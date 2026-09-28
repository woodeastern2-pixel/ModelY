import 'dart:math' as math;
import 'manual_content.dart';

import '../../core/utils/search_query_expander.dart';
import '../../domain/entities/knowledge_base_entity.dart';

/// Offline, query-dependent retrieval over every stored manual body.
/// Scores express evidence coverage, not a probability of correctness.
class LocalAnswerService {
  static const noEvidence =
      '현재 등록된 자료에서 이 질문에 직접 답할 근거를 찾지 못했습니다. 담당자에게 확인해 주세요.';

  // A concept is scored once regardless of how many aliases occur. Product
  // names and generic action words alone cannot establish answer evidence.
  static const _concepts = <String, List<String>>{
    'mail': ['brity mail', '브리티메일', '메일', 'email', '전자우편'],
    'messenger': ['brity messenger', '메신저', 'messenger'],
    'meeting': ['brity meeting', '미팅', '화상회의', '영상회의', 'meeting'],
    'drive': ['brity drive', '드라이브', 'drive'],
    'copilot': ['코파일럿', 'copilot'],
    'desktop': ['데스크톱', 'desktop', 'pc'],
    'mobile': ['모바일', 'mobile'],
    'notification': ['알림', 'notification', 'notifications'],
    'password': ['비밀번호', '암호', 'password'],
    'join': ['접속', '참가', '참여', 'join'],
    'signin': ['로그인', 'sign in', 'login', 'log in'],
    'signout': ['로그아웃', 'sign out', 'logout'],
    'attachment': ['첨부파일', '첨부 파일', 'attachment', 'attachments'],
    'permission': ['접근권한', '접근 권한', '액세스권한', 'permission', 'permissions', 'access rights'],
    'presenter': ['진행권', '발표권', '발표자', 'presenter'],
    'participant': ['참석자', '참가자', 'participant', 'participants'],
    'transfer': ['넘기', '넘겨', '양도', '부여', 'transfer', 'assign'],
    'recycle': ['휴지통', 'recycle bin', 'trash'],
    'restore': ['복원', '복구', '되살리', 'restore', 'recover'],
    'delete': ['삭제', '지우', '지워', 'delete', 'remove'],
    'share': ['공유', 'share', 'sharing'],
    'search': ['검색', '찾기', 'search'],
    'download': ['다운로드', '내려받', 'download'],
    'upload': ['업로드', '올리', 'upload'],
    'settings': ['설정', 'settings', 'options'],
    'survey': ['설문', 'survey'],
    'file': ['파일', 'file', 'files'],
    'folder': ['폴더', 'folder', 'folders'],
    'edit': ['편집', '수정', 'edit', 'editing'],
    'cancel': ['취소', 'cancel'],
    'limit': ['제한', '최대', 'limit', 'maximum'],
    'conversation': ['대화기록', '대화 기록', '대화내역', '대화 내역', 'conversation data', 'chat history'],
    'contact': ['연락처', 'contact', 'contacts'],
    'shortcut': ['바로가기', '바로 가기', 'shortcut'],
    'uninstall': ['제거', 'uninstall'],
  };
  static const _products = {'mail', 'messenger', 'meeting', 'drive', 'copilot'};
  static const _generic = {
    ..._products, 'desktop', 'mobile', 'settings', 'file', 'folder',
    'search', 'edit', 'delete', 'share', 'download', 'upload',
  };
  static const _stop = {
    '어떻게', '알려줘', '알려주세요', '해주세요', '해줘', '무엇', '뭐야',
    '있나요', '있어', '그럼', '해당', '내용', '관련', '대한', '다시',
    '방법', '하나요', '하나', '하고', '싶어요', '싶습니다', '하는', '하려면',
    '기능', '사용', '사용법', '가능한가요', '되나요', '합니다', '있는',
    'the', 'how', 'to', 'can', 'i', 'a', 'in', 'of', 'please', 'brity', '브리티',
  };

