import '../../domain/entities/knowledge_base_entity.dart';
import 'local_answer_service.dart';
import '../../core/utils/search_query_expander.dart';
import 'manual_language_policy.dart';

/// Inverted index. Each of at most four passes ranks up to 128 candidates,
/// never by opening documents or normalizing every stored body.
class OfflineSearchIndex {
  final _rows = <String, KnowledgeBaseEntity>{};
  final _keys = <String, Set<String>>{};
  final _postings = <String, Set<String>>{};
  int lastCandidates = 0;
  int lastTotalCandidates = 0;
  List<String> lastQueries = [];
  int get length => _rows.length;

  void clear() { _rows.clear(); _keys.clear(); _postings.clear(); }

  static Set<String> keysFor(String text) {
    final compact = SearchQueryExpander.normalize(text).replaceAll(' ', '');
    return {
      for (var i = 0; i + 1 < compact.length; i++) 'g:${compact.substring(i, i + 2)}',
      ...LocalAnswerService().conceptKeys(text),
    };
  }

  void put(KnowledgeBaseEntity entry, {Iterable<String>? keys, Map<String,dynamic>? preparedData}) {
    remove(entry.id);
    if (ManualLanguagePolicy.excludedEntry(entry)) return;
    if (preparedData != null) {
      LocalAnswerService().prepare(entry,data:preparedData);
    }
    _rows[entry.id] = entry;
    final text = '${entry.question} ${entry.answer}';
    // Cached bigrams stay valid when new bilingual feature aliases are added.
    final tokens = keys == null ? keysFor(text) : <String>{
      ...keys, if (preparedData == null) ...LocalAnswerService().conceptKeys(text),
    };
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

  List<SimilarVocResult> search(String query, {String? excludeVocId,
      bool includeRegisteredQuestions = false, List<String> preferredVocIds = const []}) {
    final service = LocalAnswerService();
    lastCandidates = 0;
    lastTotalCandidates = 0;
    lastQueries = [];
    final found = <String, SimilarVocResult>{};
    for (final variant in service.retrievalQueries(query)) {
      lastQueries.add(variant);
      final matches = _searchOnce(variant, constraintQuery: query, excludeVocId: excludeVocId,
          includeRegisteredQuestions: includeRegisteredQuestions, preferredVocIds: preferredVocIds);
      for (final match in matches) {
        if (!(includeRegisteredQuestions && match.knowledgeBase.vocId != null) &&
            !service.focusedEvidence(query, match.knowledgeBase)) {
          continue;
        }
        final id = match.knowledgeBase.id;
        if (!found.containsKey(id) || match.similarityScore > found[id]!.similarityScore) {
          found[id] = match;
        }
      }
      // A navigation request needs the actual location, not merely a related
      // participant action. Try the focused searches before accepting partials.
      if (service.canAnswer(query, found.values.toList()) &&
          service.evidenceGap(query, service.answerReferences(found.values.toList(), query: query)).isEmpty) break;
    }
    final order = {for (var i = 0; i < found.length; i++) found.keys.elementAt(i): i};
    final ranked = found.values.toList()..sort((a, b) {
      final sufficient = (b.similarityScore >= 0.68 ? 1 : 0)
          .compareTo(a.similarityScore >= 0.68 ? 1 : 0);
      if (sufficient != 0) return sufficient;
      final version = (service.confirmedVersion(query, b.knowledgeBase) ? 1 : 0)
          .compareTo(service.confirmedVersion(query, a.knowledgeBase) ? 1 : 0);
      if (version != 0) return version;
      final location = (service.hasNavigationLocation(query, b.knowledgeBase) ? 1 : 0)
          .compareTo(service.hasNavigationLocation(query, a.knowledgeBase) ? 1 : 0);
      if (location != 0) return location;
      final score = b.similarityScore.compareTo(a.similarityScore);
      if (score != 0) return score;
      return order[a.knowledgeBase.id]!.compareTo(order[b.knowledgeBase.id]!);
    });
    return ranked.take(16).toList();
  }

  List<SimilarVocResult> _searchOnce(String query, {required String constraintQuery, String? excludeVocId,
      bool includeRegisteredQuestions = false, List<String> preferredVocIds = const []}) {
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
    final ids = hits.keys.where((id) =>
        (excludeVocId == null || _rows[id]!.vocId != excludeVocId) &&
        (includeRegisteredQuestions || !id.startsWith('registered-voc-')) &&
        service.versionCompatible(constraintQuery, _rows[id]!)).toList()
      ..sort((a, b) { final score = hits[b]!.compareTo(hits[a]!); return score != 0 ? score : a.compareTo(b); });
    // Reserve candidates for BOTH routes even if one has many high matches.
    final qa = _diverse(ids.where((id) => !id.startsWith('raw-')));
    final raw = _diverse(ids.where((id) => id.startsWith('raw-')));
    final candidates = [...qa, ...raw].map((id) => _rows[id]!).toList();
    if (includeRegisteredQuestions && preferredVocIds.isNotEmpty) {
      for (final id in preferredVocIds.take(8)) {
        final row = _rows['approved-index-$id'] ?? _rows['registered-voc-$id'];
        if (row != null && !candidates.any((e) => e.id == row.id)) {
          if (candidates.length >= 128) candidates.removeLast();
          candidates.add(row);
        }
      }
    }
    if (candidates.length > lastCandidates) lastCandidates = candidates.length;
    lastTotalCandidates += candidates.length;
    final ranked = includeRegisteredQuestions
        ? service.rankChatReferences(query, candidates, preferredVocIds: preferredVocIds)
        : service.rank(query, candidates, limit: 128);
    final byId = {for (final result in ranked) result.knowledgeBase.id: result};
    return _diverse(byId.keys, limit: 16, perSection: 2)
        .map((id) => byId[id]!).toList();
  }
  List<String> _diverse(Iterable<String> ids, {int limit = 64, int perSection = 4}) {
    final selected = <String>[];
    final deferred = <String>[];
    final counts = <String, int>{};
    for (final id in ids) {
      final row = _rows[id]!;
      final title = row.question.replaceAll(RegExp(r'원문 구간 \d+'), '').trim();
      final key = '${row.customer}|${row.project}|$title';
      final count = counts[key] ?? 0;
      if (count < perSection) {
        selected.add(id);
        counts[key] = count + 1;
        if (selected.length == limit) return selected;
      } else {
        deferred.add(id);
      }
    }
    selected.addAll(deferred.take(limit - selected.length));
    return selected;
  }

}
