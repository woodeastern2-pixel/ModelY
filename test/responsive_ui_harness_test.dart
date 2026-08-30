import 'package:ai_voc_assistant/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ui_harness.dart';

void main() {
  setUpAll(loadUiHarnessFonts);

  final profiles = <_ViewportProfile>[
    const _ViewportProfile('compact-android', Size(360, 640), 1),
    const _ViewportProfile('galaxy-s24', Size(384, 854), 1),
    const _ViewportProfile('large-phone', Size(412, 915), 1.15),
    const _ViewportProfile('small-tablet', Size(600, 960), 1),
    const _ViewportProfile('tablet-portrait', Size(720, 1024), 1),
    const _ViewportProfile('tablet-landscape', Size(1024, 720), 1.1),
    const _ViewportProfile('small-laptop', Size(1280, 720), 1),
    const _ViewportProfile('laptop', Size(1366, 768), 1),
    const _ViewportProfile('desktop', Size(1440, 900), 1),
    const _ViewportProfile('large-desktop', Size(1920, 1080), 1.3),
  ];

  for (final profile in profiles) {
    testWidgets(
      '${profile.name} renders the shell and dashboard without overflow',
      (tester) async {
        await _setViewport(tester, profile.size);
        final harness = createUiHarness(textScale: profile.textScale);
        addTearDown(harness.viewModel.dispose);

        await tester.pumpWidget(harness.widget);
        await tester.pumpAndSettle();

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byKey(const Key('dashboard-hero')), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (profile.size.width < 720) {
          expect(find.byKey(const Key('app-shell-mobile')), findsOneWidget);
          expect(find.byKey(const Key('app-shell-mobile-nav')), findsOneWidget);
        } else if (profile.size.width < 1180) {
          expect(find.byKey(const Key('app-shell-rail')), findsOneWidget);
          expect(find.byKey(const Key('desktop-nav-compact')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('app-shell-wide')), findsOneWidget);
          expect(find.byKey(const Key('desktop-nav-expanded')), findsOneWidget);
        }
      },
    );
  }

  testWidgets(
    'mobile More keeps collaboration, settings and privacy reachable',
    (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final harness = createUiHarness();
      addTearDown(harness.viewModel.dispose);

      await tester.pumpWidget(harness.widget);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mobile-nav-more')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('more-collaboration')), findsOneWidget);
      expect(find.byKey(const Key('more-settings')), findsOneWidget);
      expect(find.byKey(const Key('more-privacy')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop navigation swaps cached workspace content', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final harness = createUiHarness();
    addTearDown(harness.viewModel.dispose);

    await tester.pumpWidget(harness.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('desktop-nav-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('harness-page-1')), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _ViewportProfile {
  const _ViewportProfile(this.name, this.size, this.textScale);

  final String name;
  final Size size;
  final double textScale;
}
