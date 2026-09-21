import 'package:ai_voc_assistant/data/seeds/brity_manual_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Brity manual seed contains unique source-grounded entries', () {
    expect(BrityManualSeed.entries, hasLength(20));
    expect(
      BrityManualSeed.entries.map((entry) => entry['id']).toSet(),
      hasLength(BrityManualSeed.entries.length),
    );
    expect(
      BrityManualSeed.entries.every(
        (entry) =>
            (entry['question'] ?? '').isNotEmpty &&
            (entry['answer'] ?? '').contains('쪽'),
      ),
      isTrue,
    );
  });
}
