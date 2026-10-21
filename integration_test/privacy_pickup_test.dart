import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_voc_assistant/main.dart' as app;
import 'package:ai_voc_assistant/presentation/screens/home/home_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets('record actual data protection page', (tester) async {
    Directory('artifacts').createSync(recursive: true);
    Future<void> pause(int ms) => tester.pump(Duration(milliseconds: ms));
    app.main();
    for (var i = 0; i < 600 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await pause(250);
    }
    expect(find.byType(HomeScreen), findsOneWidget);
    await Process.run('wmctrl', ['-r', 'ai_voc_assistant', '-b', 'add,fullscreen']);
    await pause(3500);
    final button = find.byKey(const Key('desktop-privacy'));
    expect(button, findsOneWidget);
    final p = tester.getCenter(button);
    await Process.run('xdotool', ['mousemove', '${p.dx.round()}', '${p.dy.round()}']);
    await Process.run('xdotool', ['click', '1']);
    await pause(1500);
    expect(find.text('개인정보 및 AI 데이터 처리 안내'), findsOneWidget);
    expect(find.text('데이터 보호 원칙'), findsOneWidget);
    final rec = await Process.start('ffmpeg', [
      '-y', '-loglevel', 'error', '-f', 'x11grab', '-draw_mouse', '0',
      '-framerate', '30', '-video_size', '1600x1000', '-i', Platform.environment['DISPLAY']!,
      '-an', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20',
      '-pix_fmt', 'yuv420p', '-movflags', '+faststart', 'artifacts/VOC_Mate_Privacy_Actual.mp4',
    ]);
    rec.stdout.drain<void>();
    rec.stderr.drain<void>();
    try {
      await pause(6500);
      await Process.run('xdotool', ['mousemove', '1100', '600']);
      await Process.run('xdotool', ['click', '--repeat', '10', '--delay', '150', '5']);
      await pause(6500);
      await Process.run('xdotool', ['click', '--repeat', '7', '--delay', '150', '5']);
      await pause(6500);
      expect(find.text('AI 데이터 처리 안내'), findsOneWidget);
      File('artifacts/privacy-verified.txt').writeAsStringSync('Actual application privacy page opened and recorded. Native scrolling.');
    } finally {
      rec.stdin.writeln('q');
      await rec.stdin.close();
      expect(await rec.exitCode.timeout(const Duration(seconds: 20)), 0);
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
}
