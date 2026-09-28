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

void main() {
  setUpAll(loadUiHarnessFonts);
  for (final dark in [false, true]) {
    testWidgets('offline answer blocks approval (${dark ? "dark" : "light"})', (tester) async {
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
      expect(vm.hasAnswer, isFalse);
      expect(find.textContaining('등록된 질문은 답변으로 표시하지 않습니다'), findsOneWidget);
      expect(find.text('답변 승인 및 저장'), findsNothing);
      expect(find.text('평가 저장'), findsNothing);
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
