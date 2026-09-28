import 'package:ai_voc_assistant/domain/repositories/indexed_knowledge_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_voc_assistant/data/services/offline_search_store.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/data/services/original_media_registry.dart';
import 'package:ai_voc_assistant/data/seeds/brity_suite_manual_seed.dart';

Future<Database> database() async {
  final db=await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute('CREATE TABLE knowledge_base(id TEXT PRIMARY KEY,question TEXT,answer TEXT,category TEXT,customer TEXT,project TEXT,voc_id TEXT)');
  await db.execute('CREATE TABLE vocs(id TEXT PRIMARY KEY,title TEXT,content TEXT,category TEXT,customer TEXT,project TEXT)');
  await db.execute('CREATE TABLE responses(id TEXT PRIMARY KEY,voc_id TEXT,content TEXT,status TEXT,updated_at TEXT)');
  return db;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  test('original corpus answers with ZERO QA records; persistent index stays under 5s', () async {
    final db=await database();addTearDown(db.close);
    var store=OfflineSearchStore(db);
    await store.initialize(maintenance:false);
    final answerer=LocalAnswerService();
    expect(await db.query('knowledge_base'),isEmpty);
    expect(store.index.length,5894);
    final queries={
      '드라이브 다른 사람이 편집 중인 파일 취소':'강제 취소',
      '설문 500명':'500',
      '메신저 제거 대화 기록':'conversation data',
      '일정등록 일정 등록 되려면 어떻게 해야하나요?':'일정',
    };
    final timings=<Map<String,dynamic>>[];
    Future<void> check(String stage) async {
      for(final q in queries.entries) {
        final clock=Stopwatch()..start();
        final refs=await store.search(q.key);
        expect(answerer.canAnswer(q.key,refs),isTrue,reason:'$stage ${q.key}');
        final text=answerer.answerForQuery(q.key,refs);
        clock.stop();
        expect(text.toLowerCase(),contains(q.value.toLowerCase()),reason:'$stage ${q.key}: $text');
        expect(store.index.lastCandidates,lessThanOrEqualTo(128));
        expect(clock.elapsedMilliseconds,lessThan(5000));
        timings.add({'stage':stage,'query':q.key,'milliseconds':clock.elapsedMicroseconds/1000,
          'candidates':store.index.lastCandidates,'answer':text});
      }
    }
    await check('original-only');
    final pack=await BundledManualService.load();
    final batch=db.batch();
    for(final row in [...BritySuiteManualSeed.entries,...pack['entries'] as List]) {
      batch.insert('knowledge_base',{'id':row['id'],'question':row['question'],'answer':row['answer'],
        'category':'시스템매뉴얼','customer':row['sourceName'],'project':row['project']});
    }
    await batch.commit(noResult:true);
    await store.refresh();
    expect(store.index.length,5894+1008);
    await check('qa-and-original');
    store=OfflineSearchStore(db);
    await store.initialize(maintenance:false);
    await check('first-after-reload');
    for(var i=0;i<3;i++) await check('repeat-$i');
    final file=File('test/goldens/offline-search-performance.json');
    await file.parent.create(recursive:true);
    await file.writeAsString(jsonEncode({'qaRecords':1008,'originalPassages':5894,
      'environment':'GitHub Actions Linux Flutter test; not a Windows device measurement',
      'samples':timings}));
  },timeout:const Timeout(Duration(minutes:4)));

  test('source-only table and image transcription create grounded answers', () async {
    final db=await database();addTearDown(db.close);
    final store=OfflineSearchStore(db);await store.initialize(bundled:false,maintenance:false);
    await store.installOriginal({'id':'fixture','filename':'원문만 존재.docx',
      'sha256':'1234567890abcdef','blocks':[
      {'id':'raw-fixture-table','title':'운영 표','text':'보관 기간 | 90일\n영구 삭제 | 복원 불가',
        'ocr':'','section':0,'ordinal':1,'images':[]},
      {'id':'raw-fixture-ocr','title':'화면','text':'설정 화면 안내',
        'ocr':'자동로그아웃 45분','section':1,'ordinal':2,
        'images':[{'id':'screen-fixture','kind':'screen'}]},
    ]});
    final service=LocalAnswerService();
    final table=await store.search('보관 기간 90일');
    expect(service.canAnswer('보관 기간 90일',table),isTrue);
    expect(service.answerForQuery('보관 기간 90일',table),contains('90일'));
    final ocr=await store.search('자동로그아웃 45분');
    expect(service.canAnswer('자동로그아웃 45분',ocr),isTrue);
    final answer=service.answerForQuery('자동로그아웃 45분',ocr);
    expect(answer,contains('45분'));
    expect(answer,contains('자동 인식'));
    expect(OriginalMediaRegistry.images['raw-fixture-ocr']!.single['id'],'screen-fixture');
  });

  test('new import retains original bytes and searches independently of QA', () async {
    final dir=await Directory.systemTemp.createTemp('original-search-');addTearDown(()=>dir.delete(recursive:true));
    final db=await database();addTearDown(db.close);
    final store=OfflineSearchStore(db,directory:dir);await store.initialize(bundled:false,maintenance:false);
    final bytes=Uint8List.fromList([80,75,3,4]);
    await store.preserveOriginal(fileName:'테스트.docx',fingerprint:'aabbccdd00112233',
      bytes:bytes,extractedText:'휴지통에서 복원 버튼을 누르세요.\n\n영구 삭제는 복원 불가',images:{});
    final docs=await db.query('original_documents');
    expect(await File(docs.single['original_path'] as String).readAsBytes(),bytes);
    expect(await db.query('knowledge_base'),isEmpty);
    final refs=await store.search('휴지통 복원');
    expect(LocalAnswerService().answerForQuery('휴지통 복원',refs),contains('복원 버튼'));
  });

  test('answer entry point uses the index and retains distant section restrictions', () async {
    final db=await database();addTearDown(db.close);
    final store=OfflineSearchStore(db);await store.initialize(bundled:false,maintenance:false);
    await store.installOriginal({'id':'full-section','filename':'원문.docx','sha256':'1234567890abcdef',
      'blocks':[
        for(var i=0;i<8;i++) {'id':'raw-context-$i','title':'복원 절차','ordinal':i,'section':1,
          'text':i==0 ? '휴지통에서 복원 버튼을 선택하세요.' : i==7 ? '주의: 90일 이후에는 복원이 불가합니다.' : '화면 안내 $i',
          'ocr':'','images':[]},
      ]});
    final settings=SettingsViewModel(_EmptySettings());addTearDown(settings.dispose);
    final vm=AiViewModel(_IndexRepository(store),_NoVocScan(),settings);addTearDown(vm.dispose);
    final clock=Stopwatch()..start();
    final result=await vm.generateAnswer('휴지통 복원','방법');
    expect(result,isNotNull);
    expect(result!.answer,contains('90일 이후에는 복원이 불가'));
    expect(vm.isAiConnected,isFalse);
    expect(clock.elapsedMilliseconds,lessThan(5000));
  });

  test('insert update delete and approved response invalidate the index', () async {
    final db=await database();addTearDown(db.close);
    final store=OfflineSearchStore(db);await store.initialize(bundled:false,maintenance:false);
    await db.insert('knowledge_base',{'id':'qa','question':'휴지통 복원','answer':'휴지통에서 복원 버튼을 누르세요.','category':'매뉴얼'});
    expect(await store.search('휴지통 복원'),isNotEmpty);
    await db.update('knowledge_base',{'answer':'알림 설정에서 소리를 끄세요.','question':'알림 설정'},where:'id=?',whereArgs:['qa']);
    expect(await store.search('휴지통 복원'),isEmpty);
    expect(await store.search('알림 설정'),isNotEmpty);
    await db.delete('knowledge_base',where:'id=?',whereArgs:['qa']);
    expect(await store.search('알림 설정'),isEmpty);
    await db.insert('vocs',{'id':'v','title':'휴지통 복원','content':'방법','category':'문의'});
    await db.insert('responses',{'id':'r','voc_id':'v','content':'휴지통에서 복원 버튼을 누르세요.','status':'DRAFT','updated_at':'2026'});
    expect(await store.search('휴지통 복원'),isEmpty);
    await db.update('responses',{'status':'APPROVED'});
    expect(await store.search('휴지통 복원'),isNotEmpty);
    expect(await store.search('휴지통 복원',excludeVocId:'v'),isEmpty);
  });
}

class _IndexRepository implements KnowledgeBaseRepository, IndexedKnowledgeRepository {
  final OfflineSearchStore store;
  _IndexRepository(this.store);
  @override
  Future<List<SimilarVocResult>> searchOffline(String query,{String? excludeVocId}) =>
      store.search(query,excludeVocId:excludeVocId);
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() => throw StateError('Full QA scan is forbidden in the answer path');
  @override
  dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
class _NoVocScan implements VocRepository {
  @override
  dynamic noSuchMethod(Invocation i)=>throw StateError('Full VOC scan is forbidden in the answer path');
}
class _EmptySettings implements SettingsRepository {
  @override
  Future<Map<String,String>> getAllSettings() async => {};
  @override
  dynamic noSuchMethod(Invocation i)=>super.noSuchMethod(i);
}
