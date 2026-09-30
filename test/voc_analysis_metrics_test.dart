import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/presentation/widgets/voc_analysis_metrics.dart';
import 'support/ui_harness.dart';

void main() {
  setUpAll(loadUiHarnessFonts);
  final now = DateTime(2026, 9, 30);
  VocEntity sample({bool analyzed = true}) => VocEntity(
    id: 'help-preview', title: '원격제어 기능 개선 요청', content: '사용자 편의 기능 개선 요청입니다.',
    category: '개선요청', customer: '고객', project: 'Brity Meeting', priority: 'MEDIUM',
    status: 'OPEN', createdAt: now, updatedAt: now,
    businessScore: analyzed ? 1 : null, aiCategory: analyzed ? '개선요청' : null,
    categoryScore: analyzed ? .95 : null, urgency: analyzed ? 'Medium' : null,
    urgencyScore: analyzed ? .7 : null, department: analyzed ? '플랫폼운영팀' : null,
    departmentScore: analyzed ? .9 : null, assignee: '홍길동', assigneeScore: .7,
    duplicateScore: analyzed ? 1 : null, jiraRequired: true, jiraScore: .85,
  );
  Widget app(VocEntity voc, GlobalKey boundary, {bool dark = false, double scale = 1}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    builder: (context, child) => RepaintBoundary(key: boundary, child: MediaQuery(data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale)), child: child!)),
    home: Scaffold(body: SingleChildScrollView(
      padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text('AI 분석 결과', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('각 항목의 ⓘ에 마우스를 올리거나 클릭하면 의미와 점수 해석을 확인할 수 있습니다.'),
          const SizedBox(height: 18), VocAnalysisMetrics(voc: voc)],
      ),
    )),
  );
  const labels = {'business': '업무 관련성', 'category': '추천 문의 유형', 'urgency': '긴급도',
    'department': '검토 부서', 'duplicate': '중복 판단 점수'};

  for (final dark in [false, true]) {
    for (final width in [390.0, 1440.0]) {
      testWidgets('analysis explanations click and fit $width ${dark ? "dark" : "light"}', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(app(sample(), key, dark: dark, scale: width == 390 ? 1.6 : 1));
        await tester.pumpAndSettle();
        expect(find.text('추천 담당자'), findsNothing);
        expect(find.text('Jira 등록'), findsNothing);
        expect(find.text('홍길동'), findsNothing);
        expect(find.text('Medium'), findsNothing);
        expect(find.text('보통'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('판단 점수 100%'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'analysis-help-${width.toInt()}-${dark ? "dark" : "light"}');
        for (final entry in labels.entries) {
          final help = find.byKey(ValueKey('analysis-help-${entry.key}'));
          await tester.ensureVisible(help);
          await tester.tap(help);
          await tester.pumpAndSettle();
          expect(find.text('${entry.value} 안내'), findsOneWidget);
          expect(find.textContaining(entry.key == 'duplicate' ? '문장 일치율은 아닙니다' : '실제 정답 확률'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (entry.key == 'duplicate' && width == 1440) {
            await capture(tester, key, 'analysis-help-dialog-${dark ? "dark" : "light"}');
          }
          await tester.tap(find.widgetWithText(TextButton, '닫기'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        }
      });
    }
  }
  testWidgets('mouse hover explains the score without a click', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(sample(), GlobalKey()));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('analysis-help-business'))));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('실제 정답 확률이나 검증된 정확도가 아니며'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('missing analysis does not display invented scores', (tester) async {
    await tester.pumpWidget(app(sample(analyzed: false), GlobalKey()));
    expect(find.text('분석 전'), findsNWidgets(5));
    expect(find.text('판단 점수 없음'), findsNWidgets(4));
    expect(find.text('100%'), findsNothing);
  });
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('test/goldens/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
