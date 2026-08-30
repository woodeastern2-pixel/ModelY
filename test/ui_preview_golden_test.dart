@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_harness.dart';

void main() {
  final previews = <(String, Size, ThemeMode)>[
    ('phone-light', const Size(390, 844), ThemeMode.light),
    ('tablet-light', const Size(1024, 768), ThemeMode.light),
    ('desktop-dark', const Size(1440, 900), ThemeMode.dark),
  ];

  for (final preview in previews) {
    testWidgets('${preview.$1} UI preview', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = preview.$2;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final harness = createUiHarness(themeMode: preview.$3);
      addTearDown(harness.viewModel.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('ui-preview-root')),
        matchesGoldenFile('goldens/${preview.$1}.png'),
      );
    });
  }
}
