import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_voc_assistant/data/services/bundled_qwen_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled model runs in the Windows app without Ollama', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Center(child: Text('VoC Mate · 내장 Qwen 실행 검증')),
    )));
    final root = Platform.environment['VOC_QWEN_SMOKE_ROOT'];
    expect(root, isNotNull);
    final service = BundledQwenService(bundleDirectory: Directory(root!));
    final results = <Map<String, Object>>[];
    try {
      expect(service.isInstalled, isTrue);
      final clock = Stopwatch()..start();
      final answer = await service.generate(
        '한국어로 답하세요. 아래 제공된 자료에 적힌 절차만 짧게 안내하세요. '
        '없는 기능은 추측하지 마세요. 두 문장 이내로 답하세요.',
        '[자료] PC 메신저의 옵션 > 알림에서 새 메시지 알림과 소리를 켭니다. '
        '방해 금지 설정을 확인하고 테스트 메시지로 알림을 확인합니다.\n'
        '[질문] PC 메신저에서 새 메시지 알림과 소리가 나오지 않습니다. 어떻게 확인하나요?',
        maxTokens: 256,
      );
      results.add({'case': 'notification', 'answer': answer,
        'elapsed_ms': clock.elapsedMilliseconds});
      expect(answer, contains('알림'));
      expect(answer, contains('소리'));
      expect(answer.contains('<think>'), isFalse);
      final unknown = await service.generate(
        '주어진 자료만 사용하세요. 답이 자료에 없으면 반드시 "자료에서 확인할 수 없습니다"라고 답하세요.',
        '[자료] 메신저 새 메시지 알림을 켤 수 있습니다.\n'
        '[질문] 이 회사의 메신저 메시지 보관 기간은 며칠인가요?',
        maxTokens: 96,
      );
      results.add({'case': 'unsupported_policy', 'answer': unknown});
      expect(unknown, contains('확인할 수 없'));
      expect(RegExp(r'\d+\s*일').hasMatch(unknown), isFalse);
    } finally {
      await service.stop();
      final report = File('artifacts/bundled-qwen-smoke.json');
      await report.parent.create(recursive: true);
      await report.writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    }
  }, timeout: const Timeout(Duration(minutes: 7)));
}
