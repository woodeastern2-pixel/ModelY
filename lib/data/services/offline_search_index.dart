import '../../domain/entities/knowledge_base_entity.dart';
import 'local_answer_service.dart';
import '../../core/utils/search_query_expander.dart';

/// Inverted index. Query work is bounded by posting lists and 128 candidates,
/// never by opening documents or normalizing every stored body.
class OfflineSearchIndex {
  final _rows = <String, KnowledgeBaseEntity>{};
  final _keys = <String, Set<String>>{};
  final _postings = <String, Set<String>>{};
  int lastCandidates = 0;
  int lastTotalCandidates = 0;
  List<String> lastQueries = [];
  int get length => _rows.length;

  static Set<String> keysFor(String text) {
    final compact = SearchQueryExpander.normalize(text).replaceAll(' ', '');
    return {
      for (var i = 0; i + 1 < compact.length; i++) 'g:${compact.substring(i, i + 2)}',
      ...LocalAnswerService().conceptKeys(text),
    };
  }

  void put(KnowledgeBaseEntity entry, {Iterable<String>? keys}) {
    remove(entry.id);
    _rows[entry.id] = entry;
    final tokens = (keys ?? keysFor('${entry.question} ${entry.answer}')).toSet();
    _keys[entry.id] = tokens;
    for (final token in tokens) {
      (_postings[token] ??= <String>{}).add(entry.id);
    }
  }

  void remove(String id) {
    _rows.remove(id);
    for (final token in _keys.remove(id) ?? <String>{}) {
      final posting = _postings[token];
      posting?.remove(id);
      if (posting?.isEmpty ?? false) _postings.remove(token);
    }
  }

  List<SimilarVocResult> search(String query, {String? excludeVocId}) {
    final service = LocalAnswerService();
    lastCandidates = 0;
    lastTotalCandidates = 0;
    lastQueries = [];
    final found = <String, SimilarVocResult>{};
    for (final variant in service.retrievalQueries(query)) {
      lastQueries.add(variant);
      final matches = _searchOnce(variant, excludeVocId: excludeVocId);
      for (final match in matches) {
        if (!service.focusedEvidence(query, match.knowledgeBase)) continue;
        final id = match.knowledgeBase.id;
        if (!found.containsKey(id) || match.similarityScore > found[id]!.similarityScore) {
          found[id] = match;
        }
      }
      // A navigation request needs the actual location, not merely a related
      // participant action. Try the focused searches before accepting partials.
      if (service.canAnswer(query, found.values.toList()) &&
          service.evidenceGap(query, service.answerReferences(found.values.toList())).isEmpty) break;
    }
    final order = {for (var i = 0; i < found.length; i++) found.keys.elementAt(i): i};
    final ranked = found.values.toList()..sort((a, b) {
      final location = (service.hasNavigationLocation(query, b.knowledgeBase) ? 1 : 0)
          .compareTo(service.hasNavigationLocation(query, a.knowledgeBase) ? 1 : 0);
      if (location != 0) return location;
      final score = b.similarityScore.compareTo(a.similarityScore);
      if (score != 0) return score;
      return order[a.knowledgeBase.id]!.compareTo(order[b.knowledgeBase.id]!);
    });
    return ranked.take(16).toList();
  }

  List<SimilarVocResult> _searchOnce(String query, {String? excludeVocId}) {
    final service = LocalAnswerService();
    final groups = service.queryIndexKeys(query);
    final hits = <String, double>{};
    for (final group in groups) {
      final matched = <String>{};
      // A query term uses its rarest bigram. Full text verification is done
      // only on candidate passages, so a coarse posting can never be an answer.
      final available = group.map((k) => _postings[k] ?? <String>{}).toList()
        ..sort((a, b) => a.length.compareTo(b.length));
      if (available.isNotEmpty) matched.addAll(available.first);
      final weight = 1 / (1 + matched.length).toDouble();
      for (final id in matched) hits[id] = (hits[id] ?? 0) + 1 + weight;
    }
    final ids = hits.keys.where((id) => excludeVocId == null || _rows[id]!.vocId != excludeVocId).toList()
      ..sort((a, b) { final score = hits[b]!.compareTo(hits[a]!); return score != 0 ? score : a.compareTo(b); });
    // Reserve candidates for BOTH routes even if one has many high matches.
    final qa = ids.where((id) => !id.startsWith('raw-')).take(64);
    final raw = ids.where((id) => id.startsWith('raw-')).take(64);
    final candidates = [...qa, ...raw].map((id) => _rows[id]!).toList();
    if (candidates.length > lastCandidates) lastCandidates = candidates.length;
    lastTotalCandidates += candidates.length;
    return service.rank(query, candidates, limit: 16);
  }
}
