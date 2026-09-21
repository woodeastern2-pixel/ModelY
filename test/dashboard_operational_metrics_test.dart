import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_harness.dart';

void main() {
  setUpAll(loadUiHarnessFonts);

  testWidgets('dashboard shows only observable operational metrics', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final harness = createUiHarness(includeShell: false);
    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('dashboard-operational-summary')),
      findsOneWidget,
    );
    expect(find.text('운영 현황 요약'), findsOneWidget);
    expect(find.text('우선 처리 VOC'), findsOneWidget);
    expect(find.text('최근 30일 접수'), findsOneWidget);
    expect(find.text('AI 작성 답변'), findsOneWidget);
    expect(find.text('최근 늘어난 키워드'), findsOneWidget);

    for (final removed in [
      'AI 분석 정확도',
      '월 예상 순절감액',
      'ROI',
      '투자비 회수 예상 기간',
      'AI 활용 효과',
      '중복 감소율',
      '산정 기준',
      'AI 권장 조치',
    ]) {
      expect(find.text(removed), findsNothing,
          reason: '$removed should be removed');
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    harness.viewModel.dispose();
    await tester.pump();
  });
}
