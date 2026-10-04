import 'dart:convert';

import 'package:ai_voc_assistant/data/services/voc_identity_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Database db;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('CREATE TABLE vocs (id TEXT PRIMARY KEY, title TEXT, '
        'content TEXT, customer TEXT, project TEXT, category TEXT, priority TEXT, '
        'status TEXT, source TEXT, source_ref TEXT, created_at TEXT, updated_at TEXT, '
        'duplicate_of_voc_id TEXT, assignee TEXT)');
    for (final name in ['responses', 'knowledge_base', 'jira_links', 'agent_logs',
      'ai_accuracy_metrics', 'ai_feedback']) {
      await db.execute('CREATE TABLE $name (id TEXT PRIMARY KEY, voc_id TEXT '
          'REFERENCES vocs(id), content TEXT, referenced_voc_ids TEXT)');
    }
    await db.execute('CREATE TABLE emails (id TEXT PRIMARY KEY, imported_voc_id TEXT)');
    await db.execute('CREATE TABLE ai_chat_messages '
        '(id TEXT PRIMARY KEY, referenced_voc_ids TEXT)');
    await VocIdentityStore.ensureSchema(db);
  });
  tearDown(() => db.close());

  Future<VocSaveResult> save(Map<String, dynamic> row, {String? app}) =>
      db.transaction((txn) => VocIdentityStore.save(txn, row, peerApp: app));

  test('changed timestamps are found for review without deleting recurring incidents', () async {
    await db.insert('vocs', voc('old'));
    await db.insert('vocs', voc('later')..['created_at'] = '2026-09-30T09:00:00Z');
    await db.insert('vocs', voc('other')..['customer'] = '다른 고객');
    expect(await VocIdentityStore.reconcile(db), 0);
    final groups = await VocIdentityStore.duplicateCandidates(db);
    expect(groups, hasLength(1));
    expect(groups.single.map((r) => r['id']).toSet(), {'old', 'later'});
    await db.insert('responses', {'id': 'answer', 'voc_id': 'later', 'content': '보존'});
    expect(await VocIdentityStore.mergeReviewed(db, [['old', 'later']]), 1);
    expect(await db.query('vocs'), hasLength(2));
    expect((await db.query('responses')).single['voc_id'], 'old');
    expect(await VocIdentityStore.mergeReviewed(db, [['old', 'later']]), 0);
  });

  test('review finds invisible spaces and line-wrap differences', () async {
    await db.insert('vocs', voc('one')..['content'] = '메일 알림 설정');
    await db.insert('vocs', voc('two')..['content'] = '메일\u200b알림\n설정'
      ..['created_at'] = '2026-09-30T09:00:00Z');
    expect(await VocIdentityStore.duplicateCandidates(db), hasLength(1));
  });

  test('stale reviewed group is rejected with all records preserved', () async {
    await db.insert('vocs', voc('one'));
    await db.insert('vocs', voc('two'));
    await db.update('vocs', {'content': '새로 수정한 별도 문의'}, where: 'id=?', whereArgs: ['two']);
    await expectLater(VocIdentityStore.mergeReviewed(db, [['one', 'two']]), throwsStateError);
    expect(await db.query('vocs'), hasLength(2));
    expect(await db.query('voc_merge_archive'), isEmpty);
  });

  test('concurrent manual retries from multiple callers create one durable row', () async {
    final results = await Future.wait(List.generate(16, (i) => save(voc('manual-$i'))));
    expect(results.where((r) => r.created), hasLength(1));
    expect(results.map((r) => r.id).toSet(), hasLength(1));
    expect(await db.query('vocs'), hasLength(1));
  });

  test('pull, push, full sync and return to origin preserve the same identity', () async {
    await save(voc('original'));
    for (final source in ['peer-pull', 'peer-sync', 'peer-sync-full', 'peer-bootstrap']) {
      final copy = voc('remote-copy')..['source'] = source
        ..['source_ref'] = 'origin:original';
      final result = await save(copy, app: 'remote');
      expect(result.created, isFalse);
      expect(result.id, 'original');
    }
    expect(await db.query('vocs'), hasLength(1));
  });

  test('same words for another customer, project or later incident stay separate', () async {
    final cases = [
      voc('one'),
      voc('customer')..['customer'] = '다른 고객',
      voc('project')..['project'] = '다른 프로젝트',
      voc('later')..['created_at'] = '2026-09-30T09:00:00Z',
      voc('different')..['content'] = '다른 내용',
    ];
    for (final row in cases) { expect((await save(row)).created, isTrue); }
    expect(await db.query('vocs'), hasLength(5));
  });

  test('stale remote snapshot cannot reopen a resolved issue; newer update applies', () async {
    await save(voc('one')..['status'] = 'RESOLVED'
      ..['updated_at'] = '2026-09-29T11:00:00Z'..['assignee'] = '담당자');
    final stale = await save(voc('one'), app: 'peer');
    expect(stale.updated, isFalse);
    expect(stale.row['status'], 'RESOLVED');
    final newer = await save(voc('one')
      ..['updated_at'] = '2026-09-29T12:00:00Z'
      ..['content'] = '수정한 문의', app: 'peer');
    expect(newer.updated, isTrue);
    expect(newer.row['assignee'], '담당자');
    expect((await save(voc('one')..['updated_at'] = '2026-09-29T12:00:00Z'
      ..['content'] = '수정한 문의', app: 'peer')).updated, isFalse);
  });

  test('Excel filename is not a unique VOC id', () async {
    await save(voc('one')..['source'] = 'excel'..['source_ref'] = 'file.xlsx');
    expect((await save(voc('two')..['source'] = 'excel'
      ..['source_ref'] = 'file.xlsx'..['content'] = '두 번째 행')).created, isTrue);
  });

  test('legacy cleanup preserves children, archive and aliases on repeated imports', () async {
    await db.insert('vocs', voc('original'));
    await db.insert('vocs', voc('duplicate')..['source'] = 'peer-pull'
      ..['source_ref'] = 'origin:original'..['status'] = 'RESOLVED');
    for (final name in ['responses', 'knowledge_base', 'jira_links', 'agent_logs',
      'ai_accuracy_metrics', 'ai_feedback']) {
      await db.insert(name, {'id': name, 'voc_id': 'duplicate',
        'content': '보존할 이력', 'referenced_voc_ids': '["duplicate","original"]'});
    }
    await db.insert('emails', {'id': 'mail', 'imported_voc_id': 'duplicate'});
    await db.insert('ai_chat_messages', {'id': 'chat', 'referenced_voc_ids': '["duplicate"]'});
    expect(await VocIdentityStore.reconcile(db), 1);
    expect(await VocIdentityStore.reconcile(db), 0);
    final keeper = (await db.query('vocs')).single;
    final id = keeper['id'];
    expect(keeper['status'], 'RESOLVED');
    for (final name in ['responses', 'knowledge_base', 'jira_links', 'agent_logs',
      'ai_accuracy_metrics', 'ai_feedback']) {
      final child = (await db.query(name)).single;
      expect(child['voc_id'], id);
      expect(child['content'], '보존할 이력');
      expect(jsonDecode(child['referenced_voc_ids'] as String), [id]);
    }
    expect((await db.query('emails')).single['imported_voc_id'], id);
    expect(jsonDecode((await db.query('ai_chat_messages')).single['referenced_voc_ids'] as String), [id]);
    expect(await db.query('voc_merge_archive'), hasLength(2));
    await db.insert('agent_logs', {'id': 'late-log', 'voc_id': 'duplicate',
      'content': '정리 중 시작했던 작업의 뒤늦은 기록'});
    expect((await db.query('agent_logs', where: 'id = ?',
      whereArgs: ['late-log'])).single['voc_id'], id);
    expect((await save(voc('duplicate')..['source'] = 'peer-sync-full', app: 'peer')).created, isFalse);
    expect(await db.query('vocs'), hasLength(1));
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('failure during cleanup rolls back parents, children and archive together', () async {
    await db.insert('vocs', voc('a'));
    await db.insert('vocs', voc('b'));
    await db.insert('responses', {'id': 'r', 'voc_id': 'b'});
    await db.execute("CREATE TRIGGER reject_merge BEFORE DELETE ON vocs "
        "BEGIN SELECT RAISE(ABORT, 'test rollback'); END");
    await expectLater(VocIdentityStore.reconcile(db), throwsA(isA<DatabaseException>()));
    expect(await db.query('vocs'), hasLength(2));
    expect((await db.query('responses')).single['voc_id'], 'b');
    expect(await db.query('voc_merge_archive'), isEmpty);
  });

  test('legacy source references join copies even when old bootstrap changed dates', () async {
    await db.insert('vocs', voc('old')..['source'] = 'peer-sync'
      ..['source_ref'] = 'origin:remote-id');
    await db.insert('vocs', voc('new')..['source'] = 'peer-bootstrap'
      ..['source_ref'] = 'origin:remote-id'..['created_at'] = '2026-09-30T09:00:00Z');
    expect(await VocIdentityStore.reconcile(db), 1);
    expect(await db.query('vocs'), hasLength(1));
  });

  test('repair and indexed duplicate lookup remain bounded for 2500 VOCs', () async {
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < 2500; i++) {
        batch.insert('vocs', voc('record-$i')..['content'] = '문의 내용 $i');
      }
      await batch.commit(noResult: true);
    });
    await VocIdentityStore.reconcile(db);
    final watch = Stopwatch()..start();
    expect(await VocIdentityStore.reconcile(db), 0);
    final result = await save(voc('copied')..['content'] = '문의 내용 1234'
      ..['source'] = 'peer-pull', app: 'peer');
    watch.stop();
    expect(result.created, isFalse);
    expect(watch.elapsedMilliseconds, lessThan(5000));
  });
}

Map<String, dynamic> voc(String id) => {
  'id': id, 'title': '메일 문의', 'content': '메일 등록 방법',
  'customer': '고객', 'project': '메일', 'category': '기타',
  'priority': 'MEDIUM', 'status': 'OPEN',
  'created_at': '2026-09-29T09:00:00Z', 'updated_at': '2026-09-29T09:00:00Z',
};
