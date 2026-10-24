import 'package:ai_voc_assistant/data/seeds/brity_messenger_manual_seed.dart';
import 'package:ai_voc_assistant/data/seeds/brity_suite_manual_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brity suite manual seed', () {
    test('only Korean source seeds remain, with unique provenance', () {
      final entries = BritySuiteManualSeed.entries;
      expect(entries, hasLength(268));
      expect(entries.map((e) => e['id']).toSet(), hasLength(entries.length));
      expect(entries.every((e) => (e['sourceUrl'] ?? '').contains('/ko/')), isTrue);
      expect(BrityMessengerManualSeed.entries, isEmpty);
    });

    test('Korean queries cover representative product operations', () {
      final questions = BritySuiteManualSeed.entries
          .map((entry) => entry['question'] ?? '')
          .join('\n');

      expect(questions, contains('예약 발송'));
      expect(questions, contains('Copilot으로 받은 메일을 요약'));
    });
  });
}