  List<SimilarVocResult> rank(
    String query,
    Iterable<KnowledgeBaseEntity> entries, {
    List<String> preferredVocIds = const [],
    int limit = 8,
  }) {
    final terms = _terms(query);
    if (terms.isEmpty || limit <= 0) return const [];
    final docs = entries.where((e) => e.answer.trim().isNotEmpty).toList();
    final corpora = docs.map((e) => _normalize('${e.question} ${e.answer}')).toList();
    final weights = <String, double>{};
    for (final term in terms) {
      final df = corpora.where((body) => _matches(body, term)).length;
      weights[term] = (1 + math.log(1 + docs.length / (1 + df))) *
          (_generic.contains(term) ? 0.45 : 1.0);
    }
    final ranked = <SimilarVocResult>[];
    for (var i = 0; i < docs.length; i++) {
      final entry = docs[i];
      final preferred = entry.vocId != null && preferredVocIds.contains(entry.vocId);
      final scope = _normalize('${entry.project ?? ''} ${entry.question}');
      final requestedProducts = terms.where(_products.contains);
      final knownProducts = _products.where((p) => _matches(scope, p)).toSet();
      if (!preferred && requestedProducts.isNotEmpty && knownProducts.isNotEmpty &&
          !requestedProducts.any(knownProducts.contains)) {
        continue;
      }
      final windows = _windows(entry.answer);
      var best = 0.0;
      for (final window in windows) {
        final body = _normalize(window);
        final title = _normalize(entry.question);
        var matched = 0.0;
        var total = 0.0;
        var bodyHits = 0;
        var specificBodyHits = 0;
        for (final term in terms) {
          final weight = weights[term]!;
          total += weight;
          if (_matches(body, term)) {
            matched += weight;
            bodyHits++;
            if (!_generic.contains(term)) specificBodyHits++;
          } else if (_matches(title, term) ||
              (_products.contains(term) && _matches(scope, term))) {
            matched += weight * 0.65;
          }
        }
        // Prevent a title-only or product-only result becoming an answer.
        if (bodyHits == 0 || (specificBodyHits == 0 && bodyHits < 2)) continue;
        final coverage = matched / total;
        if (coverage > best) best = coverage;
      }
      // Pinned VOCs remain available to AI as context, but cannot manufacture
      // evidence for the offline answer path (isAnswerSource filters them).
      if (entry.id.startsWith('registered-voc-')) {
        final contextHits = terms.where((t) => _matches(corpora[i], t)).length;
        best = math.max(best, 0.65 * contextHits / terms.length);
      }
      final score = preferred ? math.max(best, 0.95) : best;
      if (score < 0.38) continue;
      ranked.add(SimilarVocResult(knowledgeBase: entry,
          similarityScore: score.clamp(0.0, 1.0).toDouble()));
    }
    ranked.sort((a, b) {
      final score = b.similarityScore.compareTo(a.similarityScore);
      if (score != 0) return score;
      return a.knowledgeBase.id.compareTo(b.knowledgeBase.id);
    });
    return ranked.take(limit).toList();
  }

  bool isAnswerSource(KnowledgeBaseEntity entry) =>
      !entry.id.startsWith('registered-voc-') && entry.answer.trim().isNotEmpty;

  bool canAnswer(String query, List<SimilarVocResult> references) =>
      !needsWholeDataset(query) && references.any((item) =>
          isAnswerSource(item.knowledgeBase) && item.similarityScore >= 0.68);

  List<SimilarVocResult> answerReferences(List<SimilarVocResult> references) {
    final usable = references.where((r) =>
        isAnswerSource(r.knowledgeBase) && r.similarityScore >= 0.68).toList();
    if (usable.isEmpty) return [];
    final best = usable.first;
    // Keep different sources separate: never splice incompatible procedures.
    final source = best.knowledgeBase.customer;
    if (source == null || source.isEmpty) return [best];
    final seen = <String>{};
    return usable.where((r) =>
        r.knowledgeBase.customer == source &&
        r.knowledgeBase.project == best.knowledgeBase.project &&
        r.similarityScore >= best.similarityScore * 0.94 &&
        seen.add(r.knowledgeBase.answer.trim())).take(3).toList();
  }

  String answer(List<SimilarVocResult> references) => answerForQuery('', references);

