/// AI FAQ 자동 생성 서비스
/// 해결된 VOC에서 FAQ 후보 추출 및 자동 생성

import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';

/// FAQ 후보
class FaqCandidate {
  final String vocId;
  final String question;
  final String answer;
  final String category;
  final double relevanceScore; // 0.0 ~ 1.0
  final int occurrenceCount; // 유사 VOC 발생 횟수
  final bool isApproved;
  final DateTime createdAt;

  FaqCandidate({
    required this.vocId,
    required this.question,
    required this.answer,
    required this.category,
    required this.relevanceScore,
    required this.occurrenceCount,
    this.isApproved = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'voc_id': vocId,
    'question': question,
    'answer': answer,
    'category': category,
    'relevance_score': relevanceScore,
    'occurrence_count': occurrenceCount,
    'is_approved': isApproved ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };
}

/// FAQ 생성 옵션
class FaqGenerationOptions {
  final String vocId;
  final String title; // VOC 제목
  final String content; // VOC 내용
  final String? response; // AI 생성 답변
  final String category;
  final String department;
  final double relevanceThreshold; // 0.6 이상만 생성
  final bool autoPublishToConfluence;
  final String? confluenceSpace;

  FaqGenerationOptions({
    required this.vocId,
    required this.title,
    required this.content,
    this.response,
    required this.category,
    required this.department,
    this.relevanceThreshold = 0.75,
    this.autoPublishToConfluence = true,
    this.confluenceSpace,
  });
}

/// AI FAQ 생성 서비스
abstract class AiFaqGenerationService {
  /// FAQ 후보 생성
  Future<FaqCandidate?> generateFaqCandidate(
    FaqGenerationOptions options,
  );

  /// 유사 VOC에서 FAQ 후보 추출
  Future<List<FaqCandidate>> extractFaqCandidates(
    String vocId,
    List<VocEntity> similarVocs,
  );

  /// FAQ 후보 승인
  Future<void> approveFaqCandidate(String candidateId);

  /// FAQ 후보 거부
  Future<void> rejectFaqCandidate(String candidateId);

  /// 승인된 FAQ 조회
  Future<List<FaqCandidate>> getApprovedFaqs();

  /// 카테고리별 FAQ 조회
  Future<List<FaqCandidate>> getFaqsByCategory(String category);

  /// FAQ 생성 통계
  Future<Map<String, int>> getFaqGenerationStats();
}

/// 기본 FAQ 생성 서비스 구현
class DefaultAiFaqGenerationService implements AiFaqGenerationService {
  final Map<String, FaqCandidate> _faqCandidates = {};
  final Map<String, FaqCandidate> _approvedFaqs = {};

  @override
  Future<FaqCandidate?> generateFaqCandidate(
    FaqGenerationOptions options,
  ) async {
    // FAQ 생성 가능성 평가
    final relevanceScore = _evaluateRelevance(options);

    if (relevanceScore < options.relevanceThreshold) {
      return null;
    }

    // 질문 자동 생성
    final question = _generateQuestion(options.title, options.content);

    // 답변 준비
    final answer = options.response ?? _generateAnswer(options);

    final candidate = FaqCandidate(
      vocId: options.vocId,
      question: question,
      answer: answer,
      category: options.category,
      relevanceScore: relevanceScore,
      occurrenceCount: 1,
      createdAt: DateTime.now(),
    );

    _faqCandidates[options.vocId] = candidate;
    return candidate;
  }

  @override
  Future<List<FaqCandidate>> extractFaqCandidates(
    String vocId,
    List<VocEntity> similarVocs,
  ) async {
    // 유사 VOC들에서 공통된 패턴 찾기
    if (similarVocs.isEmpty) return [];

    final candidates = <FaqCandidate>[];

    for (final similarVoc in similarVocs) {
      final commonTerms = _findCommonTerms(
        [vocId, ...similarVocs.map((v) => v.id).where((id) => id != null).cast<String>()],
      );

      if (commonTerms.isNotEmpty) {
        final candidate = FaqCandidate(
          vocId: vocId,
          question: commonTerms.join(' '),
          answer: 'Common solution for: ${commonTerms.join(", ")}',
          category: similarVoc.category,
          relevanceScore: 0.82,
          occurrenceCount: similarVocs.length,
          createdAt: DateTime.now(),
        );

        candidates.add(candidate);
      }
    }

    return candidates;
  }

