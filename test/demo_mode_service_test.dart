import 'package:ai_voc_assistant/data/services/demo_mode_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stopping Demo Mode cancels the presentation flow promptly', () async {
    final service = DefaultDemoModeService();
    final run = service.startDemo((_) {});

    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(service.isRunning(), isTrue);

    await service.stopDemo();
    await run.timeout(const Duration(seconds: 1));

    expect(service.isRunning(), isFalse);
  });
}
