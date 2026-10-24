import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:ai_voc_assistant/data/services/offline_search_store.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/data/services/answer_evidence_selector.dart';
import 'package:ai_voc_assistant/data/services/manual_language_policy.dart';
import 'package:ai_voc_assistant/presentation/widgets/manual_content_view.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native SQLite and Korean originals answer with zero FAQ',
      (tester) async {
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
    final db = await openDatabase(inMemoryDatabasePath);
    await db.execute(
        'CREATE TABLE knowledge_base(id TEXT PRIMARY KEY,question TEXT,answer TEXT,category TEXT,customer TEXT,project TEXT,voc_id TEXT)');
    await db.execute(
        'CREATE TABLE vocs(id TEXT PRIMARY KEY,title TEXT,content TEXT,category TEXT,customer TEXT,project TEXT)');
    await db.execute(
        'CREATE TABLE responses(id TEXT PRIMARY KEY,voc_id TEXT,content TEXT,status TEXT,updated_at TEXT)');
    final store = OfflineSearchStore(db);
    final startup = Stopwatch()..start();
    try {
      await store.initialize(maintenance: false);
      startup.stop();
      expect(await db.query('knowledge_base'), isEmpty);
      final documents = await db.query('original_documents');
      expect(documents, hasLength(7));
      expect(
          documents.every((r) => !ManualLanguagePolicy.excludedDocument(
              jsonDecode(r['content'] as String))),
          isTrue);
      final samples = <Map<String, Object?>>[];
      final cases = {
        '메신저 알림 설정': '환경설정',
        '메신저 메시지 삭제': '다른 사람의 대화창에서는 메시지가 삭제되지 않습니다',
        '드라이브 다른 사람이 편집 중인 파일 취소': '강제 취소',
        '설문 500명': '500',
      };
      for (var repeat = 0; repeat < 2; repeat++) {
        for (final item in cases.entries) {
          final timer = Stopwatch()..start();
          final refs = await store.search(item.key);
          final answer = LocalAnswerService().answerForQuery(item.key, refs);
          timer.stop();
          expect(answer, contains(item.value), reason: item.key);
          expect(
              refs.every((r) => r.knowledgeBase.id.startsWith('raw-')), isTrue);
          expect(store.index.lastTotalCandidates, lessThanOrEqualTo(512));
          expect(timer.elapsedMilliseconds, lessThan(5000));
          samples.add({
            'query': item.key,
            'repeat': repeat,
            'ms': timer.elapsedMilliseconds,
            'candidates': store.index.lastTotalCandidates,
            'sources': refs.map((r) => r.knowledgeBase.id).toList()
          });
        }
      }
      final unknown = await store.search('급여 지급일 세금 계산');
      expect(LocalAnswerService().canAnswer('급여 지급일 세금 계산', unknown), isFalse);
      final refs = AnswerEvidenceSelector.select(
          '메신저 알림 설정', await store.search('메신저 알림 설정'));
      final source = refs.first.knowledgeBase;
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
                body: SingleChildScrollView(
                    child: ManualContentView(
                        content: source.answer, entryId: source.id)))));
        await tester.pumpAndSettle();
        expect(
            find.byKey(ValueKey('manual-body-${source.id}')), findsOneWidget);
        expect(find.text('영문 원문과 출처 보기'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      binding.reportData = {
        'platform': Platform.operatingSystem,
        'faqCount': 0,
        'originalDocuments': documents.length,
        'indexedPassages': store.index.length,
        'prepareMs': startup.elapsedMilliseconds,
        'samples': samples
      };
      // Captured in the CI log and integration driver report.
      // ignore: avoid_print
      print('KOREAN_MANUAL_RUNTIME ${jsonEncode(binding.reportData)}');
    } finally {
      store.dispose();
      await db.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