  @override
  Future<void> approveFaqCandidate(String candidateId) async {
    final candidate = _faqCandidates[candidateId];
    if (candidate != null) {
      _approvedFaqs[candidateId] = candidate.copyWith(isApproved: true);
      _faqCandidates.remove(candidateId);
    }
  }

  @override
  Future<void> rejectFaqCandidate(String candidateId) async {
    _faqCandidates.remove(candidateId);
  }

  @override
  Future<List<FaqCandidate>> getApprovedFaqs() async {
    return _approvedFaqs.values.toList();
  }

  @override
  Future<List<FaqCandidate>> getFaqsByCategory(String category) async {
    return _approvedFaqs.values
        .where((faq) => faq.category == category)
        .toList();
  }

  @override
  Future<Map<String, int>> getFaqGenerationStats() async {
    return {
      'total_candidates': _faqCandidates.length,
      'approved': _approvedFaqs.length,
      'pending': _faqCandidates.length,
    };
  }

  /// 관련성 점수 평가
  double _evaluateRelevance(FaqGenerationOptions options) {
    // 조건 체크
    int points = 0;

    // 제목이 충분히 구체적인가?
    if (options.title.length > 20 && options.title.length < 100) points += 20;

    // 내용이 충분한가?
    if (options.content.length > 100 && options.content.length < 2000) points += 20;

    // 응답이 있는가?
    if (options.response != null && options.response!.isNotEmpty) points += 20;

    // 카테고리가 일반적인가?
    const commonCategories = ['사용법', '기능문의', '장애', '기타'];
    if (commonCategories.contains(options.category)) points += 15;

    // 키워드 분석
    final keywords = _extractKeywords(options.content);
    if (keywords.length >= 3) points += 15;

    // 점수를 0~1로 정규화
    return (points / 100).clamp(0, 1);
  }

  /// 질문 생성
  String _generateQuestion(String title, String content) {
    // 제목이 이미 질문 형식이면 사용
    if (title.endsWith('?') || title.startsWith('Q:') || title.startsWith('Q. ')) {
      return title;
    }

    // 주요 키워드 추출
    final keywords = _extractKeywords(content).take(2).toList();

    // 자연스러운 질문 생성
    if (keywords.isNotEmpty) {
      return '${keywords.first}와 관련하여 ${title}?';
    }

    return '$title에 대해 알고 싶어요.';
  }

  /// 답변 생성
  String _generateAnswer(FaqGenerationOptions options) {
    if (options.response != null) return options.response!;

    return '''다음의 단계를 따르시면 문제를 해결할 수 있습니다:

1. 먼저 시스템을 새로 고침하세요.
2. 브라우저 캐시를 삭제하고 다시 시도하세요.
3. 관리자 권한이 필요한 경우, ${options.department} 관리자에게 문의하세요.

문제가 지속되면 기술 지원팀(support@company.com)으로 연락 주세요.''';
  }

  /// 키워드 추출
  List<String> _extractKeywords(String content) {
    // 간단한 구현: 일반적인 개념 추출
    const keywords = [
      'error',
      'fail',
      'issue',
      'problem',
      'cannot',
      'not working',
      'timeout',
      'connection',
      'password',
      'login',
      'system',
      'database',
      'server',
      'network',
    ];

    final foundKeywords = <String>[];
    for (final keyword in keywords) {
      if (content.toLowerCase().contains(keyword)) {
        foundKeywords.add(keyword);
      }
    }

    return foundKeywords;
  }

  /// 공통 용어 찾기
  List<String> _findCommonTerms(List<String> vocIds) {
    // 더미 구현: 실제로는 유사도 분석
    return ['common', 'issue', 'solution'];
  }
}

extension _CopyFaqCandidate on FaqCandidate {
  FaqCandidate copyWith({
    bool? isApproved,
  }) {
    return FaqCandidate(
      vocId: vocId,
      question: question,
      answer: answer,
      category: category,
      relevanceScore: relevanceScore,
      occurrenceCount: occurrenceCount,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt,
    );
  }
}
