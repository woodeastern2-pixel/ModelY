import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_harness.dart';

void main() {
  setUpAll(loadUiHarnessFonts);

  final profiles = <_WorkspaceProfile>[
    const _WorkspaceProfile('compact-android', Size(360, 640), 1),
    const _WorkspaceProfile('galaxy-s24', Size(384, 854), 1),
    const _WorkspaceProfile('large-phone', Size(412, 915), 1.15),
    const _WorkspaceProfile('small-tablet', Size(600, 960), 1),
    const _WorkspaceProfile('tablet-portrait', Size(720, 1024), 1),
    const _WorkspaceProfile('tablet-landscape', Size(1024, 720), 1.1),
    const _WorkspaceProfile('small-laptop', Size(1280, 720), 1),
    const _WorkspaceProfile('laptop', Size(1366, 768), 1),
    const _WorkspaceProfile('desktop', Size(1440, 900), 1),
    const _WorkspaceProfile('large-desktop', Size(1920, 1080), 1.3),
  ];

  for (var index = 0; index < profiles.length; index++) {
    final profile = profiles[index];
    final theme = index.isOdd ? ThemeMode.dark : ThemeMode.light;

    testWidgets(
      '${profile.name} keeps VOC queue and Copilot overflow-free',
      (tester) async {
        await _setViewport(tester, profile.size);

        final queueHarness = createWorkspaceHarness(
          view: WorkspaceHarnessView.vocQueue,
          themeMode: theme,
          textScale: profile.textScale,
        );
        addTearDown(queueHarness.dispose);
        await tester.pumpWidget(queueHarness.widget);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('voc-queue-hero')), findsOneWidget);
        expect(find.byKey(const Key('voc-queue-filters')), findsOneWidget);
        if (profile.size.width >= 1050) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('voc-queue-table')),
            240,
            scrollable: find.byKey(const Key('voc-queue-scroll')),
          );
          expect(find.byKey(const Key('voc-queue-table')), findsOneWidget);
        } else {
          await tester.scrollUntilVisible(
            find.byKey(const Key('voc-queue-card-voc-1042')),
            240,
            scrollable: find.byKey(const Key('voc-queue-scroll')),
          );
          expect(
            find.byKey(const Key('voc-queue-card-voc-1042')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        final copilotHarness = createWorkspaceHarness(
          view: WorkspaceHarnessView.copilot,
          themeMode: theme,
          textScale: profile.textScale,
        );
        addTearDown(copilotHarness.dispose);
        await tester.pumpWidget(copilotHarness.widget);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('copilot-home-hero')), findsOneWidget);
        expect(find.byKey(const Key('copilot-quick-actions')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('copilot-session-list')),
          240,
          scrollable: find.byKey(const Key('copilot-home-scroll')),
        );
        expect(find.byKey(const Key('copilot-session-list')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _WorkspaceProfile {
  const _WorkspaceProfile(this.name, this.size, this.textScale);

  final String name;
  final Size size;
  final double textScale;
}
