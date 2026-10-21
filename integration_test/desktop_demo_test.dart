import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:ai_voc_assistant/data/services/demo_voc_store.dart';
import 'package:ai_voc_assistant/data/services/sample_voc_generator.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/knowledge_base_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/integration_viewmodel.dart';
import 'package:ai_voc_assistant/presentation/screens/knowledge_base/knowledge_base_screen.dart';
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
  binding.shouldPropagateDevicePointerEvents = true;
  // This Linux recording host has no microphone or speech plugin. Expose that
  // unavailable OS capability; text input and every demonstrated AI/data path
  // still use the real application and real services.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugin.csdcorp.com/speech_to_text'),
    (call) async {
      if (call.method == 'initialize' || call.method == 'has_permission') return false;
      if (call.method == 'stop' || call.method == 'cancel') return null;
      throw MissingPluginException('No speech capability on recording host');
    },
  );
  const mode = String.fromEnvironment('DEMO_MODE', defaultValue: 'llm');
  const llm = mode == 'llm';
  const model = 'qwen3:4b-instruct-2507-q4_K_M';
  testWidgets('VOC Mate actual desktop scenario', (tester) async {
    const dir = 'artifacts';
    Directory(dir).createSync(recursive: true);
    for (final weight in ['Regular', 'Bold']) {
      File('assets/fonts/Pretendard-$weight.otf').copySync('$dir/Pretendard-$weight.otf');
    }
    final marks = <Map<String, Object?>>[];
    final fileDialogs = <Map<String, double>>[];
    final watch = Stopwatch();
    Process? recorder;
    final recordingLog = File('$dir/$mode-recording.log').openWrite();
    Future<void> pause([int ms = 400]) async {
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
      await pause(150);
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
      await pause(200);
    }
    Future<void> click(Finder target) async {
      await visible(target);
      final point = tester.getCenter(target.first);
      await Process.run('xdotool',
          ['mousemove', point.dx.round().toString(), point.dy.round().toString()]);
      await Process.run('xdotool', ['click', '1']);
      await pause();
    }
    Future<void> nav(int index) async {
      await click(find.byKey(Key('desktop-nav-$index')));
      await pause(900);
    }
    Future<void> nativeFile(String path, {bool save = false}) async {
      var dialogReady = false;
      for (var attempt = 0; attempt < 240; attempt++) {
        final dialog = await Process.run('pgrep', ['-x', 'zenity']);
        if (dialog.exitCode == 0) { dialogReady = true; break; }
        await pause(250);
      }
      if (!dialogReady) throw StateError('Native file dialog did not open');
      await pause(700);
      await Clipboard.setData(ClipboardData(text: path));
      await Process.run('xdotool', ['key', '--clearmodifiers', 'ctrl+l']);
      await pause(250);
      await Process.run('xdotool', ['key', '--clearmodifiers', 'ctrl+a', 'ctrl+v']);
      await pause(350);
      await Process.run('xdotool', ['key', 'Return']);
      await pause(1000);
      if (save && !File(path).existsSync()) {
        await Process.run('xdotool', ['key', 'alt+s']);
        await pause(1000);
      }
    }
    Future<Map<String, dynamic>> peerExport() async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('http://127.0.0.1:8789/webhook/sync/export'));
        final response = await request.close();
        expect(response.statusCode, 200);
        return jsonDecode(await utf8.decoder.bind(response).join()) as Map<String, dynamic>;
      } finally { client.close(); }
    }
    final pasteEvents = <Map<String, Object?>>[];
    Future<void> paste(Finder field, String value) async {
      await click(field);
      await Clipboard.setData(ClipboardData(text: value));
      final startedAt = watch.elapsedMilliseconds / 1000;
      final result = await Process.run(
          'xdotool', ['key', '--clearmodifiers', 'ctrl+a', 'ctrl+v']);
      expect(result.exitCode, 0);
      final editable = find.descendant(
          of: field.first, matching: find.byType(EditableText));
      await waitFor(
          () => tester.widget<EditableText>(editable.first).controller.text == value,
          'native clipboard paste', 5);
      pasteEvents.add({
        'start': startedAt,
        'end': watch.elapsedMilliseconds / 1000,
        'characters': value.length,
        'method': 'system clipboard and native Ctrl+V',
      });
      File('$dir/$mode-paste-events.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(pasteEvents));
    }
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await DatabaseHelper.instance.database;
      // Isolated demonstration database. Synthetic requests are labelled in the video.
      // Production answers and model responses are never mocked or prefilled.
      await DemoVocStore(db).insert(SampleVocGenerator.generateSampleVocs());
      final settings = <String, String>{
        AppConstants.settingThemeMode: 'light',
        AppConstants.settingUserName: '시연 담당자',
        AppConstants.settingAiProvider: AppConstants.aiProviderOllama,
        AppConstants.settingOllamaUrl: 'http://127.0.0.1:11434',
        AppConstants.settingAppInstanceName: '운영 담당자 A',
        AppConstants.settingVocAutoForwardEnabled: 'false',
        AppConstants.settingAiAutoAnswerOnVocRegister: 'false',
        AppConstants.settingAiMaxTokens: '640',
        AppConstants.settingAiTemperature: '0.1',
        if (llm) AppConstants.settingOllamaModel: model,
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
        '-y', '-loglevel', 'warning', '-f', 'x11grab', '-draw_mouse', '0',
        '-framerate', '30', '-video_size', '1600x1000',
        '-i', Platform.environment['DISPLAY']!,
        '-an', '-c:v', 'libx264', '-preset', 'ultrafast', '-threads', '1', '-crf', '20',
        '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
        '$dir/$outputName.mp4',
      ]);
      recorder.stdout.drain<void>();
      recorder.stderr.transform(utf8.decoder).listen(recordingLog.write);
      watch.start();
      await pause(700);
      await mark('01 현황 확인');
      await pause(5500);
      await Process.run('xdotool', ['mousemove', '1100', '650']);
      await Process.run('xdotool', ['click', '--repeat', '3', '--delay', '180', '5']);
      await pause(4500);
      await mark('02 LLM 연결');
      await nav(4);
      await click(find.text('AI 설정'));
      await paste(find.widgetWithText(TextField, '관리자 비밀번호'), AppConstants.defaultAdminPassword);
      await click(find.widgetWithText(FilledButton, '확인'));
      await click(find.text('고급 설정 보기'));
      await pause(2500);
      await click(find.text('연결 확인'));
      await waitFor(() => find.text('AI 연결을 확인했습니다').evaluate().isNotEmpty,
          'LLM connection verification', 110);
      await pause(2500);
      await click(find.widgetWithText(FilledButton, '확인'));
      await mark('03 지식 자료 등록과 검색');
      await nav(3);
      final kbVm = tester.element(find.byType(KnowledgeBaseScreen)).read<KnowledgeBaseViewModel>();
      await waitFor(() => !kbVm.isLoading, 'knowledge loaded');
      await pause(2000);
      final fileDialogStart = watch.elapsedMilliseconds / 1000;
      await click(find.byTooltip('매뉴얼 추가'));
      await nativeFile('${Directory.current.path}/artifacts/demo-guide.docx');
      await waitFor(() => !kbVm.isImportingManual && kbVm.manualEntriesByFile.keys.any((k) => k.contains('demo-guide')), 'document import', 90);
      await pause(1200);
      fileDialogs.add({'start': fileDialogStart, 'end': watch.elapsedMilliseconds / 1000});
      File('$dir/file-dialogs.json').writeAsStringSync(jsonEncode(fileDialogs));
      final kbSearch = find.byWidgetPredicate((w) => w is TextField &&
          w.decoration?.hintText == '질문, 답변 또는 매뉴얼 검색');
      await paste(kbSearch, '메신저');
      await waitFor(() => kbVm.searchQuery == '메신저' && kbVm.entries.isNotEmpty,
          'Korean knowledge search');
      await pause(1800);
      final manualTiles = find.byType(ExpansionTile);
      if (manualTiles.evaluate().isNotEmpty) {
        await click(manualTiles.first);
        await pause(5500);
      }
      await paste(kbSearch, '');
      await mark('04 문의 접수');
      await nav(1);
      await mark('문의 목록 확인');
      await click(find.byKey(const Key('voc-register-primary')));
      await paste(find.widgetWithText(TextFormField, '제목 *'),
          '브리티 메신저 PC 새 메시지 알림 문의');
      await paste(find.widgetWithText(TextFormField, '내용 *'),
          '브리티 메신저 PC에서 새 메시지가 와도 팝업과 소리가 나오지 않습니다. 메시지는 대화방을 열면 보입니다. 알림 설정과 방해 금지 설정은 어디에서 확인하나요?');
      await paste(find.widgetWithText(TextFormField, '고객명 (선택)'), '시연 담당자');
      await mark('새 문의 입력');
      await click(find.ancestor(of: find.text('VOC 등록'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
      await waitFor(() => find.byType(VocDetailScreen).evaluate().isNotEmpty,
          'registered detail');
      final detailContext = tester.element(find.byType(VocDetailScreen));
      final vocVm = detailContext.read<VocViewModel>();
      final aiVm = detailContext.read<AiViewModel>();
      await waitFor(() => vocVm.selectedVoc != null && !aiVm.isAnalyzing,
          'registration and analysis', 950);
      expect(vocVm.selectedVoc!.title, '브리티 메신저 PC 새 메시지 알림 문의');
      await mark('문의 등록 및 분류 결과');
      await click(find.byKey(const Key('voc-detail-ai-answer')));
      await waitFor(() => find.byType(AiAnswerScreen).evaluate().isNotEmpty,
          'answer review screen');
      await mark('05 LLM 답변 생성');
      await waitFor(() => !aiVm.isGenerating && !aiVm.isSearching,
          'real answer generation', 950);
      expect(aiVm.error, isNull);
      expect(aiVm.hasAnswer, isTrue);
      expect(aiVm.isClarificationAnswer, isFalse);
      expect(aiVm.isAiAnswer, llm);
      expect(aiVm.answerResult!.answer.trim(), isNotEmpty);
      final actualDraft = aiVm.answerResult!;
      final suppliedEvidence = aiVm.suppliedEvidence.map((r) => {
        'id': r.knowledgeBase.id, 'question': r.knowledgeBase.question,
        'answer': r.knowledgeBase.answer, 'score': r.similarityScore,
      }).toList();
      File('$dir/actual-ai-draft.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
        'model': model, 'answer': actualDraft.answer,
        'notes': actualDraft.notes,
        'referenced_case_ids': actualDraft.referencedCaseIds,
        'supplied_evidence': suppliedEvidence,
      }));
      expect(actualDraft.answer, contains('알림'));
      expect(actualDraft.answer.toLowerCase(), anyOf(contains('옵션'), contains('options')));
      expect(actualDraft.answer.toLowerCase(), anyOf(contains('방해'), contains('do not disturb')));
      expect(actualDraft.referencedCaseIds, contains('brity-messenger-desktop-020'));
      expect(actualDraft.answer.length, greaterThan(100));
      await pause(1500);
      await mark(llm ? '실제 모델이 생성한 답변' : '모델 없이 저장 자료로 구성한 답변');
      await mark('06 근거 확인');
      await visible(find.text('이 답변의 참고 자료'));
      await pause(2500);
      final evidenceTiles = find.byType(ExpansionTile);
      if (evidenceTiles.evaluate().isNotEmpty) {
        await click(evidenceTiles.first);
      }
      await pause(1500);
      await mark('매뉴얼 출처와 안내 내용 확인');
      // Review and approve the actual generated draft. Do not substitute a scripted answer.
      await mark('07 답변 검토와 승인');
      await click(find.byTooltip('답변 복사'));
      final copied = await Clipboard.getData(Clipboard.kTextPlain);
      expect(copied?.text?.trim(), isNotEmpty);
      await click(find.byType(BackButton));
      await waitFor(() => find.byType(VocDetailScreen).evaluate().isNotEmpty, 'back to detail');
      final composer = find.byWidgetPredicate((w) => w is TextField &&
          w.decoration?.hintText == '답변 내용을 작성해 주세요.');
      await visible(composer);
      await paste(composer, copied!.text!);
      await pause(2000);
      final reviewedAnswer = copied.text!;
      expect(reviewedAnswer.trim(), actualDraft.answer.trim());
      await mark('담당자가 매뉴얼과 실제 생성 초안을 대조');
      await click(find.ancestor(of: find.text('임시 저장'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
      await waitFor(() => vocVm.responses.any((r) => r.isDraft && r.content == reviewedAnswer), 'reviewed draft stored');
      await click(find.ancestor(of: find.text('답변 승인'), matching: find.byWidgetPredicate((w) => w is TextButton)));
      await waitFor(() => vocVm.responses.any((r) => r.isApproved), 'approved response saved');
      await visible(find.text('승인 완료'));
      await pause(1200);
      await mark('검토한 답변 승인 및 저장');
      await click(find.byTooltip('더보기'));
      await click(find.text('처리 완료'));
      await waitFor(() => vocVm.selectedVoc?.status == AppConstants.vocStatusResolved,
          'resolved status saved');
      await visible(find.byKey(const Key('voc-detail-hero')));
      expect(find.text('처리 완료'), findsWidgets);
      await pause(1200);
      await mark('문의 처리 완료 확인');
      final id = vocVm.selectedVoc!.id;
      final generatedAnswer = aiVm.answerResult!.answer;
      await mark('08 처리 이력');
      await click(find.byType(BackButton));
      await pause(2500);
      await mark('09 코파일럿 질의');
      await nav(2);
      await click(find.byKey(const Key('copilot-new-session')));
      await waitFor(() => find.byKey(const Key('copilot-message-field')).evaluate().isNotEmpty,
          'new copilot session', 120);
      await pause(1200);
      await paste(find.byKey(const Key('copilot-message-field')),
          '브리티 메신저 PC 새 메시지 알림 문의의 승인된 답변에서 알림 설정 위치와 방해 금지 확인사항을 세 문장 이내로 요약해 주세요.');
      final copilotReferences = await aiVm.resolveChatReferences(
          '브리티 메신저 PC 새 메시지 알림 문의의 승인된 답변에서 알림 설정 위치와 방해 금지 확인사항을 세 문장 이내로 요약해 주세요.');
      File('$dir/copilot-supplied-evidence.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(copilotReferences.map((r) => {
        'id': r.knowledgeBase.id, 'voc_id': r.knowledgeBase.vocId,
        'question': r.knowledgeBase.question, 'answer': r.knowledgeBase.answer,
      }).toList()));
      expect(copilotReferences.any((r) => r.knowledgeBase.vocId == id), isTrue);
      await mark('코파일럿 질문 전송');
      await click(find.byKey(const Key('copilot-send')));
      await waitFor(() => !aiVm.isChatting, 'copilot model response', 950);
      expect(aiVm.chatError, isNull);
      expect(aiVm.chatMessages.any((m) => m.role == 'assistant'), isTrue);
      await mark('코파일럿 실제 응답 확인');
      await pause(6500);
      final chatEvidence = aiVm.chatMessages.map((m) => {
        'role': m.role, 'content': m.content,
      }).toList();
      File('$dir/actual-copilot.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(chatEvidence));
      final actualReply = aiVm.chatMessages.lastWhere((m) => m.role == 'assistant').content;
      expect(actualReply, contains('알림'));
      expect(actualReply.toLowerCase(), anyOf(contains('옵션'), contains('options')));
      expect(actualReply.toLowerCase(), anyOf(contains('방해'), contains('do not disturb')));
      expect(actualReply, contains('브리티 메신저'));
      expect(actualReply.length, greaterThan(70));
      await click(find.byType(BackButton));
      await mark('10 내부망 공유');
      await nav(4);
      await click(find.text('데이터 관리'));
      await paste(find.byKey(const Key('voc-sync-instance-field')), '운영 담당자 A');
      await click(find.byKey(const Key('voc-sync-add-target')));
      await paste(find.byKey(const Key('voc-sync-target-dialog-field')),
          'http://127.0.0.1:8789/webhook/voc');
      await click(find.widgetWithText(FilledButton, '확인'));
      await click(find.byKey(const Key('voc-sync-save')));
      await pause(2500);
      final syncVm = tester.element(find.byType(HomeScreen)).read<IntegrationViewModel>();
      await click(find.text('전체 VOC와 매뉴얼 보내기'));
      await waitFor(() => !syncVm.isLoading, 'real network sharing', 100);
      expect(syncVm.error, isNull);
      final received = await peerExport();
      File('$dir/peer-export.json').writeAsStringSync(jsonEncode(received));
      expect(jsonEncode(received).contains(id), isTrue);
      await pause(5000);
      await pause(1500);
      await mark('11 데이터 보호');
      await click(find.byKey(const Key('desktop-privacy')));
      await waitFor(() => find.text('개인정보 및 AI 데이터 처리 안내').evaluate().isNotEmpty,
          'privacy page opened');
      await pause(5000);
      await Process.run('xdotool', ['mousemove', '1100', '600']);
      await Process.run('xdotool', ['click', '--repeat', '6', '--delay', '150', '5']);
      await pause(3500);
      await click(find.byType(BackButton));
      await nav(0);
      await pause(3500);
      await mark('12 시연 완료');
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
        'input_method': 'native clipboard paste', 'paste_events': pasteEvents,
        'model': llm ? model : null,
        'is_ai_answer': true, 'answer': generatedAnswer,
        'copilot': chatEvidence, 'peer_received': true,
        'backup_chapter_removed': true,
        'approved_actual_generated_draft': true,
        'reviewed_answer': reviewedAnswer,
        'evidence_count': aiVm.answerEvidence.length,
        'supplied_evidence_count': aiVm.suppliedEvidence.length,
        'voc': storedVoc, 'responses': storedResponses, 'steps': marks,
      }));
      await pause(700);
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
  }, timeout: const Timeout(Duration(minutes: 40)));
}

