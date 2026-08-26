import 'package:ai_voc_assistant/data/services/sample_voc_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Demo Mode samples are identifiable and stable across runs', () {
    final first = SampleVocGenerator.generateSampleVocs();
    final second = SampleVocGenerator.generateSampleVocs();

    expect(first, hasLength(10));
    expect(
      first.map((voc) => voc.id),
      orderedEquals(second.map((voc) => voc.id)),
    );
    expect(first.map((voc) => voc.id).toSet(), hasLength(first.length));
    expect(first.every((voc) => voc.source == 'demo'), isTrue);
  });
}
