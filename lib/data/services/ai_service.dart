import 'dart:convert';

import '../../core/utils/voc_category_catalog.dart';
import '../../core/utils/user_facing_text.dart';
import '../../core/utils/vector_utils.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/entities/ai_chat_message_entity.dart';
import '../datasources/remote/claude_service.dart';
import '../datasources/remote/gemini_service.dart';
import '../datasources/remote/ollama_service.dart';
import '../datasources/remote/openai_service.dart';
import '../../core/constants/app_constants.dart';

class AiPrompts {
  AiPrompts._();

  static const String manualAnswerRefineSystem = '''
당신은 기업 시스템 운영 매뉴얼 편집 어시스턴트입니다.
입력된 매뉴얼 원문을 사용자 문의 응답용으로 간결하고 정확하게 재작성하세요.

규칙:
1) 원문에 없는 사실을 추가하지 마세요.
2) 장황한 설명을 줄이고 즉시 실행 가능한 답변으로 작성하세요.
3) 핵심 절차는 번호 목록(1., 2., 3.)으로 정리하세요.
4) 길이는 최대 6문장 또는 8줄 이내로 제한하세요.
5) 불필요한 서론/결론 없이 바로 답변만 출력하세요.
''';

  static String manualAnswerRefineUser({
    required String question,
    required String sourceText,
  }) =>
      '''
[질문]
$question

[매뉴얼 원문]
$sourceText
''';

  static const String manualQaExpansionSystem = '''
당신은 시스템 매뉴얼을 FAQ로 변환하는 전문가입니다.
입력된 매뉴얼 섹션을 분석해서, 실제 사용자가 물을 수 있는 질문을 여러 개 도출하세요.

규칙:
1) 질문은 서로 중복되지 않게 작성하세요.
2) 질문별 답변은 원문 근거만 사용하고, 없는 내용은 만들지 마세요.
3) 답변은 간결하고 즉시 실행 가능하게 작성하세요.
4) 결과는 JSON만 반환하세요.

응답 형식:
{
  "items": [
    {
      "question": "질문",
      "answer": "답변"
    }
  ]
}
''';

  static String manualQaExpansionUser({
    required String fileName,
    required String sectionLabel,
    required String sectionText,
  }) =>
      '''
[매뉴얼 파일]
$fileName

[섹션 라벨]
$sectionLabel

[섹션 원문]
$sectionText
''';

  static String get vocAnalysisSystem => '''
당신은 IT 시스템 고객 지원 전문가입니다.
사용자의 문의가 업무(IT 시스템, 소프트웨어, 서비스) 관련 VOC인지 판단하는 역할을 합니다.

판단 기준:
- 업무 관련: 시스템 장애, 기능 문의, 사용법, 개선 요청, 운영 문의, 계약 관련 등
- 업무 무관: 일상 대화, 개인적 질문, 시스템과 관계없는 내용

응답 형식 (JSON만 반환, 다른 텍스트 없음):
{
  "is_business": true/false,
  "category": "${AppConstants.defaultCategories.join('|')}",
  "reason": "판단 이유 한 줄"
}
''';

  static String vocAnalysisUser(String title, String content) =>
      '제목: $title\n내용: $content';

