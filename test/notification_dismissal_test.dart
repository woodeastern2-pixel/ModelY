import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_voc_assistant/core/theme/app_theme.dart';
import 'package:ai_voc_assistant/presentation/widgets/dismissible_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    for (final phone in [false, true]) {
      testWidgets('notices close and reset: dark=$dark phone=$phone', (tester) async {
        tester.view.physicalSize = phone ? const Size(412, 915) : const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        final messenger = GlobalKey<ScaffoldMessengerState>();
        Future<void> show(String phase, String text) async {
          await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            scaffoldMessengerKey: messenger,
            home: RepaintBoundary(key: boundary, child: Scaffold(
              appBar: AppBar(title: const Text('VOC 목록')),
              body: const Center(child: Text('알림 닫기는 처리 결과를 변경하지 않습니다.')),
              bottomNavigationBar: DismissibleNotice(
                key: ValueKey(phase),
                child: Padding(padding: const EdgeInsets.all(16),
                  child: Text(text)),
              ),
            )),
          ));
          await tester.pumpAndSettle();
        }
        await show('running', '일괄 처리 중');
        await tester.tap(find.byTooltip('알림 닫기'));
        await tester.pumpAndSettle();
        await show('running', '다음 항목 처리 중');
        expect(find.text('다음 항목 처리 중'), findsNothing,
            reason: 'progress updates must not reopen a dismissed notice');
        await show('stopped', '일괄 처리를 중지했습니다. 완료 8건 · 실패 51건');
        expect(find.textContaining('중지했습니다'), findsOneWidget);
        messenger.currentState!.showSnackBar(const SnackBar(
          content: Text('자료 등록 알림'),
          duration: Duration(minutes: 1),
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('test/goldens/notification-${phone ? "phone" : "desktop"}-${dark ? "dark" : "light"}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.descendant(of: find.byType(SnackBar), matching: find.byType(IconButton)));
        await tester.pumpAndSettle();
        expect(find.text('자료 등록 알림'), findsNothing);
        await tester.tap(find.byTooltip('알림 닫기'));
        await tester.pumpAndSettle();
        expect(find.textContaining('중지했습니다'), findsNothing);
        await show('running', '새 일괄 처리');
        expect(find.text('새 일괄 처리'), findsOneWidget);
        messenger.currentState!.showSnackBar(const SnackBar(content: Text('일반 알림')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('일반 알림'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
