import '../../core/utils/search_query_expander.dart';
import '../../domain/entities/knowledge_base_entity.dart';

/// Builds extractive answers from records already stored on the device.
/// No model, embedding server, or network call is used here.
class LocalAnswerService {
  static const noEvidence =
      '현재 등록된 자료에서 이 질문에 직접 답할 근거를 찾지 못했습니다. 담당자에게 확인해 주세요.';

  List<SimilarVocResult> rank(
    String query,
    Iterable<KnowledgeBaseEntity> entries, {
    List<String> preferredVocIds = const [],
    int limit = 5,
  }) {
    final terms = _terms(query);
    if (terms.isEmpty) return const [];
    final ranked = <SimilarVocResult>[];
    for (final entry in entries) {
      if (entry.answer.trim().isEmpty) continue;
      final title = SearchQueryExpander.normalize(entry.question);
      final body = SearchQueryExpander.normalize(entry.answer);
      final titleHits = terms.where((term) => _matches(title, term)).length;
      final bodyHits = terms.where((term) => _matches(body, term)).length;
      final aliasTitle = SearchQueryExpander.matchRatio(query, entry.question);
      final coverage = (titleHits + bodyHits * 0.35) / terms.length;
      final preferred = entry.vocId != null && preferredVocIds.contains(entry.vocId);
      if (!preferred && titleHits == 0 && aliasTitle == 0) continue;
      final score = preferred
          ? 1.0
          : (coverage * 0.65 + aliasTitle * 0.35).clamp(0.0, 1.0).toDouble();
      if (!preferred && score < 0.35) continue;
      ranked.add(SimilarVocResult(knowledgeBase: entry, similarityScore: score));
    }
    ranked.sort((a, b) {
      final score = b.similarityScore.compareTo(a.similarityScore);
      return score != 0 ? score : a.knowledgeBase.id.compareTo(b.knowledgeBase.id);
    });
    return ranked.take(limit).toList();
  }

  bool isAnswerSource(KnowledgeBaseEntity entry) =>
      !entry.id.startsWith('registered-voc-') &&
      entry.answer.trim().isNotEmpty;

  bool canAnswer(String query, List<SimilarVocResult> references) =>
      !needsWholeDataset(query) &&
      references.any((item) =>
          isAnswerSource(item.knowledgeBase) && item.similarityScore >= 0.55);

  String answer(List<SimilarVocResult> references) {
    references = references
        .where((item) => isAnswerSource(item.knowledgeBase))
        .toList();
    if (references.isEmpty) return '$noEvidence\n근거: 없음';
    final best = references.first;
    final item = best.knowledgeBase;
    if (best.similarityScore < 0.55) {
      return '관련 자료는 있지만 질문에 직접 답할 근거는 확인되지 않았습니다. 담당자에게 확인해 주세요.\n관련 자료: ${item.question}';
    }
    final source = item.category == '시스템매뉴얼'
        ? '시스템 매뉴얼'
        : item.vocId != null
            ? '등록된 VOC'
            : '지식베이스';
    // Preserve the stored answer. Combining parts of different records could
    // invent a procedure that is absent from every source.
    return '${item.answer.trim()}\n\n근거: $source · ${item.question}';
  }

  bool needsWholeDataset(String query) {
    final normalized = SearchQueryExpander.normalize(query);
    return const [
      '전체', '몇 건', '몇개', '몇 개', '가장 많', '우선순위',
      '반복 문의', '보고서', '현황 요약',
    ].any(normalized.contains);
  }

  String answerForQuery(String query, List<SimilarVocResult> references) {
    if (needsWholeDataset(query)) {
      return '이 질문은 전체 자료의 집계가 필요합니다. 현재 자료 검색 결과만으로는 정확한 수치나 순위를 판단할 수 없습니다. VOC 목록에서 확인해 주세요.\n근거: 없음';
    }
    return answer(references);
  }

  List<String> _terms(String query) {
    const stop = {
      '어떻게', '알려줘', '알려주세요', '해주세요', '해줘', '무엇', '뭐야',
      '있나요', '있어', '그럼', '해당', '내용', '관련', '대한', '다시',
    };
    return SearchQueryExpander.normalize(query)
        .split(' ')
        .map((term) => term.replaceFirst(RegExp(r'(은|는|을|를|이|가|에서|에)$'), ''))
        .where((term) => term.length >= 2 && !stop.contains(term))
        .toSet()
        .toList();
  }

  bool _matches(String corpus, String term) {
    if (corpus.contains(term)) return true;
    return SearchQueryExpander.matchRatio(term, corpus) >= 1.0;
  }
}