  static const String answerGenerationSystem = '''
당신은 IT 시스템 고객 지원 전문가입니다.
아래 제공된 유사 VOC 사례와 기존 답변만을 근거로 고객 문의에 대한 답변을 작성하세요.

규칙:
0. 출처가 "시스템 매뉴얼"인 사례를 최우선으로 참조하세요.
1. 제공된 사례에 없는 내용은 절대 만들어내지 마세요.
2. 최대한 기존 답변을 기반으로 작성하세요.
3. 답변은 공손하고 전문적인 어조를 유지하세요.
4. 없는 사실을 추측하거나 일반적인 사용법을 현재 시스템의 기능인 것처럼 적용하지 마세요.
5. 메뉴명, 버튼명, 화면 경로, 설정 경로, 지원 기능은 제공된 근거에 해당 표현이나 절차가 확인될 때만 안내하세요.
6. 고객 문의에 특정 외부 서비스나 메신저 이름이 등장했다는 사실만으로 해당 연동 기능이 존재한다고 판단하지 마세요.
7. 질문의 핵심 절차나 지원 여부를 근거에서 직접 확인할 수 없으면 "현재 확인된 자료만으로는 정확한 안내가 어렵습니다"라고 명시하고 담당자 확인을 안내하세요.
8. 서로 다른 사례의 기능이나 절차를 조합해 새로운 사용법을 만들지 마세요.
9. 답변 본문에 "사례 1" 같은 익명 번호를 쓰지 마세요.
10. referenced_cases에는 실제로 답변 근거로 사용한 사례의 실제 제목만 넣으세요.
11. 직접적인 근거가 부족하면 confidence를 낮게 평가하세요. 단순 유사성만으로 높은 신뢰도를 부여하지 마세요.
12. 마크다운 기호(**, __, #, 백틱)를 사용하지 마세요.

응답 형식 (JSON만 반환):
{
  "answer": "생성된 답변 내용",
  "confidence": 0.0~1.0,
  "referenced_cases": ["사례1 제목", "사례2 제목"],
  "notes": "추가 참고 사항 또는 불확실한 부분"
}
''';

  static String answerGenerationUser(
    String vocTitle,
    String vocContent,
    List<SimilarVocResult> similarCases,
  ) {
    final casesText = similarCases.asMap().entries.map((e) {
      final idx = e.key + 1;
      final kb = e.value.knowledgeBase;
      final score = (e.value.similarityScore * 100).toStringAsFixed(1);
      final source = _isManualCase(kb) ? '시스템 매뉴얼' : 'VOC 이력';
      return '''
[사례 $idx] (유사도: $score%)
출처: $source
질문: ${kb.question}
답변: ${kb.answer}
카테고리: ${kb.category}
''';
    }).join('\n---\n');

    return '''
[고객 문의]
제목: $vocTitle
내용: $vocContent

[유사 사례]
$casesText
''';
  }

  static bool _isManualCase(KnowledgeBaseEntity kb) {
    return kb.category == '시스템매뉴얼' || kb.question.contains('매뉴얼 섹션');
  }

  static const String similarityRerankSystem = '''
당신은 VOC 검색 재랭커입니다.
고객 문의와 후보 사례의 관련성을 판단해서 가장 적합한 순서로 정렬하세요.

판단 기준:
1. 문제 증상과 해결 절차가 얼마나 일치하는가
2. 현재 문의에 바로 활용 가능한 답변인가
3. 같은 시스템/업무 맥락인지
4. 최신성보다 직접 관련성을 우선한다

응답 형식(JSON만 반환):
{
  "ranked_case_ids": ["case-id-1", "case-id-2"],
  "reason": "재랭킹 근거 한 줄"
}
''';

