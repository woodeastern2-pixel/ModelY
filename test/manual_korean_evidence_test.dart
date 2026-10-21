import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/manual_content.dart';
import 'package:ai_voc_assistant/data/services/reviewed_manual_translation.dart';
import 'package:ai_voc_assistant/presentation/widgets/manual_content_view.dart';

void main() {
  final fixture = jsonDecode(File('test/fixtures/recorded-notification-evidence.json')
      .readAsStringSync()) as Map<String, dynamic>;
  final evidence = (fixture['supplied_evidence'] as List).cast<Map<String, dynamic>>();

  test('both actual cited sources display reviewed Korean without changing originals', () {
    for (final entry in evidence) {
      final source = entry['answer'] as String;
      final parsed = ManualContent.forDisplay(source, entryId: entry['id'] as String);
      expect(parsed.body, ReviewedManualTranslation.notification);
      expect(parsed.body, contains('선택하면 대화창을 보고 있는 동안 소리가 나지 않습니다'));
      expect(parsed.body, contains('알림창에 메시지 내용을 표시할지'));
      expect(parsed.body, contains('2020년판 22쪽'));
      expect(RegExp(r'^\s*[a-z]\s*$', multiLine: true).hasMatch(parsed.body), isFalse);
      expect(parsed.original, contains('Check to mute sounds'));
      expect(parsed.original, contains('[출처]'));
      expect(ManualContent.parse(source).body, source.trim());
      expect(ManualContent.forDisplay('$source\n사용자가 추가한 주의사항',
          entryId: entry['id'] as String).original, isEmpty);
      expect(ManualContent.forDisplay(source, entryId: 'user-manual').original, isEmpty);
    }
    expect(ManualContent.forDisplay(evidence.first['answer'] as String,
        entryId: evidence.first['id'] as String).original,
        contains('/__icsFiles/'));
  });

  test('diagram labels are removed only when matching definitions exist', () {
    const source = '그림\n\na\n\nb\nc\n\n\na. 첫 번째\nb. 두 번째\nc. 세 번째';
    expect(ManualContent.cleanDiagramLabels(source),
        '그림\n\na. 첫 번째\nb. 두 번째\nc. 세 번째');
    const code = '값 목록\na\nb\nc\n  a + b = c';
    expect(ManualContent.cleanDiagramLabels(code), code);
    expect(ManualContent.cleanDiagramLabels('a. 첫 번째\nb. 두 번째\nc. 세 번째'),
        'a. 첫 번째\nb. 두 번째\nc. 세 번째');
  });

  for (final brightness in Brightness.values) {
    testWidgets('Korean is default and original is opt-in in $brightness', (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final entry = evidence.last;
      await tester.runAsync(() async {
        final font = FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.otf'));
        await font.load();
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness, fontFamily: 'Pretendard'),
        builder: (_, child) => RepaintBoundary(key: boundary, child: child!),
        home: Scaffold(body: SingleChildScrollView(child: ManualContentView(
          content: entry['answer'] as String, entryId: entry['id'] as String))),
      ));
      await tester.pumpAndSettle();
      final body = tester.widget<SelectableText>(find.byKey(
          ValueKey('manual-body-${entry['id']}')));
      expect(body.data, ReviewedManualTranslation.notification);
      expect(find.textContaining('Check to mute sounds'), findsNothing);
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()
            as RenderRepaintBoundary).toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('test/goldens/evidence-korean-${brightness.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.ensureVisible(find.text('영문 원문과 출처 보기'));
      await tester.tap(find.text('영문 원문과 출처 보기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check to mute sounds'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
