import 'package:ai_voc_assistant/data/seeds/brity_messenger_manual_seed.dart';
import 'package:ai_voc_assistant/data/seeds/brity_suite_manual_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brity suite manual seed', () {
    test('covers all five Brity products with unique source metadata', () {
      final entries = BritySuiteManualSeed.entries;

      expect(entries.length, greaterThan(450));
      expect(
        entries.map((entry) => entry['id']).toSet(),
        hasLength(entries.length),
      );
      expect(
        BritySuiteManualSeed.projects,
        equals({
          'Brity Mail',
          'Brity Messenger',
          'Brity Meeting',
          'Brity Drive',
          'Brity Copilot',
        }),
      );
      expect(
        entries.every(
          (entry) =>
              (entry['question'] ?? '').isNotEmpty &&
              (entry['answer'] ?? '').isNotEmpty &&
              (entry['sourceName'] ?? '').isNotEmpty &&
              (entry['sourceUrl'] ?? '').startsWith('https://') &&
              (entry['platform'] ?? '').isNotEmpty,
        ),
        isTrue,
      );
    });

    test('includes every content page from both Messenger PDFs', () {
      expect(BrityMessengerManualSeed.entries, hasLength(57));
      expect(
        BrityMessengerManualSeed.entries.where(
          (entry) => entry['platform'] == 'Desktop',
        ),
        hasLength(26),
      );
      expect(
        BrityMessengerManualSeed.entries.where(
          (entry) => entry['platform'] == 'Mobile',
        ),
        hasLength(31),
      );
    });

    test('Korean queries cover representative product operations', () {
      final questions = BritySuiteManualSeed.entries
          .map((entry) => entry['question'] ?? '')
          .join('\n');

      expect(questions, contains('화면 공유'));
      expect(questions, contains('비밀 대화방'));
      expect(questions, contains('버전 이력'));
      expect(questions, contains('회의록 초안'));
      expect(questions, contains('메일 요약'));
    });
  });
}
