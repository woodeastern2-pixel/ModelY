import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/bundled_qwen_service.dart';

void main() {
  test('missing offline files fail clearly without trying an external provider', () async {
    final directory = await Directory.systemTemp.createTemp('qwen-missing-');
    final service = BundledQwenService(bundleDirectory: directory);
    try {
      expect(service.isInstalled, isFalse);
      await expectLater(service.ensureReady(), throwsA(isA<StateError>()
          .having((e) => e.message, 'message', contains('설치본'))));
      await expectLater(service.ensureReady(), throwsA(isA<StateError>()));
    } finally {
      await service.stop();
      await directory.delete(recursive: true);
    }
  });
}
