import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'bundled_manual_service.dart';
import 'portable_manual_media.dart';

class KnowledgeRestoreResult {
  final int added, skipped, conflicts, documents, images;
  const KnowledgeRestoreResult(this.added, this.skipped, this.conflicts,
      this.documents, this.images);
}

/// A versioned, self-contained JSON archive. Never imports settings, credentials,
/// executable paths, SQL, or cached search indexes from another installation.
class KnowledgeArchiveService {
  static const format = 'ai-voc-knowledge';
  static const maxBytes = 300 * 1024 * 1024;
  final Database db;
  final Future<List<Map<String, dynamic>>> Function(String) imagesFor;
  final Future<Uint8List> Function(String) imageBytes;
  KnowledgeArchiveService(this.db, {
    this.imagesFor = BundledManualService.imagesFor,
    this.imageBytes = BundledManualService.imageBytes,
  });

  Future<Uint8List> exportData() async {
    final snapshot = await db.transaction((txn) async => <String, dynamic>{
      'entries': await txn.query('knowledge_base', orderBy: 'id'),
      'documents': await txn.query('original_documents', orderBy: 'id'),
    });
    final entries = (snapshot['entries'] as List).cast<Map<String, dynamic>>();
    final documents = (snapshot['documents'] as List).cast<Map<String, dynamic>>();
    final links = <String, List<Map<String, dynamic>>>{};
    final media = <String, String>{};
    final mediaIds = <String>{};
    final originalFiles = <String, String>{};
    void addMedia(List<Map<String, dynamic>> images) {
      mediaIds.addAll(images.map((image) => image['id'] as String));
    }
    for (final entry in entries) {
      final id = entry['id'] as String;
      final images = await imagesFor(id);
      links[id] = images;
      addMedia(images);
    }
    final fileTable = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='knowledge_original_files'");
    if (fileTable.isNotEmpty) {
      for (final row in await db.query('knowledge_original_files')) {
        originalFiles[row['document_id'] as String] = row['data'] as String;
      }
    }
    final originals = <Map<String, dynamic>>[];
    for (final row in documents) {
      final doc = jsonDecode(row['content'] as String) as Map<String, dynamic>;
      originals.add(doc);
      for (final block in doc['blocks'] as List) {
        addMedia((block['images'] as List? ?? [])
            .map((i) => Map<String, dynamic>.from(i as Map)).toList());
      }
      final path = row['original_path'] as String?;
      if (path != null && await File(path).exists()) {
        originalFiles[doc['id'] as String] = base64Encode(await File(path).readAsBytes());
      }
    }
    // Bundled image archives are grouped by id prefix. Read in that order to
    // decompress each archive once instead of cycling the bounded cache.
    final orderedMedia = mediaIds.toList()..sort();
    for (final id in orderedMedia) {
      media[id] = base64Encode(await imageBytes(id));
    }
    final payload = <String, dynamic>{
      'format': format, 'version': 1, 'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': entries, 'documents': originals, 'links': links,
      'media': media, 'originalFiles': originalFiles,
    };
    final bytes = await Isolate.run(() => Uint8List.fromList(utf8.encode(jsonEncode(payload))));
    if (bytes.length > maxBytes) throw const FormatException('지식 백업은 300MB까지 지원합니다.');
    return bytes;
  }

