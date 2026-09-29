import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/entities/response_entity.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/screens/voc/ai_answer_screen_v2.dart';
import 'package:ai_voc_assistant/presentation/screens/chat/ai_chat_screen.dart';
import 'support/ui_harness.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/data/seeds/brity_suite_manual_seed.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/knowledge_base_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/screens/knowledge_base/knowledge_base_screen.dart';

import 'package:ai_voc_assistant/domain/repositories/indexed_knowledge_repository.dart';
import 'package:ai_voc_assistant/data/services/offline_search_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'offline_original_search_test.dart' show database;
import 'offline_query_recovery_test.dart' show attendeeQuestion;

void main() {
  setUpAll(loadUiHarnessFonts);
  setUpAll(sqfliteFfiInit);
  for (final dark in [false, true]) {
    testWidgets('connected note request displays a review draft (${dark ? "dark" : "light"})', (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = SettingsViewModel(_Settings());
      final service = _ConnectedDraft();
      final vm = AiViewModel(_Knowledge(), _Vocs(), settings, aiService: service);
      addTearDown(vm.dispose);
      addTearDown(settings.dispose);
      await vm.checkCopilotConnection();
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiAnswerScreen(
            vocId: 'note-review', vocTitle: '쪽지 복사 시 서식 초기화',
            vocContent: '쪽지 내용을 복사하면 글자색과 진하게 서식이 초기화됩니다. 서식도 함께 복사되도록 개선해 주세요. 보낸 쪽지와 받은 쪽지의 보관 기간도 궁금합니다.',
            category: '기능 개선', customer: '시연 고객', project: 'Brity Messenger')))));
      await tester.pumpAndSettle();
      expect(service.calls, 1);
      expect(vm.hasAnswer, isTrue);
      expect(vm.error, isNull);
      expect(find.textContaining('쪽지 복사 시 글자색'), findsWidgets);
      expect(find.textContaining('연결된 AI로 작성한'), findsOneWidget);
      expect(find.text('AI 초안 · 담당자 확인 필요'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'connected-note-draft-${dark ? "dark" : "light"}');
    });
    testWidgets('reported attendee navigation uses indexed corpus and states missing location (${dark ? "dark" : "light"})', (tester) async {
      tester.view.physicalSize = const Size(1440, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = (await tester.runAsync(database))!;
      addTearDown(db.close);
      final store = OfflineSearchStore(db);
      await tester.runAsync(() async {
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
      });
      final settings = SettingsViewModel(_Settings());
      final vm = AiViewModel(_IndexedCorpus(store), _Vocs(), settings);
      addTearDown(vm.dispose);
      addTearDown(settings.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiAnswerScreen(
            vocId: 'attendee-location-check', vocTitle: '진행권 부여 방법',
            vocContent: attendeeQuestion, category: '기타', customer: '', project: '')))));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
        if (vm.hasAnswer || vm.error != null) break;
      }
      await tester.pumpAndSettle();
      expect(vm.isAiConnected, isFalse);
      expect(vm.hasAnswer, isTrue);
      expect(vm.similarVocs, isNotEmpty);
      expect(vm.answerResult!.answer, contains('확인되지 않은 부분'));
      expect(vm.answerResult!.answer, contains('확인된 관련 설명'));
      expect(vm.hasPartialAnswer, isTrue);
      expect(find.text('일부 근거 · 추가 확인 필요'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(find.textContaining('찾지 못했습니다'), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'attendee-navigation-${dark ? "dark" : "light"}');
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiAnswerScreen(
            key: ValueKey('quantity-condition'), vocId: 'quantity-check',
            vocTitle: '설문 대상자 지정', vocContent: '설문 대상자 1000명 지정 방법',
            category: '기타', customer: '', project: '')))));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
        if (!vm.isGenerating && (vm.hasAnswer || vm.error != null)) break;
      }
      await tester.pumpAndSettle();
      expect(vm.hasAnswer, isTrue);
      expect(vm.hasPartialAnswer, isTrue);
      expect(vm.answerResult!.answer, contains('1000명 조건'));
      expect(find.text('일부 근거 · 추가 확인 필요'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'quantity-condition-${dark ? "dark" : "light"}');
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiAnswerScreen(
            key: ValueKey('meeting-create'), vocId: 'meeting-create-check',
            vocTitle: '미팅개설', vocContent: '미팅개설에 어려움이 있습니다. 도와주세요',
            category: '기타', customer: '', project: '')))));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
        if (!vm.isGenerating && (vm.hasAnswer || vm.error != null)) break;
      }
      await tester.pumpAndSettle();
      expect(vm.similarVocs, hasLength(1));
      expect(vm.answerResult!.answer, contains('즉시시작'));
      expect(vm.answerResult!.answer, contains('권한'));
      expect(vm.hasPartialAnswer, isTrue);
      expect(tester.takeException(), isNull);
      for (var attempt = 0; attempt < 50; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
        if (tester.widgetList<RawImage>(find.byType(RawImage)).any((w) => w.image != null)) break;
      }
      expect(tester.widgetList<RawImage>(find.byType(RawImage)).any((w) => w.image != null), isTrue);
      expect(vm.answerResult!.answer, contains('선택한 기능에 따른 동작'));
      expect(vm.answerResult!.answer, isNot(contains('3. 예약하기')));
      await _capture(tester, key, 'meeting-help-${dark ? "dark" : "light"}');
      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpAndSettle();
      expect(vm.similarVocs, hasLength(1));
      expect(find.text('참고할 유사 사례가 없습니다.'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('자료 기반 답변 초안').last).height, lessThan(40));
      expect(tester.getSize(find.text('답변을 승인하기 전에 사실관계와 안내 절차를 확인해 주세요.')).height,
          lessThan(80));
      await _capture(tester, key, 'meeting-help-phone-${dark ? "dark" : "light"}');


    });
    testWidgets('schedule question composes an offline answer from the complete corpus (${dark ? "dark" : "light"})', (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pack = await tester.runAsync(BundledManualService.load);
      final rows = [...BritySuiteManualSeed.entries, ...(pack!['entries'] as List)];
      final entries = rows.map((r) => KnowledgeBaseEntity(
        id: r['id'] as String, question: r['question'] as String, answer: r['answer'] as String,
        category: '시스템매뉴얼', customer: r['sourceName'] as String?,
        project: r['project'] as String?, resolvedAt: DateTime(2026), createdAt: DateTime(2026))).toList();
      final settings = SettingsViewModel(_Settings());
      final vm = AiViewModel(_CorpusKnowledge(entries), _Vocs(), settings);
      addTearDown(vm.dispose);
      addTearDown(settings.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiAnswerScreen(
            vocId: 'schedule-check', vocTitle: '일정등록',
            vocContent: '일정 등록 되려면 어떻게 해야하나요?',
            category: '기타', customer: '', project: '')))));
      await tester.pumpAndSettle();
      expect(entries.length, 1008);
      expect(vm.isAiConnected, isFalse);
      expect(vm.hasAnswer, isTrue);
      expect(vm.answerResult!.answer, contains('다음 순서로 진행해 주세요.'));
      expect(vm.answerResult!.answer, contains('등록'));
      expect(find.textContaining('답변으로 사용할 매뉴얼이나 승인된 답변을 찾지 못했습니다'), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'schedule-offline-${dark ? "dark" : "light"}');
    });
    testWidgets('recall answer shows original images instead of raw transcription (${dark ? "dark" : "light"})', (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pack = await tester.runAsync(BundledManualService.load);
      final raw = (pack!['entries'] as List).cast<Map<String, dynamic>>().firstWhere((e) =>
          (e['question'] as String).contains('발신 취소') && (e['images'] as List).isNotEmpty);
      final entry = KnowledgeBaseEntity(id: raw['id'] as String,
          question: raw['question'] as String, answer: raw['answer'] as String,
          category: '시스템매뉴얼', customer: raw['sourceName'] as String,
          project: raw['project'] as String,
          resolvedAt: DateTime(2026), createdAt: DateTime(2026));
      final settings = SettingsViewModel(_Settings());
      final vm = AiViewModel(_RecallKnowledge(entry), _Vocs(), settings);
      addTearDown(vm.dispose);
      addTearDown(settings.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiAnswerScreen(
            vocId: 'recall-check', vocTitle: '메일 발신 취소 방법', vocContent: '',
            category: '문의', customer: '검증', project: 'Brity Mail')))));
      for (var attempt = 0; attempt < 100; attempt++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
        final images = tester.widgetList<RawImage>(find.byType(RawImage));
        if (images.isNotEmpty && images.every((i) => i.image != null)) break;
      }
      await tester.pumpAndSettle();
      expect(vm.hasAnswer, isTrue);
      expect(vm.answerResult!.answer, isNot(contains('[이미지에서 읽은 글자')));
      expect(find.textContaining('이미지 자동 인식 글자 확인'), findsOneWidget);
      expect(find.textContaining('원본 이미지'), findsWidgets);
      expect(tester.widgetList<RawImage>(find.byType(RawImage))
          .where((i) => i.image != null), isNotEmpty);
      expect(find.textContaining('Home [ oz'), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'recall-answer-images-${dark ? "dark" : "light"}');
    });
    testWidgets('manual counts include legacy sources (${dark ? "dark" : "light"})', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = SettingsViewModel(_Settings());
      final vm = KnowledgeBaseViewModel(_ManualKnowledge(), settings);
      addTearDown(vm.dispose);
      addTearDown(settings.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const KnowledgeBaseScreen()))));
      await tester.pumpAndSettle();
      expect(find.text('출처 2개 · 지식 항목 2개'), findsOneWidget);
      expect(vm.manualEntriesByFile['기존 영문 매뉴얼'], 1);
      expect(find.textContaining('질문 수가 아닙니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'manual-corpus-${dark ? "dark" : "light"}');
    });
    testWidgets('offline clarification is clearly distinguished from verified evidence (${dark ? "dark" : "light"})', (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = SettingsViewModel(_Settings());
      final vm = AiViewModel(_Knowledge(), _Vocs(), settings);
      addTearDown(vm.dispose);
      addTearDown(settings.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiAnswerScreen(
            vocId: 'current', vocTitle: '진행권 부여 방법',
            vocContent: '참석자 메뉴는 어디에 있나요?', category: '문의',
            customer: '테스트 고객', project: '미팅')))));
      await tester.pumpAndSettle();
      expect(vm.hasAnswer, isTrue);
      expect(vm.isClarificationAnswer, isTrue);
      expect(find.text('추가 확인용 초안'), findsOneWidget);
      expect(find.textContaining('검증된 해결 답변이 아닙니다'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'offline-answer-${dark ? "dark" : "light"}');
      await tester.pumpWidget(ChangeNotifierProvider.value(value: vm,
        child: MaterialApp(theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: RepaintBoundary(key: key, child: const AiChatScreen(previewSessions: [])))));
      await tester.pumpAndSettle();
      expect(find.text(AiViewModel.copilotUnavailable), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'offline-copilot-${dark ? "dark" : "light"}');
    });
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('test/goldens/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
class _Knowledge implements KnowledgeBaseRepository {
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
class _Vocs implements VocRepository {
  @override
  Future<List<VocEntity>> getAllVocs() async => [];
  @override
  Future<List<ResponseEntity>> getResponsesByVocId(String id) async => [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
class _Settings implements SettingsRepository {
  @override
  Future<Map<String, String>> getAllSettings() async => {};
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _ManualKnowledge extends _Knowledge {
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => [
    for (final old in [true, false]) KnowledgeBaseEntity(
      id: old ? 'brity-messenger-desktop-001' : 'manual-source-new',
      question: old ? 'User guide' : '복원 절차',
      answer: old ? 'Open Settings to configure notifications.' : '휴지통에서 파일을 선택한 뒤 복원합니다.',
      category: '시스템매뉴얼', customer: old ? '기존 영문 매뉴얼' : '새 문서.docx',
      project: old ? 'Brity Messenger' : 'manual-upload',
      resolvedAt: DateTime(2026), createdAt: DateTime(2026)),
  ];
}

class _RecallKnowledge extends _Knowledge {
  final KnowledgeBaseEntity entry;
  _RecallKnowledge(this.entry);
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => [entry];
}

class _CorpusKnowledge extends _Knowledge {
  final List<KnowledgeBaseEntity> entries;
  _CorpusKnowledge(this.entries);
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => entries;
}

class _IndexedCorpus implements KnowledgeBaseRepository, IndexedKnowledgeRepository {
  final OfflineSearchStore store;
  _IndexedCorpus(this.store);
  @override
  Future<List<SimilarVocResult>> searchOffline(String query, {String? excludeVocId}) =>
      store.search(query, excludeVocId: excludeVocId);
  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() =>
      throw StateError('The answer screen must use the index, not scan all entries');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}




// Model output is a deterministic fixture; this verifies routing and rendering,
// not the quality or availability of a user's actual model server.
class _ConnectedDraft extends AiService {
  int calls = 0;
  @override
  bool get isConfigured => true;
  @override
  Future<String> testConnection() async => 'connected';
  @override
  Future<AiAnswerResult> generateReviewDraft(String title, String content,
      List<SimilarVocResult> references) async {
    calls++;
    return const AiAnswerResult(
      answer: '안녕하세요. 쪽지 복사 시 글자색과 진하게 서식이 유지되지 않는다는 말씀을 확인했습니다. 서식 보존 기능의 지원 여부와 개선 가능 여부는 제품 담당자 확인이 필요합니다. 사용 중인 메신저 버전과 복사한 내용을 붙여넣는 프로그램을 알려주시면 확인에 도움이 됩니다.\n\n보낸 쪽지와 받은 쪽지의 보관 기간은 현재 확인된 자료만으로 확정하기 어렵습니다. 담당 관리자에게 적용된 보관 정책을 확인해 주세요.',
      confidence: 0, referencedCases: [],
      notes: '연결된 AI로 작성한 검토용 초안입니다. 확인되지 않은 정책과 기능은 담당자 확인이 필요합니다.');
  }
}
