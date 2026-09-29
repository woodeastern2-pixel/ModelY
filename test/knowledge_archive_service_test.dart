import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ai_voc_assistant/core/database/database_helper.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/data/services/knowledge_archive_service.dart';
import 'package:ai_voc_assistant/data/services/offline_search_store.dart';
import 'package:ai_voc_assistant/data/services/portable_manual_media.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=');
Map<String, dynamic> entry(String id, {String answer = '휴지통에서 복원 버튼을 선택합니다.'}) => {
  'id': id, 'question': '파일 복원 방법', 'answer': answer, 'category': '시스템매뉴얼',
  'customer': '매뉴얼.pdf', 'project': 'Brity Drive', 'voc_id': null, 'embedding': null,
  'created_at': '2026-09-29T00:00:00Z', 'resolved_at': '2026-09-29T00:00:00Z',
};
Future<Database> emptyDatabase() async {
  final dir = await Directory.systemTemp.createTemp('knowledge-archive-test-');
  final db = await databaseFactoryFfi.openDatabase('${dir.path}/knowledge.db');
  addTearDown(() async { if (db.isOpen) await db.close(); await dir.delete(recursive: true); });
  await db.execute('CREATE TABLE knowledge_base (id TEXT PRIMARY KEY, question TEXT NOT NULL, '
      'answer TEXT NOT NULL, category TEXT NOT NULL, customer TEXT, project TEXT, '
      'voc_id TEXT, embedding TEXT, created_at TEXT NOT NULL, resolved_at TEXT NOT NULL)');
  await db.execute('CREATE TABLE vocs (id TEXT PRIMARY KEY, title TEXT, content TEXT, category TEXT, customer TEXT, project TEXT)');
  await db.execute('CREATE TABLE responses (id TEXT PRIMARY KEY, voc_id TEXT, content TEXT, status TEXT, updated_at TEXT)');
  final store = OfflineSearchStore.forDatabase(db);
  await store.initialize(bundled: false, maintenance: false);
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Database source, target;
  setUp(() async { source = await emptyDatabase(); target = await emptyDatabase(); });

  Future<Uint8List> sample() async {
    await source.insert('knowledge_base', entry('manual-source-one'));
    await OfflineSearchStore.forDatabase(source).installOriginal({
      'id': 'document', 'filename': '매뉴얼.pdf', 'sha256': 'a' * 64, 'project': 'Brity Drive',
      'blocks': [{'id': 'raw-archive-1', 'ordinal': 0, 'section': 0, 'title': '파일 복원',
        'text': '휴지통에서 파일을 선택하고 복원 버튼을 누릅니다.', 'ocr': '복원',
        'images': [{'id': 'picture', 'kind': 'screenshot'}]}],
    });
    return KnowledgeArchiveService(source,
      imagesFor: (_) async => [{'id': 'picture', 'kind': 'screenshot'}],
      imageBytes: (_) async => png).exportData();
  }

  test('round trip restores QA, original search, media bytes and repeat import skips', () async {
    final data = await sample();
    final service = KnowledgeArchiveService(target);
    final result = await service.importData(data);
    expect(result.added, 1); expect(result.documents, 1); expect(result.images, 1);
    final store = OfflineSearchStore.forDatabase(target);
    await store.restorePendingOriginals(); await store.refresh();
    final refs = await store.search('드라이브 파일 복원 방법');
    expect(refs, isNotEmpty);
    expect(refs.any((r) => r.knowledgeBase.id.startsWith('raw-')), isTrue);
    final images = await BundledManualService.imagesFor('manual-source-one');
    expect(await BundledManualService.imageBytes(images.single['id'] as String), png);
    final repeated = await service.importData(data);
    expect(repeated.added, 0); expect(repeated.skipped, 1); expect(repeated.documents, 0);
    expect(await target.query('knowledge_base'), hasLength(1));
    final second = jsonDecode(utf8.decode(await service.exportData()));
    expect(second['entries'], hasLength(1));
    expect(second['documents'], hasLength(1));
    expect(second['media'], hasLength(1));
  });

  test('same id with different content preserves both versions and remains idempotent', () async {
    final data = await sample();
    await target.insert('knowledge_base', entry('manual-source-one', answer: '기존에 수정한 답변'));
    final service = KnowledgeArchiveService(target);
    final result = await service.importData(data);
    expect(result.added, 1); expect(result.conflicts, 1);
    expect((await service.importData(data)).added, 0);
    expect(await target.query('knowledge_base'), hasLength(2));
    expect((await target.query('knowledge_base', where: 'id=?', whereArgs: ['manual-source-one']))
        .single['answer'], '기존에 수정한 답변');
    final imported = (await target.query('knowledge_base', where: 'id != ?', whereArgs: ['manual-source-one'])).single;
    expect(await PortableManualMedia.imagesFor(imported['id'] as String), hasLength(1));
  });

  test('missing or corrupt media is rejected before any data is written', () async {
    final data = jsonDecode(utf8.decode(await sample())) as Map<String, dynamic>;
    data['media'] = <String, dynamic>{};
    await expectLater(KnowledgeArchiveService(target).importData(
        Uint8List.fromList(utf8.encode(jsonEncode(data)))), throwsFormatException);
    expect(await target.query('knowledge_base'), isEmpty);
    data['media'] = {'picture': base64Encode([1, 2, 3])};
    await expectLater(KnowledgeArchiveService(target).importData(
        Uint8List.fromList(utf8.encode(jsonEncode(data)))), throwsA(anything));
    expect(await target.query('knowledge_base'), isEmpty);
  });

  test('database failure rolls back questions, sources and images together', () async {
    final data = await sample();
    await PortableManualMedia.initialize(target);
    await target.execute("CREATE TRIGGER reject_archive BEFORE INSERT ON original_documents "
        "BEGIN SELECT RAISE(ABORT, 'test failure'); END");
    await expectLater(KnowledgeArchiveService(target).importData(data), throwsA(anything));
    expect(await target.query('knowledge_base'), isEmpty);
    expect(await target.query('knowledge_media'), isEmpty);
    expect(await target.query('original_documents'), isEmpty);
  });

  test('unknown versions and malformed dates are rejected', () async {
    final data = jsonDecode(utf8.decode(await sample())) as Map<String, dynamic>;
    data['version'] = 9;
    await expectLater(KnowledgeArchiveService(target).importData(
        Uint8List.fromList(utf8.encode(jsonEncode(data)))), throwsFormatException);
    data['version'] = 1; data['entries'][0]['created_at'] = 'not-a-date';
    await expectLater(KnowledgeArchiveService(target).importData(
        Uint8List.fromList(utf8.encode(jsonEncode(data)))), throwsFormatException);
    expect(await target.query('knowledge_base'), isEmpty);
  });

  test('original binary survives a second export without using foreign paths', () async {
    final data = jsonDecode(utf8.decode(await sample())) as Map<String, dynamic>;
    final binary = utf8.encode('original document bytes');
    data['documents'][0]['sha256'] = sha256.convert(binary).toString();
    data['originalFiles'] = {'document': base64Encode(binary)};
    final service = KnowledgeArchiveService(target);
    await service.importData(Uint8List.fromList(utf8.encode(jsonEncode(data))));
    final second = jsonDecode(utf8.decode(await service.exportData()));
    expect(base64Decode(second['originalFiles']['document']), binary);
    expect((await target.query('original_documents')).single['original_path'], isNull);
  });

  test('all bundled knowledge, original passages and media round trip', () async {
    databaseFactory = databaseFactoryFfi;
    final dir = await Directory.systemTemp.createTemp('knowledge-full-roundtrip-');
    await databaseFactory.setDatabasesPath(dir.path);
    final helper = DatabaseHelper.instance;
    try {
      final full = await helper.database;
      final entries = await full.query('knowledge_base');
      final originals = await full.query('original_documents');
      final bytes = await KnowledgeArchiveService(full).exportData();
      final backup = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(entries.length, greaterThanOrEqualTo(1008));
      expect(originals.length, greaterThanOrEqualTo(9));
      expect((backup['media'] as Map).length, greaterThanOrEqualTo(911));
      final result = await KnowledgeArchiveService(target).importData(bytes);
      expect(result.added, entries.length);
      expect(result.documents, originals.length);
      final store = OfflineSearchStore.forDatabase(target);
      await store.restorePendingOriginals(); await store.refresh();
      expect(await target.query('knowledge_base'), hasLength(entries.length));
      expect(await target.query('original_documents'), hasLength(originals.length));
      final records = await target.query('offline_records');
      expect(records.where((r) => (r['id'] as String).startsWith('raw-')).length,
          greaterThanOrEqualTo(5894));
      expect(await store.search('메신저 알림 설정 방법'), isNotEmpty);
      for (final item in (backup['media'] as Map).entries) {
        final expected = base64Decode(item.value as String);
        final id = 'local-backup-${sha256.convert(expected)}';
        expect(await PortableManualMedia.bytes(id), expected);
      }
    } finally {
      await helper.close(); await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