  static String similarityRerankUser(
    String query,
    List<SimilarVocResult> candidates,
  ) {
    final candidateText = candidates.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final caseItem = entry.value;
      final kb = caseItem.knowledgeBase;
      final similarity = (caseItem.similarityScore * 100).toStringAsFixed(1);
      return '''
[후보 $index]
case_id: ${kb.id}
유사도: $similarity%
질문: ${kb.question}
답변: ${kb.answer}
카테고리: ${kb.category}
''';
    }).join('\n---\n');

    return '''
[고객 문의]
$query

[후보 사례]
$candidateText
''';
  }

  static const String chatSystem = '''
당신은 고객 지원용 AI 채팅 어시스턴트입니다.
답변은 한국어로 간결하고 명확하게 작성하세요.
현재 등록된 VOC와 지식베이스, 이전 대화 맥락을 함께 활용하세요.
등록 VOC의 내용과 처리 상태를 근거로 질문에 답하고, 근거가 여러 건이면 공통점과 차이점을 구분하세요.
아래 참고 자료에 실제로 적힌 사실만 확정적으로 답하세요.
고객명, 학교명, VOC 제목, 처리 상태와 수치를 임의로 만들거나 다른 사례와 섞지 마세요.
참고 자료에 없는 사실은 추측하지 말고 "현재 확인된 자료만으로는 판단할 수 없습니다"라고 명시하세요.
"가장 많다", "가장 길다" 같은 전체 비교는 전체 데이터가 제공된 경우에만 단정하고, 일부 후보만 있으면 "확인된 후보 중"이라고 범위를 밝히세요.
이전 답변과 현재 참고 자료가 충돌하면 현재 자료를 기준으로 즉시 정정하고 정정 이유를 짧게 설명하세요.
답변 마지막에는 근거로 사용한 VOC 제목을 한 줄로 명시하세요. 내부 ID나 UUID는 출력하지 마세요. 근거가 없으면 근거 없음이라고 쓰세요.
마크다운 기호(**, __, #, 백틱)를 사용하지 말고 일반 텍스트로 작성하세요.
''';

  static String chatUser(
    String message,
    List<AiChatMessageEntity> history,
    List<SimilarVocResult> references,
  ) {
    final historyText = history.map((item) {
      final role = item.role == 'assistant' ? '어시스턴트' : '사용자';
      return '[$role] ${item.content}';
    }).join('\n');

    final referenceText = references.map((item) {
      final kb = item.knowledgeBase;
      final source = kb.vocId != null
          ? '등록 VOC'
          : _isManualCase(kb)
              ? '시스템 매뉴얼'
              : '지식베이스';
      return '''
[참고 자료]
출처: $source
질문: ${kb.question}
답변: ${kb.answer}
카테고리: ${kb.category}
유사도: ${(item.similarityScore * 100).toStringAsFixed(1)}%
''';
    }).join('\n---\n');

    return '''
[대화 맥락]
$historyText

[참고 자료: 등록 VOC 및 지식베이스]
$referenceText

[사용자 질문]
$message
''';
  }
}

class AiAnswerResult {
  final String answer;
  final double confidence;
  final List<String> referencedCases;
  final String notes;

  const AiAnswerResult({
    required this.answer,
    required this.confidence,
    required this.referencedCases,
    required this.notes,
  });
}

class ManualQaPair {
  final String question;
  final String answer;

  const ManualQaPair({
    required this.question,
    required this.answer,
  });
}

class VocAnalysisResult {
  final bool isBusiness;
  final String category;
  final String reason;

  const VocAnalysisResult({
    required this.isBusiness,
    required this.category,
    required this.reason,
  });
}

class VocIntelligenceResult {
  final bool isBusiness;
  final double businessScore;
  final String category;
  final double categoryScore;
  final String urgency;
  final double urgencyScore;
  final String department;
  final double departmentScore;
  final String assignee;
  final double assigneeScore;
  final String? duplicateOfVocId;
  final double duplicateScore;
  final bool jiraRequired;
  final double jiraScore;
  final String reason;

  const VocIntelligenceResult({
    required this.isBusiness,
    required this.businessScore,
    required this.category,
    required this.categoryScore,
    required this.urgency,
    required this.urgencyScore,
    required this.department,
    required this.departmentScore,
    required this.assignee,
    required this.assigneeScore,
    this.duplicateOfVocId,
    required this.duplicateScore,
    required this.jiraRequired,
    required this.jiraScore,
    required this.reason,
  });
}

class AssigneeRecommendation {
  final String assignee;
  final double accuracy;
  final int handled;

  const AssigneeRecommendation({
    required this.assignee,
    required this.accuracy,
    required this.handled,
  });
}

class AiService {
  OllamaService? _ollamaService;
  OpenAiService? _openAiService;
  GeminiService? _geminiService;
  ClaudeService? _claudeService;
  String _provider = AppConstants.aiProviderOllama;

