import 'package:ai_voc_assistant/data/services/demo_voc_store.dart';
import 'package:ai_voc_assistant/data/services/sample_voc_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  final samples = SampleVocGenerator.generateSampleVocs(now: DateTime.utc(2026,9,29,8,1));
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await db.execute('CREATE TABLE vocs (id TEXT PRIMARY KEY, title TEXT, content TEXT, '
        'category TEXT, tags TEXT, customer TEXT, project TEXT, priority TEXT, status TEXT, '
        'is_business_related INTEGER, jira_required INTEGER, business_type TEXT, department TEXT, '
        'assignee TEXT, urgency TEXT, source TEXT, source_ref TEXT, processing_minutes INTEGER, '
        'analysis_reason TEXT, created_at TEXT, updated_at TEXT, duplicate_of_voc_id TEXT)');
    await db.execute('CREATE TABLE knowledge_base (id TEXT PRIMARY KEY, voc_id TEXT, answer TEXT)');
    await db.execute('CREATE TABLE responses (id TEXT PRIMARY KEY, voc_id TEXT, content TEXT)');
    await db.insert('vocs', {'id':'real-1', 'source':'manual','title':'실제 문의', 'content':'보존'});
  });
  tearDown(() async => db.close());

  test('upgrade removes old markers without changing IDs, dates or user edits', () async {
    final store = DemoVocStore(db);
    await store.insert(samples);
    final first = samples.first;
    await db.update('vocs', {
      'title': '[시연] ${first.title}',
      'content': '${first.content}\n\n[시연용 가상 문의 — 실제 고객 접수가 아닙니다.]',
      'customer': '시연 ${first.customer}',
      'tags': '시연,${first.tags}',
      'assignee': '시연 담당자 1',
    }, where: 'id = ?', whereArgs: [first.id]);
    await db.update('vocs', {'title': '사용자가 바꾼 제목', 'content': '추가한 내용'},
        where: 'id = ?', whereArgs: [samples[1].id]);
    await db.update('vocs', {'title': '[시연] 실제 사용자의 제목'},
        where: 'id = ?', whereArgs: ['real-1']);
    expect(await store.removeVisibleMarkers(), 1);
    expect(await store.removeVisibleMarkers(), 0);
    final row = (await db.query('vocs', where: 'id = ?', whereArgs: [first.id])).single;
    expect(row['title'], first.title);
    expect(row['content'], first.content);
    expect(row['customer'], first.customer);
    expect(row['source'], 'demo');
    expect(row['created_at'], first.createdAt.toIso8601String());
    expect(row['updated_at'], first.updatedAt.toIso8601String());
    expect((await db.query('vocs', where: 'id = ?', whereArgs: [samples[1].id])).single['content'], '추가한 내용');
    expect((await db.query('vocs', where: 'id = ?', whereArgs: ['real-1'])).single['title'], '[시연] 실제 사용자의 제목');
    expect((await store.insert(samples)).added, 0);
    expect(await store.clear(), 1000);
    expect(await db.query('vocs'), hasLength(1));
  });

  test('full insertion and repeated import preserve real and edited rows', () async {
    final store = DemoVocStore(db);
    final first = await store.insert(samples);
    expect(first.added, 1000);
    expect(first.skipped, 0);
    await db.update('vocs', {'title':'사용자가 수정한 시연'}, where:'id = ?',whereArgs:[samples.first.id]);
    final second = await store.insert(samples);
    expect(second.added, 0);
    expect(second.skipped, 1000);
    expect((await db.query('vocs')), hasLength(1001));
    expect((await db.query('vocs',where:'id = ?',whereArgs:[samples.first.id])).single['title'], '사용자가 수정한 시연');
    expect(await db.query('knowledge_base'), isEmpty);
    expect(await db.query('responses'), isEmpty);
    expect((await db.query('vocs',where:"id = 'real-1'")).single['content'], '보존');
  });
  test('failed middle write rolls back every generated row', () async {
    await db.execute("CREATE TRIGGER fail_demo BEFORE INSERT ON vocs WHEN NEW.id = '${samples[320].id}' "
        "BEGIN SELECT RAISE(ABORT, 'forced failure'); END");
    await expectLater(DemoVocStore(db).insert(samples), throwsA(isA<DatabaseException>()));
    expect(await db.query('vocs'), hasLength(1));
  });
  test('concurrent imports cannot duplicate the batch', () async {
    final results = await Future.wait([DemoVocStore(db).insert(samples), DemoVocStore(db).insert(samples)]);
    expect(results.fold<int>(0,(n,r)=>n+r.added),1000);
    expect(await db.query('vocs'), hasLength(1001));
  });
  test('clear removes sample activity but preserves actual data and knowledge', () async {
    final store = DemoVocStore(db);
    await store.insert(samples);
    await db.insert('responses', {'id':'r1','voc_id':samples.first.id, 'content':'시연 답변'});
    await db.insert('responses', {'id':'r2','voc_id':'real-1', 'content':'실제 답변'});
    await db.insert('knowledge_base', {'id':'k1','voc_id':samples.first.id,'answer':'사용자 지식'});
    await db.insert('vocs', {'id':'brity-demo-v2-real', 'source':'manual','title':'실제'});
    expect(await store.clear(),1000);
    expect(await db.query('vocs'),hasLength(2));
    expect((await db.query('responses')).single['id'],'r2');
    final knowledge = (await db.query('knowledge_base')).single;
    expect(knowledge['answer'],'사용자 지식');
    expect(knowledge['voc_id'],isNull);
    expect(await db.query('voc_identity_index'),isEmpty);
    expect(await db.query('voc_identity_aliases'),isEmpty);
    expect(await store.clear(),0);
    expect((await store.insert(samples)).added,1000);
  });
}
