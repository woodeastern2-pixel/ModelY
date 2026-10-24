import 'package:ai_voc_assistant/data/services/sample_voc_generator.dart';
import 'package:ai_voc_assistant/domain/repositories/indexed_knowledge_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'offline_query_recovery_test.dart' show attendeeQuestion;
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
  test('reported ordinary questions retrieve procedures and reject unrelated evidence', () async {
    final db = await database();
    addTearDown(db.close);
    final store = OfflineSearchStore(db);
    await store.initialize(maintenance: false);
    final pack = await BundledManualService.load();
    final batch = db.batch();
    for (final row in [...BritySuiteManualSeed.entries, ...pack['entries'] as List]) {
      batch.insert('knowledge_base', {'id': row['id'], 'question': row['question'],
        'answer': row['answer'], 'category': '시스템매뉴얼',
        'customer': row['sourceName'], 'project': row['project']});
    }
    await batch.commit(noResult: true);
    await store.refresh();
    final settings = SettingsViewModel(_EmptySettings());
    final vm = AiViewModel(_IndexRepository(store), _NoVocScan(), settings);
    addTearDown(vm.dispose);
    addTearDown(settings.dispose);
    final cases = [
      ['회의실을 찾아서 예약하는 방법', '내일 오후에 프로젝터가 있는 빈 회의실을 찾아 예약하려고 합니다. 어디에서 어떻게 예약하면 되나요?'],
      ['Copilot으로 답장 초안 작성', '받은 메일 내용을 바탕으로 정중한 답장 초안을 자동 작성하고 싶은데 어떻게 사용하나요?'],
      ['메신저 아이디 중복', '메신저 아이디가 중복되는 현상이 발생하고 있습니다. 조치 방법 알려주세요.'],
      ['카메라 필터 알림이 계속 뜹니다.', 'Zoom 회의 중 Brity Messenger에서 카메라를 켜거나 끌 때 카메라 필터 사용 기간이 만료되었다는 알림이 계속 뜹니다.'],
    ];
    final report = <Map<String, Object?>>[];
    for (var i = 0; i < cases.length; i++) {
      final item = cases[i];
      final result = await vm.generateAnswer(item[0], item[1]);
      expect(result, isNotNull);
      expect(vm.error, isNull);
      if (i < 2) {
        expect(vm.isClarificationAnswer, isFalse, reason: item[0]);
        expect(vm.answerEvidence, isNotEmpty);
        expect(result!.answer, contains(i == 0 ? '예약' : '답장'));
        expect(result.answer, isNot(contains('문제가 발생한 화면')));
        if (i == 0) {
          expect(result.answer, contains('클릭'));
          expect(result.answer, contains('비품'));
        }
        expect(result.answer, isNot(contains('추가 확인이 필요한 항목: ${item[0]}')));
        if (i == 1) {
          expect(vm.answerEvidence.every((r) => r.knowledgeBase.answer.contains('답장')), isTrue);
          expect(vm.answerEvidence.any((r) => r.knowledgeBase.question.contains('회의록')), isFalse);
        }
      } else {
        expect(vm.isClarificationAnswer, isTrue, reason: item[0]);
        expect(vm.answerEvidence, isEmpty);
        expect(result!.referencedCases, isEmpty);
        expect(result.answer, contains(i == 2 ? '서로 다른 사용자' : '알림 창의 제목'));
        expect(result.answer, isNot(contains('제품 이름을 알려주세요')));
      }
      report.add({'title': item[0], 'clarification': vm.isClarificationAnswer,
        'answer': result.answer, 'notes': result.notes,
        'sources': vm.answerEvidence.map((r) => r.knowledgeBase.question).toList()});
    }
    final output = File('test/goldens/reported-question-audit.json');
    await output.parent.create(recursive: true);
    await output.writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  });

  test('all 1000 demo requests produce an offline draft without model calls', () async {
    final db = await database();
    addTearDown(db.close);
    final store = OfflineSearchStore(db);
    await store.initialize(maintenance: false);
    final pack = await BundledManualService.load();
    final batch = db.batch();
    for (final row in [...BritySuiteManualSeed.entries, ...pack['entries'] as List]) {
      batch.insert('knowledge_base', {'id': row['id'], 'question': row['question'],
        'answer': row['answer'], 'category': '시스템매뉴얼',
        'customer': row['sourceName'], 'project': row['project']});
    }
    await batch.commit(noResult: true);
    await store.refresh();
    final settings = SettingsViewModel(_EmptySettings());
    final vm = AiViewModel(_IndexRepository(store), _NoVocScan(), settings);
    addTearDown(vm.dispose);
    addTearDown(settings.dispose);
    final counts = <String, Map<String, int>>{};
    final examples = <Map<String, Object?>>[];
    var grounded = 0;
    var processed = 0;
    var longestMs = 0;
    final elapsed = Stopwatch()..start();
    for (final voc in SampleVocGenerator.generateSampleVocs(now: DateTime(2026, 9, 29, 20))) {
      final timer = Stopwatch()..start();
      final result = await vm.generateAnswer(voc.title, voc.content, excludeVocId: voc.id);
      timer.stop();
      if (timer.elapsedMilliseconds > longestMs) longestMs = timer.elapsedMilliseconds;
      processed++;
      if (processed % 100 == 0) {
        // ignore: avoid_print
        print('Offline demo coverage: $processed/1000 in ${elapsed.elapsed.inSeconds}s');
      }
      expect(result, isNotNull, reason: voc.title);
      expect(result!.answer.trim(), isNotEmpty, reason: voc.title);
      expect(vm.error, isNull, reason: voc.title);
      expect(vm.isAiConnected, isFalse);
      expect(vm.isAiAnswer, isFalse);
      expect(store.index.lastTotalCandidates, lessThanOrEqualTo(512));
      final key = vm.isClarificationAnswer ? 'clarification' : 'grounded';
      final field = counts.putIfAbsent(voc.project, () => {'grounded': 0, 'clarification': 0});
      field[key] = field[key]! + 1;
      if (vm.isClarificationAnswer) {
        expect(result.referencedCases, isEmpty);
        expect(result.confidence, 0);
        expect(result.notes, contains('검증된 해결 답변이 아닙니다'));
      } else {
        grounded++;
        expect(result.referencedCases, isNotEmpty);
      }
      if (examples.length < 20) examples.add({'title': voc.title, 'kind': key, 'answer': result.answer});
    }
    expect(grounded, greaterThan(0), reason: 'Known manuals must contribute real evidence, not only clarification templates.');
    expect(counts.values.fold<int>(0, (n, c) => n + c['grounded']! + c['clarification']!), 1000);
    final report = File('test/goldens/demo-offline-coverage.json');
    await report.parent.create(recursive: true);
    await report.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'total': 1000, 'grounded': grounded, 'clarification': 1000 - grounded,
      'modelCalls': 0, 'fields': counts, 'examples': examples,
      'elapsedMs': elapsed.elapsedMilliseconds, 'longestRequestMs': longestMs,
    }));
  }, timeout: const Timeout(Duration(minutes: 15)));

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
        if(q.key.startsWith('일정등록')) {
          expect(answerer.answerReferences(refs).first.knowledgeBase.question,
              isNot(contains('단축키')));
          expect(text,anyOf(contains('클릭'),contains('입력')));
        }
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
    for (var i = 0; i < 4; i++) {
      final clock = Stopwatch()..start();
      final refs = await store.search(attendeeQuestion);
      final answer = answerer.answerForQuery(attendeeQuestion, refs);
      clock.stop();
      expect(answerer.canAnswer(attendeeQuestion, refs), isTrue);
      expect(answer, contains('확인되지 않은 부분'));
      expect(answer, contains('참석자'));
      expect(answer, isNot(contains('하단')));
      expect(store.index.lastQueries.length, greaterThan(1));
      expect(store.index.lastQueries.length, lessThanOrEqualTo(4));
      expect(store.index.lastTotalCandidates, lessThanOrEqualTo(512));
      expect(clock.elapsedMilliseconds, lessThan(5000));
      timings.add({'stage': 'user-reported-navigation-$i', 'query': attendeeQuestion,
        'milliseconds': clock.elapsedMicroseconds / 1000,
        'queries': store.index.lastQueries, 'candidates': store.index.lastTotalCandidates,
        'answer': answer});
    }
    final qualityQueries = {
      '미팅개설 미팅개설에 어려움이 있습니다. 도와주세요': '즉시시작',
      '미팅 개설에 어려움을 겪고 있습니다. 도움을 부탁드립니다.': '즉시시작',
      '미팅 개설이 어려워요. 안내 부탁드립니다.': '즉시시작',
      '미팅 개설 방법을 잘 모르겠어요. 설명해 주세요.': '즉시시작',
      '휴지통 복원에 어려움이 있습니다. 도와주세요': '복원',
      '설문 대상자 1000명 지정에 어려움이 있습니다. 도와주세요': '1000명 조건',
      '메신저 v8.5.5 알림 설정에 어려움이 있습니다. 도와주세요': '버전 8.5.5',
      '미팅개설이 안되요 미팅개설을 하려면 어떤게 해야하나요?': '즉시시작',
      '미팅 개설을 하려면 어떻게 해야 하나요?': '즉시시작',
      '설문 대상자 1000명 지정 방법': '1000명 조건',
      '메신저 8.5.5 알림 설정 방법': '버전 8.5.5',
      '드라이브 파일 복원 방법 그리고 보관 기간': '보관',
      '드라이브 영구 삭제 파일 복원 방법': '영구',
    };
    for (final item in qualityQueries.entries) {
      final clock = Stopwatch()..start();
      final refs = await store.search(item.key);
      final answer = answerer.answerForQuery(item.key, refs);
      clock.stop();
      expect(answerer.canAnswer(item.key, refs), isTrue, reason: item.key);
      expect(answer, contains(item.value), reason: item.key);
      if (item.key.contains('미팅')) {
        expect(refs.where((r)=>r.knowledgeBase.question.contains('6.미팅 사용하기')),hasLength(1));
        final meeting=refs.singleWhere((r)=>r.knowledgeBase.question.contains('6.미팅 사용하기'));
        expect(await BundledManualService.imagesFor(meeting.knowledgeBase.id),hasLength(2));
        expect(answer, contains('권한'));
        expect(answer, contains('미팅'));
        if (item.key.contains('안되요') || item.key.contains('어려')) {
          expect(answer, contains('원인은 자료만으로'));
        }
      }
      if (item.key.contains('영구')) {
        expect(answer, contains('영구 삭제한 파일/폴더는 복원이 불가능'));
        expect(answer, isNot(contains('다음 순서')));
      }
      expect(clock.elapsedMilliseconds, lessThan(5000));
      expect(store.index.lastTotalCandidates, lessThanOrEqualTo(512));
      timings.add({'stage': 'quality-conditions', 'query': item.key,
        'milliseconds': clock.elapsedMicroseconds / 1000,
        'queries': store.index.lastQueries, 'candidates': store.index.lastTotalCandidates,
        'answer': answer});
    }
    final meetingRow=(pack['entries'] as List).cast<Map<String,dynamic>>()
        .singleWhere((e)=>e['id']=='manual-pack-works-2-0830');
    final storedAnswer=meetingRow['answer'] as String;
    await db.update('knowledge_base',{'answer':storedAnswer.replaceFirst(
      '[출처]', '미팅 개설 추가 운영 안내: 담당자 승인 후 진행합니다.\n\n[출처]')},
      where:'id=?',whereArgs:[meetingRow['id']]);
    final edited=await store.search('미팅 개설을 하려면 어떻게 해야 하나요?');
    expect(edited.any((r)=>r.knowledgeBase.id==meetingRow['id']),isTrue);
    expect(edited.any((r)=>r.knowledgeBase.id.startsWith('raw-')),isTrue);
    await db.update('knowledge_base',{'answer':storedAnswer},
      where:'id=?',whereArgs:[meetingRow['id']]);
    await store.refresh();
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
    expect(vm.similarVocs,hasLength(1));
    expect(vm.isAiConnected,isFalse);
    expect(clock.elapsedMilliseconds,lessThan(5000));
  });

  test('identical headings in different versions and sections stay distinct', () async {
    final db=await database();addTearDown(db.close);
    final store=OfflineSearchStore(db);
    await store.initialize(bundled:false,maintenance:false);
    for(final version in [1,2]) {
      await store.installOriginal({'id':'version-$version','filename':'동일제목.docx',
        'sha256':'000000000000000$version','project':'fixture','blocks':[
          for(var i=0;i<2;i++) {'id':'raw-version-$version-$i','section':0,'ordinal':i,
            'title':'복원 방법','text':'휴지통 복원 버튼을 선택하세요. 버전 $version 설명 $i',
            'ocr':'','images':[{'id':'image-$version-$i','kind':'screen'}]},
          if(version==2) {'id':'raw-repeated-heading','section':1,'ordinal':2,
            'title':'복원 방법','text':'휴지통 복원 버튼을 선택하세요. 별도 절의 제한 사항',
            'ocr':'','images':[]},
        ]});
    }
    for(var repeat=0;repeat<2;repeat++) {
      final refs=await store.search('휴지통 복원 버튼');
      expect(refs,hasLength(3));
      for(final version in [1,2]) {
        final ref=refs.singleWhere((r)=>r.knowledgeBase.answer.contains('버전 $version'));
        expect(ref.knowledgeBase.answer,contains('설명 0'));
        expect(ref.knowledgeBase.answer,contains('설명 1'));
        expect(await BundledManualService.imagesFor(ref.knowledgeBase.id),hasLength(2));
      }
      expect(refs.any((r)=>r.knowledgeBase.answer.contains('별도 절의 제한 사항')),isTrue);
    }
    expect(store.index.length,5); // Stored passages are never deleted by grouping.
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



