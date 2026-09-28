// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ai_voc_assistant/main.dart';
import 'package:ai_voc_assistant/presentation/screens/home/home_screen.dart';
import 'package:ai_voc_assistant/presentation/screens/splash/splash_screen.dart';

void main() {
  testWidgets('App boots to splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VocAssistantApp());

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
