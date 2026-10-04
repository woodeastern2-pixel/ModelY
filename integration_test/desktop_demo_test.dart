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
import 'package:ai_voc_assistant/presentation/screens/home/home_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/voc/voc_detail_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/voc/ai_answer_screen_v2.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/ai_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/voc_viewmodel.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const mode = String.fromEnvironment('DEMO_MODE', defaultValue: 'no-llm');
  const llm = mode == 'llm';
  testWidgets('VOC Mate actual desktop scenario', (tester) async {
    const dir = 'artifacts';
    Directory(dir).createSync(recursive: true);
    final marks = <Map<String, Object?>>[];
    final watch = Stopwatch();
    Process? recorder;
    final recordingLog = File('$dir/$mode-recording.log').openWrite();
    Future<void> pause([int ms = 1500]) async {
      await tester.pump(Duration(milliseconds: ms));
    }
    Future<void> waitFor(bool Function() condition, String step,
        [int seconds = 90]) async {
      final timer = Stopwatch()..start();
      while (!condition()) {
        if (timer.elapsed.inSeconds > seconds) {
          throw StateError('Timed out: $step');
        }
        await tester.pump(const Duration(milliseconds: 250));
      }
      await pause(600);
    }
    Future<void> mark(String label) async {
      marks.add({'seconds': watch.elapsedMilliseconds / 1000, 'step': label});
      print('DEMO_STEP $mode $label');
      final number = marks.length.toString().padLeft(2, '0');
      await Process.run('ffmpeg', [
        '-y', '-loglevel', 'error', '-f', 'x11grab', '-video_size', '1600x1000',
        '-i', Platform.environment['DISPLAY']!, '-frames:v', '1',
        '$dir/$mode-$number.png',
      ]);
      File('$dir/$mode-steps.json')
          .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(marks));
    }
    Future<void> visible(Finder target) async {
      expect(target, findsWidgets);
      await tester.ensureVisible(target.first);
      await pause(700);
    }
    Future<void> click(Finder target) async {
      await visible(target);
      final point = tester.getCenter(target.first);
      await Process.run('xdotool',
          ['mousemove', point.dx.round().toString(), point.dy.round().toString()]);
      await pause(350);
      await tester.tap(target.first);
      await pause();
    }
    Future<void> type(Finder field, String value) async {
      await click(field);
      for (var end = 4; end < value.length; end += 4) {
        await tester.enterText(field.first, value.substring(0, end));
        await pause(170);
      }
      await tester.enterText(field.first, value);
      await pause(1500);
    }
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await DatabaseHelper.instance.database;
      // A fresh runner holds only bundled manuals and scenario data.
      // Configure user settings; do not seed answers or business records.
      final settings = <String, String>{
        AppConstants.settingAiAutoAnswerOnVocRegister: 'false',
        AppConstants.settingAiMaxTokens: '384',
        AppConstants.settingAiTemperature: '0.1',
        if (llm) AppConstants.settingOllamaModel: 'qwen2.5:0.5b',
        if (llm) 'ai_connection_configured': 'true',
      };
      for (final entry in settings.entries) {
        await db.insert(AppConstants.tableSettings, {
          'key': entry.key, 'value': entry.value,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      app.main();
      await waitFor(() => find.byType(HomeScreen).evaluate().isNotEmpty,
          'application startup', 150);
      await Process.run('wmctrl', ['-r', 'ai_voc_assistant', '-b', 'add,fullscreen']);
      await pause(2500);
      final outputName = llm ? 'VOC_Mate_LLM_Actual' : 'VOC_Mate_No_LLM_Actual';
      recorder = await Process.start('ffmpeg', [
        '-y', '-loglevel', 'warning', '-f', 'x11grab', '-draw_mouse', '1',
        '-framerate', '30', '-video_size', '1600x1000',
        '-i', Platform.environment['DISPLAY']!,
        '-an', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20',
        '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
        '$dir/$outputName.mp4',
      ]);
      recorder.stdout.drain<void>();
      recorder.stderr.transform(utf8.decoder).listen(recordingLog.write);
      watch.start();
      await pause(3000);
      await mark('앱 실행 및 현황 확인');
      await click(find.text('VOC 목록'));
      await mark('문의 목록 확인');
      await click(find.byKey(const Key('voc-register-primary')));
      await type(find.widgetWithText(TextFormField, '제목 *'),
          '브리티 드라이브 삭제 파일 복원 문의');
      await type(find.widgetWithText(TextFormField, '내용 *'),
          '브리티 드라이브에서 업무 파일을 실수로 삭제했습니다. 휴지통에 있는 파일을 원래 위치로 복원할 수 있나요?');
      await type(find.widgetWithText(TextFormField, '고객명 (선택)'), '시연 담당자');
      await mark('새 문의 입력');
      await click(find.ancestor(of: find.text('VOC 등록'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
      await waitFor(() => find.byType(VocDetailScreen).evaluate().isNotEmpty,
          'registered detail');
      final detailContext = tester.element(find.byType(VocDetailScreen));
      final vocVm = detailContext.read<VocViewModel>();
      final aiVm = detailContext.read<AiViewModel>();
      await waitFor(() => vocVm.selectedVoc != null && !aiVm.isAnalyzing,
          'registration and analysis', 150);
      expect(vocVm.selectedVoc!.title, '브리티 드라이브 삭제 파일 복원 문의');
      await mark('문의 등록 및 분류 결과');
      await click(find.byKey(const Key('voc-detail-ai-answer')));
      await waitFor(() => find.byType(AiAnswerScreen).evaluate().isNotEmpty,
          'answer review screen');
      await mark('답변 생성 실행');
      await waitFor(() => !aiVm.isGenerating && !aiVm.isSearching,
          'real answer generation', 100);
      expect(aiVm.error, isNull);
      expect(aiVm.hasAnswer, isTrue);
      expect(aiVm.isClarificationAnswer, isFalse);
      expect(aiVm.isAiAnswer, llm);
      expect(aiVm.answerResult!.answer.trim(), isNotEmpty);
      await pause(5000);
      await mark(llm ? '실제 모델이 생성한 답변' : '모델 없이 저장 자료로 구성한 답변');
      await visible(find.text('이 답변의 참고 자료'));
      await pause(2500);
      final evidenceTiles = find.byType(ExpansionTile);
      if (evidenceTiles.evaluate().isNotEmpty) {
        await click(evidenceTiles.first);
      }
      await pause(4500);
      await mark('매뉴얼 출처와 안내 내용 확인');
      // Copy the real generated result, then review and edit using the app UI.
      await click(find.byTooltip('답변 복사'));
      final copied = await Clipboard.getData(Clipboard.kTextPlain);
      expect(copied?.text?.trim(), isNotEmpty);
      await click(find.byType(BackButton));
      await waitFor(() => find.byType(VocDetailScreen).evaluate().isNotEmpty, 'back to detail');
      final composer = find.byWidgetPredicate((w) => w is TextField &&
          w.decoration?.hintText == '답변 내용을 작성해 주세요.');
      await visible(composer);
      await tester.enterText(composer, copied!.text!);
      await pause(2000);
      await click(find.ancestor(of: find.text('임시 저장'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
      await waitFor(() => vocVm.responses.any((r) => r.isDraft), 'draft stored');
      await click(find.ancestor(of: find.text('수정'), matching: find.byWidgetPredicate((w) => w is TextButton)));
      final editor = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      const reviewedAnswer = '안녕하세요. 브리티 드라이브의 휴지통에서 삭제한 파일을 확인하실 수 있으며, 보관 기한 내에는 원래 위치로 복원할 수 있습니다.\n\n휴지통에 해당 파일이 남아 있는지 먼저 확인해 주세요.\n\n참고: Brity Drive 매뉴얼 · 2.3 전체화면 구성';
      await type(editor, reviewedAnswer);
      await mark('담당자가 매뉴얼을 확인하고 답변 수정');
      await click(find.ancestor(of: find.text('저장'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
      await waitFor(() => vocVm.responses.any((r) => r.content == reviewedAnswer), 'review edit stored');
      await click(find.ancestor(of: find.text('답변 승인'), matching: find.byWidgetPredicate((w) => w is TextButton)));
      await waitFor(() => vocVm.responses.any((r) => r.isApproved), 'approved response saved');
      await visible(find.text('승인 완료'));
      await pause(3500);
      await mark('검토한 답변 승인 및 저장');
      await click(find.byTooltip('더보기'));
      await click(find.text('처리 완료'));
      await waitFor(() => vocVm.selectedVoc?.status == AppConstants.vocStatusResolved,
          'resolved status saved');
      await visible(find.byKey(const Key('voc-detail-hero')));
      expect(find.text('처리 완료'), findsWidgets);
      await pause(3500);
      await mark('문의 처리 완료 확인');
      final id = vocVm.selectedVoc!.id;
      final storedVoc = await db.query(AppConstants.tableVocs,
          where: 'id = ?', whereArgs: [id]);
      final storedResponses = await db.query(AppConstants.tableResponses,
          where: 'voc_id = ?', whereArgs: [id]);
      expect(storedVoc.single['status'], AppConstants.vocStatusResolved);
      expect(storedResponses.any((r) => r['status'] == AppConstants.responseApproved),
          isTrue);
      File('$dir/$mode-verification.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
        'success': true, 'mode': mode, 'actual_app': true,
        'model': llm ? 'qwen2.5:0.5b' : null,
        'is_ai_answer': aiVm.isAiAnswer, 'answer': aiVm.answerResult!.answer,
        'reviewed_answer': reviewedAnswer,
        'evidence_count': aiVm.answerEvidence.length,
        'supplied_evidence_count': aiVm.suppliedEvidence.length,
        'voc': storedVoc, 'responses': storedResponses, 'steps': marks,
      }));
      await pause(3000);
    } catch (error, stack) {
      await mark('오류 발생');
      File('$dir/$mode-error.txt').writeAsStringSync('$error\n$stack');
      debugDumpApp();
      rethrow;
    } finally {
      if (recorder != null) {
        recorder.stdin.writeln('q');
        await recorder.stdin.close();
        await recorder.exitCode.timeout(const Duration(seconds: 20));
      }
      await recordingLog.close();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