  void configureOllama(String baseUrl, String model, {double temperature = 0.3, int maxTokens = 2048}) {
    _ollamaService = OllamaService(
      baseUrl: baseUrl,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    _provider = AppConstants.aiProviderOllama;
  }

  void configureOpenAi(String apiKey, String model, {double temperature = 0.3, int maxTokens = 2048}) {
    _openAiService = OpenAiService(
      apiKey: apiKey,
      chatModel: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    _provider = AppConstants.aiProviderOpenAi;
  }

  void configureGemini(String apiKey, String model, {double temperature = 0.3, int maxTokens = 2048}) {
    _geminiService = GeminiService(
      apiKey: apiKey,
      chatModel: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    _provider = AppConstants.aiProviderGemini;
  }

  void configureClaude(String apiKey, String baseUrl, String model, {double temperature = 0.3, int maxTokens = 2048}) {
    _claudeService = ClaudeService(
      apiKey: apiKey,
      baseUrl: baseUrl,
      chatModel: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    _provider = AppConstants.aiProviderClaude;
  }

  void setProvider(String provider) => _provider = provider;

  Future<String> testConnection() async {
    final raw = await _generate(
      '당신은 AI 통신 테스트 응답기입니다. 한 문장으로만 응답하세요.',
      '연결 테스트입니다. 정상 응답 가능 여부를 짧게 알려 주세요.',
    );
    return raw.trim();
  }

  Future<String> refineManualAnswer({
    required String question,
    required String sourceText,
  }) async {
    final raw = await _generate(
      AiPrompts.manualAnswerRefineSystem,
      AiPrompts.manualAnswerRefineUser(
        question: question,
        sourceText: sourceText,
      ),
    );

    final normalized = raw.trim();
    if (normalized.isEmpty) {
      throw Exception('AI가 빈 답변을 반환했습니다.');
    }
    return normalized;
  }

  Future<List<ManualQaPair>> generateManualQaPairs({
    required String fileName,
    required String sectionLabel,
    required String sectionText,
  }) async {
    final raw = await _generate(
      AiPrompts.manualQaExpansionSystem,
      AiPrompts.manualQaExpansionUser(
        fileName: fileName,
        sectionLabel: sectionLabel,
        sectionText: sectionText,
      ),
    );

    try {
      final map = _jsonDecode(_extractJson(raw));
      final items = map['items'];
      if (items is! List) {
        return const [];
      }

      final pairs = <ManualQaPair>[];
      for (final item in items) {
        if (item is! Map) continue;
        final question = item['question']?.toString().trim() ?? '';
        final answer = item['answer']?.toString().trim() ?? '';
        if (question.isEmpty || answer.isEmpty) continue;
        pairs.add(ManualQaPair(question: question, answer: answer));
      }
      return pairs;
    } catch (_) {
      return const [];
    }
  }

  bool get isConfigured {
    if (_provider == AppConstants.aiProviderOllama) {
      return _ollamaService != null;
    }
    if (_provider == AppConstants.aiProviderGemini) {
      return _geminiService != null && _geminiService!.apiKey.isNotEmpty;
    }
    if (_provider == AppConstants.aiProviderClaude) {
      return _claudeService != null && _claudeService!.apiKey.isNotEmpty;
    }
    return _openAiService != null && _openAiService!.apiKey.isNotEmpty;
  }

  Future<String> _generate(String systemPrompt, String userPrompt) async {
    if (_provider == AppConstants.aiProviderGemini && _geminiService != null) {
      return await _geminiService!.generate(systemPrompt, userPrompt);
    }
    if (_provider == AppConstants.aiProviderClaude && _claudeService != null) {
      return await _claudeService!.generate(systemPrompt, userPrompt);
    }
    if (_provider == AppConstants.aiProviderOpenAi && _openAiService != null) {
      return await _openAiService!.generate(systemPrompt, userPrompt);
    }
    if (_ollamaService != null) {
      return await _ollamaService!.generate(systemPrompt, userPrompt);
    }
    throw Exception('AI 서비스가 설정되지 않았습니다. 설정에서 AI 제공자를 구성해 주세요.');
  }

  Future<VocAnalysisResult> analyzeVoc(String title, String content) async {
    final userPrompt = AiPrompts.vocAnalysisUser(title, content);
    final raw = await _generate(AiPrompts.vocAnalysisSystem, userPrompt);
    return _parseVocAnalysis(raw);
  }

  Future<VocIntelligenceResult> analyzeVocIntelligence({
    required String title,
    required String content,
    required List<Map<String, dynamic>> assigneeCandidates,
    required List<Map<String, dynamic>> duplicateCandidates,
  }) async {
    final systemPrompt = '''
당신은 기업 VOC 운영 분석 엔진입니다.
아래 VOC에 대해 다음 항목을 반드시 점수와 함께 판단하세요.
1) 업무 관련 여부
2) 카테고리 분류
3) 긴급도(Critical/High/Medium/Low)
4) 담당 부서 추천
5) 담당자 추천
6) 중복 VOC 여부
7) JIRA 생성 필요 여부

응답은 JSON만 반환:
{
  "is_business": true,
  "business_score": 0.0,
  "category": "${AppConstants.defaultCategories.join('|')}",
  "category_score": 0.0,
  "urgency": "High",
  "urgency_score": 0.0,
  "department": "플랫폼운영팀",
  "department_score": 0.0,
  "assignee": "홍길동",
  "assignee_score": 0.0,
  "duplicate_of_voc_id": "optional",
  "duplicate_score": 0.0,
  "jira_required": true,
  "jira_score": 0.0,
  "reason": "근거 설명"
}
''';

    final userPrompt = '''
[VOC]
제목: $title
내용: $content

[담당자 후보]
${jsonEncode(assigneeCandidates)}

[중복 후보]
${jsonEncode(duplicateCandidates)}
''';

    final raw = await _generate(systemPrompt, userPrompt);
    try {
      final map = _jsonDecode(_extractJson(raw));
      return VocIntelligenceResult(
        isBusiness: map['is_business'] as bool? ?? true,
        businessScore: (map['business_score'] as num?)?.toDouble() ?? 0.6,
        category: VocCategoryCatalog.normalize(
          map['category'] as String?,
          title: title,
          content: content,
        ),
        categoryScore: (map['category_score'] as num?)?.toDouble() ?? 0.6,
        urgency: map['urgency'] as String? ?? 'Medium',
        urgencyScore: (map['urgency_score'] as num?)?.toDouble() ?? 0.5,
        department: map['department'] as String? ?? '고객지원팀',
        departmentScore: (map['department_score'] as num?)?.toDouble() ?? 0.5,
        assignee: map['assignee'] as String? ?? '미지정',
        assigneeScore: (map['assignee_score'] as num?)?.toDouble() ?? 0.5,
        duplicateOfVocId: map['duplicate_of_voc_id'] as String?,
        duplicateScore: (map['duplicate_score'] as num?)?.toDouble() ?? 0.0,
        jiraRequired: map['jira_required'] as bool? ?? false,
        jiraScore: (map['jira_score'] as num?)?.toDouble() ?? 0.5,
        reason: map['reason'] as String? ?? '',
      );
    } catch (_) {
      return VocIntelligenceResult(
        isBusiness: true,
        businessScore: 0.55,
        category: VocCategoryCatalog.normalize(
          '기능문의',
          title: title,
          content: content,
        ),
        categoryScore: 0.5,
        urgency: 'Medium',
        urgencyScore: 0.5,
        department: '고객지원팀',
        departmentScore: 0.4,
        assignee: assigneeCandidates.isNotEmpty
            ? (assigneeCandidates.first['assignee'] as String? ?? '미지정')
            : '미지정',
        assigneeScore: 0.4,
        duplicateOfVocId: duplicateCandidates.isNotEmpty
            ? duplicateCandidates.first['id'] as String?
            : null,
        duplicateScore: duplicateCandidates.isNotEmpty
            ? ((duplicateCandidates.first['score'] as num?)?.toDouble() ?? 0.0)
            : 0.0,
        jiraRequired: false,
        jiraScore: 0.4,
        reason: raw.length > 200 ? raw.substring(0, 200) : raw,
      );
    }
  }

  Future<String> predictUrgencyReason({
    required String title,
    required String content,
    required String urgency,
  }) async {
    final systemPrompt = '''
당신은 VOC 긴급도 평가자입니다. 긴급도 등급의 근거를 2문장 이내로 설명하세요.
''';
    final userPrompt = '제목: $title\n내용: $content\n긴급도: $urgency';
    final raw = await _generate(systemPrompt, userPrompt);
    return raw.trim();
  }

  Future<List<String>> generateExecutiveRecommendations({
    required Map<String, dynamic> metrics,
  }) async {
    final systemPrompt = '''
당신은 경영진 보고용 운영 인사이트 분석가입니다.
주어진 지표만으로 실행 가능한 개선 권장사항을 작성하세요.

규칙:
1) 4개 항목으로 작성
2) 각 항목은 한 줄, 40자 이내
3) 모호한 문구 금지(예: 개선 필요)
4) 즉시 실행 가능한 행동 포함
5) 한국어로 작성

출력 형식(JSON):
{
  "recommendations": [
    "...",
    "...",
    "...",
    "..."
  ]
}
''';

    final userPrompt = '''
[지표]
${jsonEncode(metrics)}
''';

    final raw = await _generate(systemPrompt, userPrompt);
    try {
      final parsed = _jsonDecode(_extractJson(raw));
      final list = List<String>.from(parsed['recommendations'] ?? const []);
      final cleaned = list
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(4)
          .toList();
      if (cleaned.isNotEmpty) return cleaned;
    } catch (_) {}

    return raw
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^[-•\d\.)\s]+'), '').trim())
        .where((line) => line.isNotEmpty)
        .take(4)
        .toList();
  }

  Future<AiAnswerResult> generateAnswer(
    String vocTitle,
    String vocContent,
    List<SimilarVocResult> similarCases,
  ) async {
    if (similarCases.isEmpty) {
      return const AiAnswerResult(
        answer: '유사한 사례를 찾지 못했습니다. 담당자가 직접 답변을 작성해 주세요.',
        confidence: 0.0,
        referencedCases: [],
        notes: '지식베이스에 유사 사례 없음',
      );
    }

    final rankedCases = [...similarCases]
      ..sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    final strongest = rankedCases.first.similarityScore;
    if (strongest < 0.40) {
      return const AiAnswerResult(
        answer: '현재 확인된 자료만으로는 정확한 안내가 어렵습니다. 담당자가 관련 매뉴얼 또는 기존 처리 사례를 확인해 주세요.',
        confidence: 0.25,
        referencedCases: [],
        notes: '직접적인 근거가 충분하지 않아 자동 답변을 제한했습니다.',
      );
    }

    final threshold = strongest >= 0.70
        ? 0.50
        : strongest >= 0.55
            ? 0.45
            : 0.40;
    final groundedCases = rankedCases
        .where((item) => item.similarityScore >= threshold)
        .take(5)
        .toList();
    final selectedCases = groundedCases.isEmpty
        ? rankedCases.take(1).toList()
        : groundedCases;

    final userPrompt = AiPrompts.answerGenerationUser(
      vocTitle,
      vocContent,
      selectedCases,
    );
    final raw = await _generate(AiPrompts.answerGenerationSystem, userPrompt);
    return _parseAnswerResult(raw, selectedCases);
  }

  Future<String> generateChatReply({
    required String message,
    required List<AiChatMessageEntity> history,
    required List<SimilarVocResult> references,
  }) async {
    final userPrompt = AiPrompts.chatUser(message, history, references);
    final raw = await _generate(AiPrompts.chatSystem, userPrompt);
    return UserFacingText.fromAi(raw);
  }

  Future<List<SimilarVocResult>> rerankSimilarCases({
    required String query,
    required List<SimilarVocResult> candidates,
  }) async {
    if (candidates.length <= 1) return candidates;

    final shortlist = candidates.toList();
    if (!isConfigured || shortlist.length <= 3 || shortlist.length > 20) {
      return _heuristicRerank(query, shortlist);
    }

    try {
      final raw = await _generate(
        AiPrompts.similarityRerankSystem,
        AiPrompts.similarityRerankUser(query, shortlist),
      );
      final map = _jsonDecode(_extractJson(raw));
      final rankedIds = List<String>.from(map['ranked_case_ids'] ?? const []);
      if (rankedIds.isEmpty) return _heuristicRerank(query, shortlist);

      final byId = {
        for (final candidate in shortlist) candidate.knowledgeBase.id: candidate,
      };
      final ranked = <SimilarVocResult>[];
      for (final id in rankedIds) {
        final candidate = byId.remove(id);
        if (candidate != null) ranked.add(candidate);
      }
      ranked.addAll(byId.values);
      return ranked.isEmpty ? _heuristicRerank(query, shortlist) : ranked;
    } catch (_) {
      return _heuristicRerank(query, shortlist);
    }
  }

  VocAnalysisResult _parseVocAnalysis(String raw) {
    try {
      final map = _jsonDecode(_extractJson(raw));
      return VocAnalysisResult(
        isBusiness: map['is_business'] as bool? ?? true,
        category: map['category'] as String? ?? '기능문의',
        reason: map['reason'] as String? ?? '',
      );
    } catch (_) {
      final isReject = raw.toUpperCase().contains('REJECT') ||
          raw.contains('업무와 관련 없') ||
          raw.contains('업무 무관');
      return VocAnalysisResult(
        isBusiness: !isReject,
        category: '기능문의',
        reason: raw.length > 100 ? raw.substring(0, 100) : raw,
      );
    }
  }

  AiAnswerResult _parseAnswerResult(String raw, List<SimilarVocResult> cases) {
    try {
      final map = _jsonDecode(_extractJson(raw));
      return AiAnswerResult(
        answer: UserFacingText.fromAi(map['answer'] as String? ?? raw),
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
        referencedCases: List<String>.from(map['referenced_cases'] ?? []),
        notes: UserFacingText.fromAi(map['notes'] as String? ?? ''),
      );
    } catch (_) {
      return AiAnswerResult(
        answer: UserFacingText.fromAi(raw),
        confidence: 0.5,
        referencedCases: cases.map((c) => c.knowledgeBase.question).toList(),
        notes: '',
      );
    }
  }

  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) return text;
    return text.substring(start, end + 1);
  }

  Map<String, dynamic> _jsonDecode(String json) {
    return Map<String, dynamic>.from(jsonDecode(json) as Map);
  }

  List<SimilarVocResult> _heuristicRerank(
    String query,
    List<SimilarVocResult> candidates,
  ) {
    final queryTokens = _tokenize(query);
    final queryVector = VectorUtils.simpleTextEmbedding(query);

    final scored = candidates.map((candidate) {
      final kb = candidate.knowledgeBase;
      final combinedText = '${kb.question} ${kb.answer} ${kb.category}'.toLowerCase();
      final overlapScore = queryTokens.isEmpty
          ? 0.0
          : queryTokens.where(combinedText.contains).length / queryTokens.length;
      final answerVector = VectorUtils.simpleTextEmbedding('${kb.question} ${kb.answer}');
      final semanticScore = VectorUtils.cosineSimilarity(queryVector, answerVector);
      final blendedScore = (candidate.similarityScore * 0.5) +
          (semanticScore * 0.3) +
          (overlapScore * 0.2);
      return MapEntry(candidate, blendedScore);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((entry) => entry.key).toList();
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^0-9a-z가-힣\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.length > 1)
        .toSet()
        .toList();
  }
}
