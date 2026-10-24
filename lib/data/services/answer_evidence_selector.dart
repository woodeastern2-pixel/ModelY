import '../../domain/entities/knowledge_base_entity.dart';
import 'local_answer_service.dart';
import 'manual_language_policy.dart';
import 'offline_query_plan.dart';

/// Spend context on distinct question parts and source conditions, not top-N alone.
class AnswerEvidenceSelector {
  static List<SimilarVocResult> select(
    String query,
    List<SimilarVocResult> candidates, {
    int maxCharacters = 16000,
    int maxSources = 8,
  }) {
    final service = LocalAnswerService();
    final usable = candidates
        .where(
          (r) =>
              r.similarityScore >= 0.40 &&
              service.isAnswerSource(r.knowledgeBase) &&
              !ManualLanguagePolicy.excludedEntry(r.knowledgeBase) &&
              service.versionCompatible(query, r.knowledgeBase),
        )
        .toList();
    final ordered = <SimilarVocResult>[];
    final parts = OfflineQueryPlan.from(query).parts;
    for (final part in parts) {
      final ranking = service.rank(part, usable.map((r) => r.knowledgeBase));
      if (ranking.isNotEmpty && ranking.first.similarityScore >= 0.68) {
        ordered.add(
          usable.firstWhere(
            (r) => r.knowledgeBase.id == ranking.first.knowledgeBase.id,
          ),
        );
      }
    }
    ordered.addAll(service.answerReferences(usable, query: query));
    ordered.addAll(
      usable.where((r) => service.focusedEvidence(query, r.knowledgeBase)),
    );
    final selected = <SimilarVocResult>[];
    final seen = <String>{};
    var characters = 0;
    for (final item in ordered) {
      if (selected.length >= maxSources) break;
      final entry = item.knowledgeBase;
      final key =
          '${entry.customer}\n${entry.answer.replaceAll(RegExp(r'\s+'), '')}';
      if (!seen.add(key)) continue;
      // A section is atomic: never silently cut off restrictions to fit a budget.
      if (selected.isNotEmpty &&
          characters + entry.answer.length > maxCharacters) {
        continue;
      }
      selected.add(item);
      characters += entry.answer.length;
    }
    return selected;
  }
}
