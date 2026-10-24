import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/manual_content.dart';
import 'package:ai_voc_assistant/presentation/widgets/manual_content_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> entry;
  setUpAll(() async {
    final pack = jsonDecode(
      await rootBundle.loadString('assets/manuals/brity_documents.json'),
    ) as Map<String, dynamic>;
    entry = (pack['entries'] as List).cast<Map<String, dynamic>>().singleWhere(
      (e) => e['id'] == 'manual-pack-works-3-0671',
    );
  });
  test(
    'Korean source keeps notification restrictions and source attribution',
    () {
      final parsed = ManualContent.forDisplay(
        entry['answer'] as String,
        entryId: entry['id'] as String,
      );
      expect(parsed.body, contains('모든 알림을 받을 수 없습니다'));
      expect(parsed.body, contains('VIP/키워드/나를 언급한 메시지 알림은 받습니다'));
      expect(parsed.body, contains('brityworks_매뉴얼3.docx'));
      expect(parsed.original, isEmpty);
      expect(parsed.transcription, isNotEmpty);
      expect(parsed.body, isNot(contains('2020년판')));
    },
  );
  test('diagram labels are removed only when matching definitions exist', () {
    const source = '그림\n\na\n\nb\nc\n\n\na. 첫 번째\nb. 두 번째\nc. 세 번째';
    expect(
      ManualContent.cleanDiagramLabels(source),
      '그림\n\na. 첫 번째\nb. 두 번째\nc. 세 번째',
    );
    const code = '값 목록\na\nb\nc\n  a + b = c';
    expect(ManualContent.cleanDiagramLabels(code), code);
  });
  for (final brightness in Brightness.values) {
    for (final width in [390.0, 1440.0]) {
      testWidgets('Korean original evidence at $width in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SingleChildScrollView(
                child: ManualContentView(
                  content: entry['answer'] as String,
                  entryId: entry['id'] as String,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final body = tester.widget<SelectableText>(
          find.byKey(ValueKey('manual-body-${entry['id']}')),
        );
        expect(body.data, contains('메인 메뉴의 환경설정을 클릭하세요'));
        expect(find.text('영문 원문과 출처 보기'), findsNothing);
        expect(find.text('이미지 자동 인식 글자 확인'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
