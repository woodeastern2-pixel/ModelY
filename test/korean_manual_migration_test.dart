import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_voc_assistant/data/services/manual_language_policy.dart';
import 'package:ai_voc_assistant/data/services/manual_sectioner.dart';
import 'package:ai_voc_assistant/data/services/offline_search_store.dart';
import 'package:ai_voc_assistant/data/services/knowledge_archive_service.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'offline_original_search_test.dart' show database;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  test(
      'upgrade removes English sources and derived QA but keeps Korean and user history',
      () async {
    final db = await database();
    addTearDown(db.close);
    var store = OfflineSearchStore(db);
    await store.initialize(bundled: false, maintenance: false);
    await db.insert('knowledge_base', {
      'id': 'brity-messenger-desktop-old',
      'question': '알림 설정',
      'answer': '영문에서 번역된 FAQ',
      'category': '시스템매뉴얼'
    });
    await db.insert('knowledge_base', {
      'id': 'korean',
      'question': '메신저 알림',
      'answer': '환경설정의 알림에서 알림음을 켭니다.',
      'category': '시스템매뉴얼'
    });
    await db.insert('knowledge_base', {
      'id': 'user-answer',
      'voc_id': 'v',
      'question': 'Customer question',
      'answer': 'User approved response',
      'category': '문의'
    });
    await db.insert('vocs',
        {'id': 'v', 'title': '고객 문의', 'content': '문의 내용', 'category': '문의'});
    await db.insert('responses', {
      'id': 'r',
      'voc_id': 'v',
      'status': 'APPROVED',
      'content': '승인 답변',
      'updated_at': '2026'
    });
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT)');
    await db.insert('settings', {'key': 'existing', 'value': 'preserved'});
    final old = {
      'id': 'messenger-desktop',
      'filename': 'messenger-desktop.pdf',
      'sha256': '0123456789abcdef',
      'language': 'en',
      'blocks': [
        {
          'id': 'raw-messenger-desktop-22',
          'ordinal': 22,
          'section': 22,
          'title': 'Notification',
          'text': 'Check to mute sounds',
          'ocr': '',
          'images': []
        }
      ]
    };
    await db.insert('original_documents', {
      'id': old['id'],
      'name': old['filename'],
      'fingerprint': old['sha256'],
      'content': jsonEncode(old)
    });
    await db.insert('offline_records', {
      'id': 'raw-messenger-desktop-22',
      'record': jsonEncode({
        'id': 'raw-messenger-desktop-22',
        'title': '알림 설정',
        'body': 'English source'
      }),
      'tokens': '[]'
    });
    await db.insert('offline_meta', {'key': 'version', 'value': '1'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    store = OfflineSearchStore(db);
    await store.initialize(bundled: false, maintenance: false);
    expect((await db.query('knowledge_base')).map((r) => r['id']).toSet(),
        {'korean', 'user-answer'});
    expect(await db.query('original_documents'), isEmpty);
    expect(
        await db.query('offline_records',
            where: 'id LIKE ?', whereArgs: ['%messenger-desktop%']),
        isEmpty);
    expect((await db.query('settings')).single['value'], 'preserved');
    expect(await db.query('vocs'), hasLength(1));
    expect(await db.query('responses'), hasLength(1));
    expect(
        (await store.search('메신저 알림'))
            .any((r) => r.knowledgeBase.id == 'korean'),
        isTrue);
    await store.initialize(bundled: false, maintenance: false);
    expect((await db.query('knowledge_base')).length, 2);
  });
  test('English source cannot be installed or restored through archive',
      () async {
    final db = await database();
    addTearDown(db.close);
    final store = OfflineSearchStore(db);
    await store.initialize(bundled: false, maintenance: false);
    final doc = {
      'id': 'english-upload',
      'filename': 'guide.pdf',
      'sha256': '1234567890abcdef',
      'language': 'en',
      'blocks': []
    };
    await store.installOriginal(doc);
    expect(await db.query('original_documents'), isEmpty);
    final archive = {
      'format': KnowledgeArchiveService.format,
      'version': 1,
      'entries': [],
      'documents': [doc],
      'links': {},
      'media': {},
      'originalFiles': {}
    };
    await expectLater(
        KnowledgeArchiveService(db)
            .importData(Uint8List.fromList(utf8.encode(jsonEncode(archive)))),
        throwsA(isA<FormatException>()));
    expect(await db.query('original_documents'), isEmpty);
  });
  test('English product words in Korean manuals remain valid', () {
    final entry = KnowledgeBaseEntity(
        id: 'korean',
        question: 'Brity Messenger PC',
        answer: 'Windows 작업표시줄에서 알림을 확인합니다. VIP 메시지와 키워드 알림은 받습니다.',
        category: '시스템매뉴얼',
        createdAt: DateTime(2026),
        resolvedAt: DateTime(2026));
    expect(ManualLanguagePolicy.excludedEntry(entry), isFalse);
  });
  test(
      'headings split sections while page breaks and distant caveats stay together',
      () {
    final parts = ManualSectioner.split(
        '[제목] 1. 복원\n\n1. 휴지통을 엽니다.\n\n[페이지 2]\n\n2. 복원을 누릅니다.\n\n주의: 영구 삭제는 복원 불가\n\n[제목] 2. 알림\n\n알림음을 켭니다.');
    expect(parts, hasLength(2));
    expect(parts.first.body, contains('영구 삭제는 복원 불가'));
    expect(parts.first.body, contains('2. 복원을 누릅니다'));
    expect(parts.last.body, isNot(contains('휴지통')));
  });
  test('indexed chat retains pending context but never treats it as an answer',
      () async {
    final db = await database();
    addTearDown(db.close);
    final store = OfflineSearchStore(db);
    await store.initialize(bundled: false, maintenance: false);
    await db.insert('vocs', {
      'id': 'pending',
      'title': '메신저 알림 설정 문의',
      'content': '알림음이 안 나요',
      'category': '문의'
    });
    expect(await store.search('메신저 알림 설정'), isEmpty);
    final refs =
        await store.search('메신저 알림 설정', includeRegisteredQuestions: true);
    expect(refs.single.knowledgeBase.vocId, 'pending');
    expect(LocalAnswerService().isAnswerSource(refs.single.knowledgeBase),
        isFalse);
    await db.insert('responses', {
      'id': 'approved',
      'voc_id': 'pending',
      'content': '환경설정의 알림에서 알림음을 켭니다.',
      'status': 'APPROVED',
      'updated_at': '2026'
    });
    final approved = await store.search('메신저 알림 설정의 승인된 답변 요약',
        includeRegisteredQuestions: true);
    expect(approved.single.knowledgeBase.id, 'approved-index-pending');
    expect(LocalAnswerService().isAnswerSource(approved.single.knowledgeBase),
        isTrue);
  });
}
