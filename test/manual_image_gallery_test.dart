import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/presentation/widgets/manual_image_gallery.dart';

void main() {
  testWidgets('manual image gallery opens its offline source image', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final loader = FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
      await loader.load();
    });
    final pack = await tester.runAsync(BundledManualService.load);
    final entries = (pack!['entries'] as List).cast<Map<String, dynamic>>();
    final entry = entries.firstWhere((e) => (e['images'] as List).length == 1);
    final id = entry['id'] as String;
    final images = await tester.runAsync(() => BundledManualService.imagesFor(id));
    await tester.runAsync(() => BundledManualService.imageBytes(images!.first['id'] as String));
    final boundary = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'Pretendard'),
      builder: (_, child) => RepaintBoundary(key: boundary, child: child!),
      home: Scaffold(appBar: AppBar(title: const Text('지식 자료')),
        body: SingleChildScrollView(padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry['question'] as String),
            const SizedBox(height: 16),
            ManualImageGallery(entryId: id),
          ]),
        ),
      ),
    ));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('매뉴얼 원본 이미지 1개 보기'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('test/goldens/manual-knowledge-desktop.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
