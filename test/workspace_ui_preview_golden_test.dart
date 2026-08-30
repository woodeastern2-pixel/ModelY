@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_harness.dart';

void main() {
  setUpAll(loadUiHarnessFonts);

  final previews = <_WorkspacePreview>[
    const _WorkspacePreview(
      'voc-phone-light',
      Size(390, 844),
      ThemeMode.light,
      WorkspaceHarnessView.vocQueue,
    ),
    const _WorkspacePreview(
      'voc-desktop-dark',
      Size(1440, 900),
      ThemeMode.dark,
      WorkspaceHarnessView.vocQueue,
    ),
    const _WorkspacePreview(
      'copilot-phone-light',
      Size(390, 844),
      ThemeMode.light,
      WorkspaceHarnessView.copilot,
    ),
    const _WorkspacePreview(
      'copilot-desktop-dark',
      Size(1440, 900),
      ThemeMode.dark,
      WorkspaceHarnessView.copilot,
    ),
  ];

  for (final preview in previews) {
    testWidgets('${preview.name} workspace preview', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = preview.size;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final harness = createWorkspaceHarness(
        view: preview.view,
        themeMode: preview.themeMode,
      );
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('workspace-preview-root')),
        matchesGoldenFile('goldens/${preview.name}.png'),
      );
    });
  }
}

class _WorkspacePreview {
  const _WorkspacePreview(
    this.name,
    this.size,
    this.themeMode,
    this.view,
  );

  final String name;
  final Size size;
  final ThemeMode themeMode;
  final WorkspaceHarnessView view;
}
