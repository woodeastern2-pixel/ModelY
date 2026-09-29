import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/demo_voc_store.dart';
import 'package:ai_voc_assistant/presentation/widgets/demo_data_dialog.dart';
import 'support/ui_harness.dart';

void main() {
  setUpAll(loadUiHarnessFonts);
  testWidgets('double tap is blocked and actual import result is shown', (tester) async {
    final pending = Completer<DemoImportResult>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DemoDataDialog(
      onImport: () { calls++; return pending.future; }, onClear: () async => 0))));
    await tester.tap(find.byKey(const Key('demo-import')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('demo-import')));
    expect(calls,1);
    pending.complete(const DemoImportResult(900,100));
    await tester.pumpAndSettle();
    expect(find.text('900건 추가 · 이미 등록된 100건 제외'), findsOneWidget);
  });
  testWidgets('failed import gives a retryable message', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DemoDataDialog(
      onImport: () async => throw StateError('test'), onClear: () async => 0))));
    await tester.tap(find.byKey(const Key('demo-import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('입력을 완료하지 못했습니다'),findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('demo-import'))).onPressed,isNotNull);
  });
  for (final width in [390.0,1440.0]) {
    testWidgets('demo dialog readable at $width and large text', (tester) async {
      tester.view.physicalSize = Size(width,900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness:width == 390 ? Brightness.light : Brightness.dark,
            fontFamily:'Pretendard'),
        builder: (context,child) => MediaQuery(
            data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(1.3)),child:child!),
        home: RepaintBoundary(key:boundary,child:Scaffold(body:DemoDataDialog(
          onImport:() async => const DemoImportResult(1000,0),onClear:() async => 0))),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(),isNull);
      expect(find.byKey(const Key('demo-import')),findsOneWidget);
      await tester.runAsync(() async {
        final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final screenshot = await render.toImage(pixelRatio:1);
        final bytes = await screenshot.toByteData(format:ui.ImageByteFormat.png);
        final file = File('test/goldens/demo-data-${width.toInt()}.png');
        await file.parent.create(recursive:true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        screenshot.dispose();
      });
      await tester.tap(find.byKey(const Key('demo-import')));
      await tester.pumpAndSettle();
      expect(find.text('1000건 추가 · 이미 등록된 0건 제외'),findsOneWidget);
      expect(tester.takeException(),isNull);
    });
  }
}