  /// Validates the entire archive before any database write. A failed import
  /// rolls back entries, source documents, media, and provenance together.
  Future<KnowledgeRestoreResult> importData(Uint8List bytes) async {
    if (bytes.length > maxBytes) throw const FormatException('지식 백업은 300MB까지 지원합니다.');
    final payload = await Isolate.run(() => _validate(bytes));
    // Reject corrupt image payloads before committing any restored data.
    for (final encoded in (payload['media'] as Map).values) {
      final codec = await ui.instantiateImageCodec(base64Decode(encoded as String));
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    }
    await PortableManualMedia.initialize(db);
    return db.transaction((txn) async {
      var added = 0, skipped = 0, conflicts = 0, documents = 0;
      final imageIds = <String, String>{};
      for (final item in (payload['media'] as Map<String, dynamic>).entries) {
        final data = base64Decode(item.value as String);
        final id = 'local-backup-${sha256.convert(data)}';
        imageIds[item.key] = id;
        await txn.insert('knowledge_media', {'id': id, 'bytes': data},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      List<Map<String, dynamic>> remapImages(List raw) => raw.map((v) {
        final image = Map<String, dynamic>.from(v as Map);
        return <String, dynamic>{...image, 'id': imageIds[image['id']]!};
      }).toList();
      for (final raw in payload['entries'] as List) {
        final entry = Map<String, dynamic>.from(raw as Map);
        final originalId = entry['id'] as String;
        final existing = await txn.query('knowledge_base', where: 'id = ?', whereArgs: [originalId]);
        var id = originalId;
        if (existing.isNotEmpty && !_sameEntry(existing.single, entry)) {
          id = 'manual-source-backup-${sha256.convert(utf8.encode(jsonEncode([
            originalId, entry['question'], entry['answer'], entry['category'], entry['customer'], entry['project'],
          ])))}';
          conflicts++;
        }
        entry['id'] = id;
        final found = await txn.query('knowledge_base', where: 'id = ?', whereArgs: [id]);
        if (found.isEmpty) {
          // A foreign VOC id must not accidentally link to a different incident.
          entry['voc_id'] = null;
          await txn.insert('knowledge_base', entry);
          added++;
        } else {
          if (!_sameEntry(found.single, entry)) {
            throw const FormatException('백업 자료의 식별자가 변경된 기존 자료와 충돌합니다.');
          }
          skipped++;
        }
        final images = remapImages((payload['links'] as Map)[originalId] as List? ?? []);
        if (images.isNotEmpty) {
          await txn.insert('knowledge_media_links', {'entry_id': id, 'images': jsonEncode(images)},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
      for (final raw in payload['documents'] as List) {
        final doc = Map<String, dynamic>.from(raw as Map);
        final existing = await txn.query('original_documents', where: 'id = ?', whereArgs: [doc['id']]);
        if (existing.isNotEmpty) {
          if (existing.single['fingerprint'] != doc['sha256']) {
            throw const FormatException('기존 원문과 식별자가 충돌합니다. 기존 자료는 보존됩니다.');
          }
          continue;
        }
        doc['blocks'] = [for (final rawBlock in doc['blocks'] as List)
          {...Map<String, dynamic>.from(rawBlock as Map),
            'images': remapImages(rawBlock['images'] as List? ?? [])}];
        // Check raw passage identity across other sources before installation.
        for (final block in doc['blocks'] as List) {
          final clash = await txn.query('offline_records', columns: ['id'],
              where: 'id = ?', whereArgs: [block['id']], limit: 1);
          if (clash.isNotEmpty) throw const FormatException('원문 구간 식별자가 충돌합니다.');
        }
        await txn.insert('original_documents', {'id': doc['id'], 'name': doc['filename'],
          'fingerprint': doc['sha256'], 'original_path': null, 'content': jsonEncode(doc)});
        documents++;
      }
      // Original binary files are retained in the archive DB without restoring
      // untrusted filesystem paths. A subsequent export includes them again.
      await txn.execute('CREATE TABLE IF NOT EXISTS knowledge_original_files '
          '(document_id TEXT PRIMARY KEY, data TEXT NOT NULL)');
      for (final item in (payload['originalFiles'] as Map<String, dynamic>).entries) {
        await txn.insert('knowledge_original_files', {'document_id': item.key, 'data': item.value},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      if (documents > 0) {
        await txn.insert('offline_meta', {'key': 'original_restore_pending', 'value': '1'},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return KnowledgeRestoreResult(added, skipped, conflicts, documents, imageIds.values.toSet().length);
    });
  }

  static bool _sameEntry(Map<String, dynamic> a, Map<String, dynamic> b) =>
      ['question', 'answer', 'category', 'customer', 'project']
          .every((key) => a[key] == b[key]);

  static Map<String, dynamic> _validate(Uint8List bytes) {
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map || value['format'] != format || value['version'] != 1) {
      throw const FormatException('지원하지 않는 지식 백업 형식입니다.');
    }
    final data = Map<String, dynamic>.from(value);
    for (final key in ['entries', 'documents']) {
      if (data[key] is! List) throw FormatException('$key 항목이 잘못되었습니다.');
    }
    for (final key in ['links', 'media', 'originalFiles']) {
      if (data[key] is! Map) throw FormatException('$key 항목이 잘못되었습니다.');
    }
    final ids = <String>{};
    const columns = {'id', 'question', 'answer', 'category', 'customer', 'project',
      'voc_id', 'embedding', 'resolved_at', 'created_at'};
    for (final raw in data['entries'] as List) {
      if (raw is! Map || raw.keys.any((k) => !columns.contains(k))) {
        throw const FormatException('지식 항목의 필드가 잘못되었습니다.');
      }
      for (final key in ['id', 'question', 'answer', 'category', 'resolved_at', 'created_at']) {
        if (raw[key] is! String || (raw[key] as String).trim().isEmpty) {
          throw FormatException('지식 항목의 $key 값이 비어 있습니다.');
        }
      }
      if (!ids.add(raw['id'] as String)) throw const FormatException('중복된 지식 식별자입니다.');
      for (final key in ['resolved_at', 'created_at']) {
        if (DateTime.tryParse(raw[key] as String) == null) throw const FormatException('날짜가 잘못되었습니다.');
      }
      for (final key in ['customer', 'project', 'voc_id', 'embedding']) {
        if (raw[key] != null && raw[key] is! String) throw const FormatException('지식 필드 형식이 잘못되었습니다.');
      }
      if (raw['embedding'] != null) {
        final vector = jsonDecode(raw['embedding'] as String);
        if (vector is! List || vector.any((x) => x is! num || !x.isFinite)) {
          throw const FormatException('검색 벡터가 잘못되었습니다.');
        }
      }
    }
    final media = data['media'] as Map;
    for (final item in media.entries) {
      if (item.key is! String || item.value is! String || base64Decode(item.value).isEmpty) {
        throw const FormatException('이미지 데이터가 잘못되었습니다.');
      }
    }
    void checkImages(Object? raw) {
      if (raw is! List) throw const FormatException('이미지 연결이 잘못되었습니다.');
      for (final image in raw) {
        if (image is! Map || image['id'] is! String || !media.containsKey(image['id'])) {
          throw const FormatException('연결된 이미지가 백업에 없습니다.');
        }
      }
    }
    for (final item in (data['links'] as Map).entries) {
      if (!ids.contains(item.key)) throw const FormatException('이미지의 지식 항목이 없습니다.');
      checkImages(item.value);
    }
    final docIds = <String>{}, blockIds = <String>{};
    for (final doc in data['documents'] as List) {
      if (doc is! Map || doc['id'] is! String || !docIds.add(doc['id']) ||
          doc['filename'] is! String || doc['sha256'] is! String ||
          !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(doc['sha256']) || doc['blocks'] is! List) {
        throw const FormatException('원문 정보가 잘못되었습니다.');
      }
      if (doc['project'] != null && doc['project'] is! String) throw const FormatException('원문 제품 정보가 잘못되었습니다.');
      for (final block in doc['blocks'] as List) {
        if (block is! Map || block['id'] is! String || !(block['id'] as String).startsWith('raw-') ||
            !blockIds.add(block['id']) || block['title'] is! String || block['text'] is! String ||
            block['ordinal'] is! int || block['section'] == null ||
            (block['ocr'] != null && block['ocr'] is! String)) {
          throw const FormatException('원문 구간 정보가 잘못되었습니다.');
        }
        checkImages(block['images'] ?? []);
      }
    }
    for (final item in (data['originalFiles'] as Map).entries) {
      if (!docIds.contains(item.key) || item.value is! String) throw const FormatException('원본 파일 정보가 잘못되었습니다.');
      final binary = base64Decode(item.value);
      final doc = (data['documents'] as List).firstWhere((d) => d['id'] == item.key);
      if (sha256.convert(binary).toString() != doc['sha256']) throw const FormatException('원본 파일 검증에 실패했습니다.');
    }
    return data;
  }
}
