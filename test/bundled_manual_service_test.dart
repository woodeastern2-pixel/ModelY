import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> pack;

  setUpAll(() async {
    pack = await BundledManualService.load();
    sqfliteFfiInit();
  });

  test('six documents retain all media and nested tables', () async {
    final docs = (pack['documents'] as List).cast<Map<String, dynamic>>();
    final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();
    final images = pack['images'] as Map<String, dynamic>;
    expect(docs.length, 6);
    expect(entries.length, 532);
    expect(entries.map((e) => e['id']).toSet().length, entries.length);
    expect(docs.fold<int>(0, (n, d) => n + (d['mediaCount'] as int)), 921);
    expect(docs.fold<int>(0, (n, d) => n + (d['tables'] as int)), 81);
    expect(images.length, 911);
    final referenced = entries.expand((e) => e['images'] as List).toSet();
    expect(referenced, images.keys.toSet());
    expect(images.values.where((i) => i['ocrStatus'] == 'ocr').length, 548);
    for (final group in '0123456789abcdef'.split('')) {
      final data = await rootBundle.load('assets/manuals/images-$group.zip');
      final archive = ZipDecoder().decodeBytes(data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes));
      for (final id in images.keys.where((id) => id.startsWith(group))) {
        final file = archive.findFile('$id.webp');
        expect(file, isNotNull, reason: id);
        expect(file!.size, greaterThan(0));
      }
    }
    for (final entry in entries) {
      expect(entry['answer'], contains('[출처] ${entry['sourceName']}'));
    }
  });

  test('Drive answer and survey limits preserve original evidence', () {
    final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();
    final faq = entries.singleWhere((e) =>
        (e['question'] as String).contains('다른 사람이 편집 중인 파일을 취소'));
    expect(faq['answer'], contains('강제 취소 기능을 제공하지 않습니다'));
    final survey = entries.where((e) => e['sourceName'] == 'BW_설문.docx');
    expect(survey.map((e) => e['answer']).join(), contains('20,000'));
    expect(survey.map((e) => e['answer']).join(), contains('500명'));
    final entities = entries.map((e) => KnowledgeBaseEntity(
      id: e['id'] as String,
      question: e['question'] as String,
      answer: e['answer'] as String,
      category: '시스템매뉴얼',
      customer: e['sourceName'] as String,
      project: e['project'] as String,
      resolvedAt: DateTime(2026, 9, 28),
      createdAt: DateTime(2026, 9, 28),
    ));
    final service = LocalAnswerService();
    final results = service.rank('드라이브 다른 사람이 편집 중인 파일 취소', entities);
    expect(results.first.knowledgeBase.id, faq['id']);
    expect(service.answer(results), contains('강제 취소 기능을 제공하지 않습니다'));
  });

  Future<Database> database() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT, updated_at TEXT)');
      await db.execute('CREATE TABLE knowledge_base (id TEXT PRIMARY KEY, question TEXT NOT NULL, answer TEXT NOT NULL, category TEXT, customer TEXT, project TEXT, embedding TEXT, resolved_at TEXT, created_at TEXT)');
    }),
  );

  test('upgrade installs once and preserves user edits and removals', () async {
    final db = await database();
    try {
      await db.insert('knowledge_base', {'id':'user-entry','question':'사용자 질문','answer':'사용자 답변'});
      await BundledManualService.installPack(db, pack);
      expect((await db.query('knowledge_base')).length, 533);
      final firstId = (pack['entries'] as List).first['id'];
      await db.delete('knowledge_base', where: 'id = ?', whereArgs: [firstId]);
      await db.update('knowledge_base', {'answer':'보존할 수정'}, where:'id = ?', whereArgs:['user-entry']);
      await BundledManualService.installPack(db, pack);
      expect((await db.query('knowledge_base')).length, 532);
      expect((await db.query('knowledge_base', where:'id = ?', whereArgs:['user-entry'])).single['answer'], '보존할 수정');
    } finally {
      await db.close();
    }
  });

  test('failed registration rolls back entries and version marker', () async {
    final db = await database();
    try {
      final entries = pack['entries'] as List;
      final broken = {...pack, 'entries': [entries.first, {...entries[1] as Map, 'answer':null}]};
      await expectLater(BundledManualService.installPack(db, broken), throwsA(isA<DatabaseException>()));
      expect(await db.query('knowledge_base'), isEmpty);
      expect(await db.query('settings'), isEmpty);
    } finally {
      await db.close();
    }
  });
}
