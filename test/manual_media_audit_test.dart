import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/data/services/manual_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all bundled images decode, retain dimensions and resolve from every entry', () async {
    final pack = await BundledManualService.load();
    final entries = (pack['entries'] as List).cast<Map<String, dynamic>>();
    final images = (pack['images'] as Map<String, dynamic>);
    final used = <String>{};
    var transcriptions = 0;
    for (final entry in entries) {
      final attached = await BundledManualService.imagesFor(entry['id'] as String);
      expect(attached.map((e) => e['id']).toList(), entry['images']);
      used.addAll(attached.map((e) => e['id'] as String));
      final parsed = ManualContent.parse(entry['answer'] as String);
      if (parsed.transcription.isNotEmpty) {
        transcriptions++;
        expect(parsed.body, isNot(contains('[이미지에서 읽은 글자')));
        expect(parsed.body, contains('[출처]'));
      }
    }
    expect(used, images.keys.toSet());
    expect(used.length, 911);
    final rows = <Map<String, dynamic>>[];
    final ids = images.keys.toList()..sort();
    final output = Directory('test/goldens')..createSync(recursive: true);
    for (var offset = 0; offset < ids.length; offset += 72) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(const ui.Color(0xffeeeeee), ui.BlendMode.src);
      final decoded = <ui.Image>[];
      for (var index = offset; index < math.min(offset + 72, ids.length); index++) {
        final id = ids[index];
        final bytes = await BundledManualService.imageBytes(id);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final img = frame.image;
        codec.dispose();
        decoded.add(img);
        expect(img.width, greaterThan(0), reason: id);
        expect(img.height, greaterThan(0), reason: id);
        final metadata = images[id] as Map;
        if (metadata['width'] is int) expect(img.width, metadata['width'], reason: id);
        if (metadata['height'] is int) expect(img.height, metadata['height'], reason: id);
        rows.add({'id': id, 'width': img.width, 'height': img.height, 'bytes': bytes.length});
        final local = index - offset;
        final x = (local % 6) * 180.0;
        final y = (local ~/ 6) * 140.0;
        canvas.drawRect(ui.Rect.fromLTWH(x + 2, y + 2, 176, 136), ui.Paint()..color = const ui.Color(0xffffffff));
        final scale = math.min(2.0, math.min(172 / img.width, 110 / img.height));
        canvas.drawImageRect(img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            ui.Rect.fromLTWH(x + 4, y + 4, img.width * scale, img.height * scale), ui.Paint());
        final text = (ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 10))
          ..pushStyle(ui.TextStyle(color: const ui.Color(0xff111111)))
          ..addText('${index + 1} ${id.substring(0, 8)} ${img.width}x${img.height}')).build()
          ..layout(const ui.ParagraphConstraints(width: 172));
        canvas.drawParagraph(text, ui.Offset(x + 4, y + 120));
        text.dispose();
      }
      final picture = recorder.endRecording();
      final sheet = await picture.toImage(1080, 1680);
      final png = await sheet.toByteData(format: ui.ImageByteFormat.png);
      await File('${output.path}/manual-audit-${offset ~/ 72 + 1}.png')
          .writeAsBytes(png!.buffer.asUint8List());
      sheet.dispose();
      picture.dispose();
      for (final img in decoded) { img.dispose(); }
    }
    await File('${output.path}/manual-image-audit.json').writeAsString(jsonEncode({
      'entries': entries.length, 'images': rows.length,
      'entriesWithTranscription': transcriptions, 'results': rows,
    }));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
