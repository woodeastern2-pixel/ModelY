import 'package:ai_voc_assistant/presentation/screens/chat/ai_chat_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VOC Copilot quick actions use real chat prompts', () {
    expect(vocCopilotQuickActions, hasLength(5));
    expect(
      vocCopilotQuickActions.map((action) => action.label).toSet(),
      hasLength(vocCopilotQuickActions.length),
    );
    for (final action in vocCopilotQuickActions) {
      expect(action.label.trim(), isNotEmpty);
      expect(action.prompt.trim(), isNotEmpty);
      expect(action.prompt, contains('VOC'));
    }
  });
}
