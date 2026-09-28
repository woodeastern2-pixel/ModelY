import 'dart:convert';
import 'manual_media_store.dart';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// The reviewed document pack is installed locally once, without a model call.
class BundledManualService {
  static const packVersion = 'brity-documents-20260928-v1';
  static const settingKey = 'bundled_manual_pack';
  static Future<Map<String, dynamic>>? _pack;
  static final Map<String, Archive> _archives = {};

  static Future<Map<String, dynamic>> load() => _pack ??= rootBundle
      .loadString('assets/manuals/brity_documents.json')
      .then((value) => jsonDecode(value) as Map<String, dynamic>);

  static Future<void> install(Database db) async {
    final installed = await db.query('settings',
        columns: ['value'], where: 'key = ?', whereArgs: [settingKey]);
    if (installed.isNotEmpty && installed.first['value'] == packVersion) return;
    final pack = await load();
    await installPack(db, pack);
  }

  /// Public for an in-memory migration test; all writes commit together.
  static Future<void> installPack(
      Database db, Map<String, dynamic> pack) async {
    if (pack['version'] != packVersion) {
      throw const FormatException('지원하지 않는 매뉴얼 자료 버전입니다.');
    }
    await db.transaction((txn) async {
      final installed = await txn.query('settings',
          columns: ['value'], where: 'key = ?', whereArgs: [settingKey]);
      if (installed.isNotEmpty && installed.first['value'] == packVersion) return;
      final now = DateTime.now().toIso8601String();
      final batch = txn.batch();
      for (final raw in pack['entries'] as List) {
        final e = Map<String, dynamic>.from(raw as Map);
        for (final key in ['id', 'question', 'answer', 'sourceName', 'project']) {
          if (e[key] is! String || (e[key] as String).trim().isEmpty) {
            throw FormatException('매뉴얼 자료의 $key 항목이 비어 있습니다.');
          }
        }
        batch.insert('knowledge_base', {
          'id': e['id'],
          'question': e['question'],
          'answer': e['answer'],
          'category': '시스템매뉴얼',
          'customer': e['sourceName'],
          'project': e['project'],
          'embedding': null,
          'resolved_at': now,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      batch.insert('settings', {
        'key': settingKey,
        'value': packVersion,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
  }

  static Future<List<Map<String, dynamic>>> imagesFor(String entryId) async {
    if (!entryId.startsWith('manual-pack-')) {
      return const ManualMediaStore().imagesFor(entryId);
    }
    final pack = await load();
    final entries = pack['entries'] as List;
    for (final raw in entries) {
      final entry = raw as Map<String, dynamic>;
      if (entry['id'] != entryId) continue;
      final images = pack['images'] as Map<String, dynamic>;
      return (entry['images'] as List)
          .map((id) => Map<String, dynamic>.from(images[id] as Map))
          .toList();
    }
    return const [];
  }

  static Future<Uint8List> imageBytes(String id) async {
    if (id.startsWith('local-')) return const ManualMediaStore().imageBytes(id);
    if (!RegExp(r'^[a-f0-9]{24}$').hasMatch(id)) {
      throw const FormatException('잘못된 매뉴얼 이미지 식별자입니다.');
    }
    final group = id.substring(0, 1);
    var archive = _archives[group];
    if (archive == null) {
      final data = await rootBundle.load('assets/manuals/images-$group.zip');
      archive = ZipDecoder().decodeBytes(data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes));
      if (_archives.length >= 2) _archives.remove(_archives.keys.first);
      _archives[group] = archive;
    }
    final file = archive.findFile('$id.webp');
    if (file == null) throw const FormatException('매뉴얼 이미지가 없습니다.');
    return Uint8List.fromList(file.content as List<int>);
  }
}

