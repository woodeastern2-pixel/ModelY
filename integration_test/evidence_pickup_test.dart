import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_voc_assistant/main.dart' as app;
import 'package:ai_voc_assistant/core/database/database_helper.dart';
import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/data/services/manual_content.dart';
import 'package:ai_voc_assistant/data/services/reviewed_manual_translation.dart';
import 'package:ai_voc_assistant/presentation/screens/home/home_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/knowledge_base/knowledge_base_screen.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/knowledge_base_viewmodel.dart';

/// Pickup of the real knowledge screen, opening the exact manual cited by the
/// previously recorded model response. No inference is simulated or replaced.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.shouldPropagateDevicePointerEvents = true;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('plugin.csdcorp.com/speech_to_text'),
          (call) async => call.method == 'initialize' || call.method == 'has_permission'
              ? false : null);

  testWidgets('open the actually cited manual in Korean', (tester) async {
    Directory('artifacts').createSync(recursive: true);
    Future<void> pause(int ms) => tester.pump(Duration(milliseconds: ms));
    Future<void> waitFor(bool Function() condition, String name) async {
      final timer = Stopwatch()..start();
      while (!condition()) {
        if (timer.elapsed.inSeconds > 180) throw StateError('Timeout: $name');
        await pause(250);
      }
      await pause(300);
    }
    Future<void> click(Finder finder) async {
      await tester.ensureVisible(finder.first);
      await pause(200);
      final point = tester.getCenter(finder.first);
      await Process.run('xdotool', ['mousemove', '${point.dx.round()}', '${point.dy.round()}']);
      await Process.run('xdotool', ['click', '1']);
      await pause(600);
    }
    Future<void> screenshot(String name) async {
      await Process.run('ffmpeg', ['-y', '-v', 'error', '-f', 'x11grab',
        '-video_size', '1600x1000', '-i', Platform.environment['DISPLAY']!,
        '-frames:v', '1', 'artifacts/$name.png']);
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await DatabaseHelper.instance.database;
    await db.insert(AppConstants.tableSettings, {
      'key': AppConstants.settingThemeMode, 'value': 'light',
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final fixture = jsonDecode(File('test/fixtures/recorded-notification-evidence.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final cited = (fixture['supplied_evidence'] as List).first as Map<String, dynamic>;
    final rows = await db.query(AppConstants.tableKnowledgeBase,
        where: 'id = ?', whereArgs: [cited['id']]);
    expect(rows.single['answer'], cited['answer']);
    expect((fixture['referenced_case_ids'] as List), contains(cited['id']));

    app.main();
    await waitFor(() => find.byType(HomeScreen).evaluate().isNotEmpty, 'startup');
    await Process.run('wmctrl', ['-r', 'ai_voc_assistant', '-b', 'add,fullscreen']);
    await pause(1800);
    await click(find.byKey(const Key('desktop-nav-3')));
    final vm = tester.element(find.byType(KnowledgeBaseScreen)).read<KnowledgeBaseViewModel>();
    await waitFor(() => !vm.isLoading, 'knowledge loaded');
    final search = find.byWidgetPredicate((w) => w is TextField &&
        w.decoration?.hintText == '질문, 답변 또는 매뉴얼 검색');
    await click(search);
    await Clipboard.setData(ClipboardData(text: cited['question'] as String));
    await Process.run('xdotool', ['key', '--clearmodifiers', 'ctrl+a', 'ctrl+v']);
    await waitFor(() => vm.searchQuery == cited['question'] &&
        find.text(cited['question'] as String).evaluate().isNotEmpty, 'cited source search');
    await pause(500);
    final log = File('artifacts/evidence-recorder.log').openWrite();
    final recorder = await Process.start('ffmpeg', ['-y', '-v', 'warning',
      '-f', 'x11grab', '-draw_mouse', '0', '-framerate', '30',
      '-video_size', '1600x1000', '-i', Platform.environment['DISPLAY']!,
      '-an', '-c:v', 'libx264', '-preset', 'ultrafast', '-threads', '1',
      '-crf', '20', '-pix_fmt', 'yuv420p', 'artifacts/evidence-pickup.mp4']);
    recorder.stdout.drain<void>();
    recorder.stderr.transform(utf8.decoder).listen(log.write);
    final clock = Stopwatch()..start();
    try {
      await pause(800);
      await click(find.text(cited['question'] as String));
      await pause(1200);
      final bodyFinder = find.byKey(ValueKey('manual-body-${cited['id']}'));
      await tester.ensureVisible(bodyFinder);
      await pause(1000);
      final body = tester.widget<SelectableText>(bodyFinder).data!;
      expect(body, ReviewedManualTranslation.notification);
      expect(RegExp(r'^\s*[a-z]\s*$', multiLine: true).hasMatch(body), isFalse);
      expect(find.textContaining('Check to mute sounds'), findsNothing);
      final readyAt = clock.elapsedMilliseconds / 1000;
      await screenshot('evidence-korean-light');
      await pause(15000);
      final parsed = ManualContent.forDisplay(cited['answer'] as String,
          entryId: cited['id'] as String);
      File('artifacts/evidence-verification.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
        'success': true, 'source_id': cited['id'],
        'source_matches_recorded_citation': true, 'korean_default': true,
        'original_collapsed': true, 'detached_labels_absent': true,
        'screen': 'production KnowledgeBaseScreen and shared ManualContentView',
        'pickup_only': true, 'new_model_inference': false,
        'prior_model': fixture['model'], 'prior_answer': fixture['answer'],
        'displayed_body': body, 'original_retained': parsed.original.contains('[출처]'),
        'ready_at': readyAt, 'duration': clock.elapsedMilliseconds / 1000,
      }));
    } finally {
      recorder.stdin.writeln('q');
      await recorder.stdin.flush();
      await recorder.exitCode;
      await log.close();
    }
    expect(tester.takeException(), isNull);
  });
}