  String answerForQuery(String query, List<SimilarVocResult> references) {
    if (needsWholeDataset(query)) {
      return '이 질문은 전체 자료의 집계가 필요합니다. 현재 자료 검색 결과만으로는 정확한 수치나 순위를 판단할 수 없습니다. VOC 목록에서 확인해 주세요.\n근거: 없음';
    }
    final selected = answerReferences(references);
    if (selected.isEmpty) return '$noEvidence\n근거: 없음';
    return selected.map((reference) {
      final item = reference.knowledgeBase;
      final authored = ManualContent.parse(item.answer).body;
      final text = authored.isEmpty
          ? '이미지에 포함된 설명은 아래 매뉴얼 원본 이미지를 확인해 주세요.'
          : query.trim().isEmpty ? authored : _extract(query, authored);
      final source = item.customer?.trim();
      final label = source != null && source.isNotEmpty ? source :
          (item.category == '시스템매뉴얼' ? '시스템 매뉴얼' : '승인된 답변 / 지식베이스');
      return '$text\n\n근거: $label · ${item.question}';
    }).join('\n\n────────\n\n');
  }

  bool needsWholeDataset(String query) {
    final normalized = _normalize(query);
    return RegExp(r'(voc|문의|접수|처리|답변).*(통계|집계|몇 건|몇건|가장 많|현황 요약|보고서)')
        .hasMatch(normalized) ||
        RegExp(r'(통계|집계|가장 많).*(voc|문의|접수|처리)').hasMatch(normalized);
  }

  // Adjacent paragraphs are searched together so a heading, steps, table rows
  // and caution can contribute jointly. No term is required in the question.
  List<String> _windows(String text) {
    final blocks = text.split(RegExp(r'\n\s*\n'))
        .where((s) => s.trim().isNotEmpty).toList();
    if (blocks.length <= 3) return [text];
    return [for (var i = 0; i < blocks.length; i++)
      blocks.sublist(math.max(0, i - 1), math.min(blocks.length, i + 3)).join('\n\n')];
  }

  String _extract(String query, String text) {
    // Short sections remain intact: do not lose a negation or numbered step.
    if (text.length <= 2200) return text.trim();
    final terms = _terms(query).where((t) => !_products.contains(t)).toList();
    final blocks = text.split(RegExp(r'\n\s*\n'));
    final scores = blocks.map((b) => terms.where((t) => _matches(_normalize(b), t)).length).toList();
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    final keep = <int>{};
    for (var i = math.max(0, best - 1); i < math.min(blocks.length, best + 3); i++) {
      keep.add(i);
    }
    for (var i = 0; i < blocks.length; i++) {
      // Retain section-wide restrictions and provenance, including OCR labels.
      if (RegExp(r'주의|제한|불가|않습니다|해야|경우|출처|자동 인식|OCR|caution|warning|must|cannot|only', caseSensitive: false)
          .hasMatch(blocks[i])) {
        keep.add(i);
      }
    }
    if (keep.length == blocks.length) return text.trim();
    final indices = keep.toList()..sort();
    return '매뉴얼 근거 발췌 (전체 절차는 아래 출처 원문 확인)\n\n${indices.map((i) => blocks[i].trim()).join('\n\n')}';
  }

  String _normalize(String text) => SearchQueryExpander.normalize(text);

  List<String> _terms(String query) {
    var remaining = _normalize(query);
    final result = <String>{};
    final aliases = <MapEntry<String, String>>[
      for (final concept in _concepts.entries)
        for (final alias in concept.value) MapEntry(alias, concept.key),
    ]..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final alias in aliases) {
      final pattern = _pattern(alias.key);
      if (!pattern.hasMatch(remaining)) continue;
      result.add(alias.value);
      remaining = remaining.replaceAll(pattern, ' ');
    }
    for (var term in remaining.split(' ')) {
      term = term.replaceFirst(RegExp(r'(에서는|으로|에서|에게|처럼|하고|은|는|을|를|이|가|에|도|만)$'), '');
      if (term.length >= 2 && !_stop.contains(term)) result.add(term);
    }
    return result.toList();
  }

  static final _patterns = <String, RegExp>{};

  RegExp _pattern(String alias) => _patterns.putIfAbsent(alias, () {
    final words = alias.split(' ').map(RegExp.escape).join(r'\s*');
    return RegExp(RegExp(r'[가-힣]').hasMatch(alias)
        ? words : '(^|(?<=\\s))$words(?=\\s|\$|[가-힣])');
  });

  bool _matches(String corpus, String term) {
    final aliases = _concepts[term];
    if (aliases != null) return aliases.any((a) => _pattern(a).hasMatch(corpus));
    return corpus.contains(term) || corpus.replaceAll(' ', '').contains(term);
  }
}
