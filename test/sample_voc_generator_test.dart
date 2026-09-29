import 'package:ai_voc_assistant/data/services/sample_voc_generator.dart';
import 'package:ai_voc_assistant/core/utils/voc_category_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 29, 8, 1);
  test('1000 distinct Brity requests, exactly 100 for every field', () {
    final rows = SampleVocGenerator.generateSampleVocs(now: now);
    expect(rows, hasLength(1000));
    expect(rows.map((v) => v.id).toSet(), hasLength(1000));
    expect(rows.map((v) => v.title).toSet(), hasLength(1000));
    expect(rows.map((v) => v.content).toSet(), hasLength(1000));
    final projects = rows.map((v) => v.project).toSet();
    expect(projects, hasLength(10));
    for (final project in projects) {
      final field = rows.where((v) => v.project == project).toList();
      expect(field, hasLength(100));
      expect(field.map((v) => v.customer).toSet(), hasLength(10));
      expect(field.map((v) => v.category).toSet(), hasLength(10));
      expect(field.map((v) => v.createdAt.month).toSet(), {2,3,4,5,6,7,8,9});
    }
    expect(rows.every((v) => VocCategoryCatalog.isAllowed(v.category)), isTrue);
    expect(rows.every(SampleVocGenerator.isSample), isTrue);
    expect(rows.every((v) => v.businessScore == null && v.categoryScore == null), isTrue);
  });
  test('dates and processing states are chronological and reproducible', () {
    final rows = SampleVocGenerator.generateSampleVocs(now: now);
    final again = SampleVocGenerator.generateSampleVocs(now: now.add(const Duration(days: 5)));
    expect(rows.map((v) => v.createdAt), orderedEquals(again.map((v) => v.createdAt)));
    expect(rows.map((v) => v.id), orderedEquals(again.map((v) => v.id)));
    expect(rows.map((v) => v.status).toSet(), {'OPEN', 'IN_PROGRESS', 'RESOLVED'});
    for (final v in rows) {
      expect(v.createdAt.isBefore(SampleVocGenerator.start), isFalse);
      expect(v.updatedAt.isBefore(v.createdAt), isFalse);
      expect(v.updatedAt.isAfter(now), isFalse);
      if (v.status == 'RESOLVED') {
        expect(v.processingMinutes, v.updatedAt.difference(v.createdAt).inMinutes);
        expect(v.assignee, isNotNull);
      } else { expect(v.processingMinutes, isNull); }
    }
  });
  test('early system clock never produces future timestamps', () {
    final clock = DateTime.utc(2026, 3, 1, 2);
    for (final v in SampleVocGenerator.generateSampleVocs(now: clock)) {
      expect(v.updatedAt.isAfter(clock), isFalse);
    }
    expect(SampleVocGenerator.generateSampleVocs(now: DateTime.utc(2026,1)), isEmpty);
  });
}
