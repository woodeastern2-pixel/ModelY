import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/search_query_expander.dart';
import '../../core/utils/vector_utils.dart';
import '../../domain/entities/ai_chat_message_entity.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';
import '../../domain/repositories/indexed_knowledge_repository.dart';
import '../../domain/repositories/voc_repository.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/local_answer_service.dart';
import '../../data/services/vector_search_service.dart';
import 'settings_viewmodel.dart';

class AiChatSessionSummary {
  final String sessionId;
  final String title;
  final String preview;
  final int messageCount;
  final DateTime updatedAt;

  const AiChatSessionSummary({
    required this.sessionId,
    required this.title,
    required this.preview,
    required this.messageCount,
    required this.updatedAt,
  });
}

class AiViewModel extends ChangeNotifier {
  final KnowledgeBaseRepository _kbRepository;
  final VocRepository _vocRepository;
  final SettingsViewModel _settingsViewModel;
  final _uuid = const Uuid();

  late final AiService _aiService;
  late final VectorSearchService _vectorSearch;
  final LocalAnswerService _localAnswers = LocalAnswerService();

  bool _aiConnected = false;
  bool _connectionAttempted = false;
  bool get hasAiConfiguration => _connectionAttempted ||
      _settingsViewModel.settings['ai_connection_configured'] == 'true' ||
      (_settingsViewModel.aiProvider != AppConstants.aiProviderOllama
          ? _aiService.isConfigured
          : _settingsViewModel.ollamaUrl != AppConstants.defaultOllamaUrl ||
              _settingsViewModel.ollamaModel != AppConstants.defaultOllamaModel);
  bool _checkingConnection = false;
  int _configurationRevision = 0;
  List<Object?>? _configurationValues;
  bool _disposed = false;
  static const copilotUnavailable =
      '인공지능이 연결되지 않아 코파일럿을 사용할 수 없습니다. 설정에서 연결을 확인해 주세요.';
  bool get isAiConnected => _aiConnected;
  bool get isCheckingConnection => _checkingConnection;
  String get copilotStatusMessage => _checkingConnection
      ? '인공지능 연결을 확인하고 있습니다. 확인 전에는 코파일럿을 사용할 수 없습니다.'
      : _aiConnected
          ? '인공지능 연결이 확인되었습니다. 코파일럿을 사용할 수 있습니다.'
          : copilotUnavailable;

  bool _isAnalyzing = false;
  bool _isGenerating = false;
  bool _isSearching = false;
  bool _isChatting = false;
  String? _error;
  String? _chatError;

  VocAnalysisResult? _analysisResult;
  VocIntelligenceResult? _intelligenceResult;
  List<SimilarVocResult> _similarVocs = [];
  AiAnswerResult? _answerResult;
  bool _hasPartialAnswer = false;
  List<SimilarVocResult>? _generatedEvidence;
  List<SimilarVocResult> _suppliedEvidence = [];
  List<SimilarVocResult> get suppliedEvidence => _suppliedEvidence;
  bool _isAiAnswer = false;
  bool get isAiAnswer => _isAiAnswer;
  String? _searchError;
  String? get searchError => _searchError;
  String get generationStatus => _isSearching ? '참고 자료를 검색하고 있습니다.'
      : hasAiConfiguration ? 'AI에 답변 초안을 요청하고 있습니다.'
      : '저장된 자료로 답변 초안을 구성하고 있습니다.';
  bool _isClarificationAnswer = false;
  bool get isClarificationAnswer => _isClarificationAnswer;
  bool get hasPartialAnswer => _hasPartialAnswer;
  String? _urgencyReason;
  List<AssigneeRecommendation> _topAssignees = [];
  List<AiChatMessageEntity> _chatMessages = [];
  String? _activeChatSessionId;
  static const String _manualCategory = '시스템매뉴얼';

  AiViewModel(this._kbRepository, this._vocRepository, this._settingsViewModel,
      {AiService? aiService}) {
    _aiService = aiService ?? AiService();
    _vectorSearch = VectorSearchService(_kbRepository);
    _configureServices();
    _settingsViewModel.addListener(_handleSettingsChanged);
  }

  bool get isAnalyzing => _isAnalyzing;
  bool get isGenerating => _isGenerating;
  bool get isSearching => _isSearching;
  bool get isChatting => _isChatting;
  String? get error => _error;
  String? get chatError => _chatError;
  VocAnalysisResult? get analysisResult => _analysisResult;
  VocIntelligenceResult? get intelligenceResult => _intelligenceResult;
  List<SimilarVocResult> get similarVocs => _similarVocs;
  List<SimilarVocResult> get answerEvidence => _generatedEvidence ?? const [];
  AiAnswerResult? get answerResult => _answerResult;
  bool get hasAnswer => _answerResult != null;
  String? get urgencyReason => _urgencyReason;
  List<AssigneeRecommendation> get topAssignees => _topAssignees;
  List<AiChatMessageEntity> get chatMessages => _chatMessages;
  String? get activeChatSessionId => _activeChatSessionId;

  void _handleSettingsChanged() {
    _configureServices();
    notifyListeners();
  }

  void _configureServices() {
    final values = <Object?>[
      _settingsViewModel.aiProvider,
      _settingsViewModel.ollamaUrl, _settingsViewModel.ollamaModel,
      _settingsViewModel.openAiKey, _settingsViewModel.openAiModel,
      _settingsViewModel.geminiKey, _settingsViewModel.geminiModel,
      _settingsViewModel.claudeKey, _settingsViewModel.claudeModel,
      _settingsViewModel.claudeBaseUrl, _settingsViewModel.faissEndpoint,
      _settingsViewModel.aiTemperature, _settingsViewModel.aiMaxTokens,
    ];
    if (listEquals(values, _configurationValues)) return;
    _configurationValues = values;
    _configurationRevision++;
    _aiConnected = false;
    final provider = _settingsViewModel.aiProvider;
    _aiService.setProvider(provider);
    _vectorSearch.setProvider(provider);
    _vectorSearch.configureFaiss(_settingsViewModel.faissEndpoint);

    if (provider == AppConstants.aiProviderOllama) {
      _aiService.configureOllama(
        _settingsViewModel.ollamaUrl,
        _settingsViewModel.ollamaModel,
        temperature: _settingsViewModel.aiTemperature,
        maxTokens: _settingsViewModel.aiMaxTokens,
      );
      _vectorSearch.configureOllama(
        _settingsViewModel.ollamaUrl,
        _settingsViewModel.ollamaModel,
      );
      return;
    }

    if (provider == AppConstants.aiProviderGemini) {
      _aiService.configureGemini(
        _settingsViewModel.geminiKey,
        _settingsViewModel.geminiModel,
        temperature: _settingsViewModel.aiTemperature,
        maxTokens: _settingsViewModel.aiMaxTokens,
      );
      _vectorSearch.configureGemini(
        _settingsViewModel.geminiKey,
        _settingsViewModel.geminiModel,
      );
      return;
    }

    if (provider == AppConstants.aiProviderClaude) {
      _aiService.configureClaude(
        _settingsViewModel.claudeKey,
        _settingsViewModel.claudeBaseUrl,
        _settingsViewModel.claudeModel,
        temperature: _settingsViewModel.aiTemperature,
        maxTokens: _settingsViewModel.aiMaxTokens,
      );
      return;
    }

    _aiService.configureOpenAi(
      _settingsViewModel.openAiKey,
      _settingsViewModel.openAiModel,
      temperature: _settingsViewModel.aiTemperature,
      maxTokens: _settingsViewModel.aiMaxTokens,
    );
    _vectorSearch.configureOpenAi(
      _settingsViewModel.openAiKey,
      _settingsViewModel.openAiModel,
    );
  }

  /// 1단계: VOC 업무 관련 여부 분석
  Future<VocAnalysisResult?> analyzeVoc(String title, String content) async {
    if (!_ensureAiConfigured()) {
      return null;
    }
    _isAnalyzing = true;
    _error = null;
    _analysisResult = null;
    notifyListeners();

    try {
      _analysisResult = await _aiService.analyzeVoc(title, content);
      return _analysisResult;
    } catch (e) {
      _error = '분석 실패: $e';
      return null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<VocIntelligenceResult?> analyzeVocIntelligence(
    String title,
    String content,
  ) async {
    if (!_ensureAiConfigured()) {
      return null;
    }
    _isAnalyzing = true;
    _error = null;
    _intelligenceResult = null;
    _urgencyReason = null;
    notifyListeners();

    try {
      final assigneeStats = await _vocRepository.getTopAssigneeStats(topN: 10);
      _topAssignees = assigneeStats
          .map(
            (e) => AssigneeRecommendation(
              assignee: e['assignee'] as String,
              accuracy: (e['accuracy'] as num?)?.toDouble() ?? 0.0,
              handled: e['handled'] as int? ?? 0,
            ),
          )
          .take(3)
          .toList();

      final allVocs = await _vocRepository.getAllVocs();
      final queryEmb = VectorUtils.simpleTextEmbedding('$title $content');
      final dupCandidates = allVocs
          .map((v) {
            final emb = v.embedding ?? VectorUtils.simpleTextEmbedding('${v.title} ${v.content}');
            final score = VectorUtils.cosineSimilarity(queryEmb, emb);
            return {
              'id': v.id,
              'title': v.title,
              'content': v.content,
              'score': score,
            };
          })
          .where((m) => ((m['score'] as double?) ?? 0) >= 0.85)
          .toList()
        ..sort((a, b) => ((b['score'] as double?) ?? 0).compareTo((a['score'] as double?) ?? 0));

      _intelligenceResult = await _aiService.analyzeVocIntelligence(
        title: title,
        content: content,
        assigneeCandidates: assigneeStats,
        duplicateCandidates: dupCandidates.take(5).toList(),
      );

      _urgencyReason = await _aiService.predictUrgencyReason(
        title: title,
        content: content,
        urgency: _intelligenceResult!.urgency,
      );

      return _intelligenceResult;
    } catch (e) {
      _error = '고급 분석 실패: $e';
      return null;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// 2단계: 유사 VOC 검색
  Future<List<SimilarVocResult>> searchSimilarVocs(String query, {String? excludeVocId}) async {
    if (_isSearching) return _similarVocs;
    _isSearching = true;
    _searchError = null;
    notifyListeners();
    try {
      _similarVocs = await _localReferences(query, excludeVocId: excludeVocId);
      return _similarVocs;
    } catch (e) {
      _searchError = '자료 검색에 실패했습니다. 자료 다시 검색으로 재시도해 주세요.';
      _similarVocs = [];
      return [];
    } finally {
      _isSearching = false;
      if (!_disposed) notifyListeners();
    }
  }

  List<SimilarVocResult> _prioritizeManualReferences(
    String query,
    List<SimilarVocResult> candidates,
  ) {
    final queryLower = query.toLowerCase();
    final weighted = candidates.map((candidate) {
      var score = candidate.similarityScore;
      if (_isManualEntry(candidate)) {
        score += 0.18;
        final kb = candidate.knowledgeBase;
        final corpus = '${kb.question} ${kb.answer}'.toLowerCase();
        final overlap = _keywordOverlapRatio(queryLower, corpus);
        score += overlap * 0.15;
      }
      return MapEntry(candidate, score);
    }).toList();

    weighted.sort((a, b) => b.value.compareTo(a.value));
    return weighted.map((item) => item.key).toList();
  }

  List<SimilarVocResult> _prioritizeVocReferences(
    List<SimilarVocResult> candidates,
  ) {
    final weighted = candidates.map((candidate) {
      var score = candidate.similarityScore;
      if (_isVocHistoryEntry(candidate)) {
        score += 0.15;
      }
      return MapEntry(candidate, score);
    }).toList();

    weighted.sort((a, b) => b.value.compareTo(a.value));
    return weighted.map((item) => item.key).toList();
  }

  bool _isManualEntry(SimilarVocResult item) {
    final kb = item.knowledgeBase;
    return kb.category == _manualCategory || kb.question.contains('매뉴얼 섹션');
  }

  bool _isVocHistoryEntry(SimilarVocResult item) {
    final kb = item.knowledgeBase;
    return kb.vocId != null || kb.id.startsWith('voc-case-');
  }

  double _keywordOverlapRatio(String queryLower, String corpus) {
    return SearchQueryExpander.matchRatio(queryLower, corpus);
  }

  Future<List<SimilarVocResult>> _searchSimilarFromVocResponses(
    String query, {
    double minSimilarity = AppConstants.similarityThreshold,
    int? topK,
    bool includeLowSimilarityFallback = false,
  }) async {
    final queryEmb = VectorUtils.simpleTextEmbedding(
      SearchQueryExpander.expand(query),
    );
    final vocs = await _vocRepository.getAllVocs();
    final results = <SimilarVocResult>[];

    for (final voc in vocs) {
      final responses = await _vocRepository.getResponsesByVocId(voc.id);
      if (responses.isEmpty) {
        continue;
      }

      responses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final selected = responses.firstWhere(
        (r) => r.status == AppConstants.responseApproved,
        orElse: () => responses.first,
      );

      final vocEmb = voc.embedding ??
          VectorUtils.simpleTextEmbedding('${voc.title} ${voc.content}');
      final answerEmb = VectorUtils.simpleTextEmbedding(selected.content);

      final vocScore = VectorUtils.cosineSimilarity(queryEmb, vocEmb);
      final answerScore = VectorUtils.cosineSimilarity(queryEmb, answerEmb);
      final similarity = (vocScore * 0.6 + answerScore * 0.4).clamp(0.0, 1.0);

      if (similarity < minSimilarity) {
        continue;
      }

      results.add(
        SimilarVocResult(
          knowledgeBase: KnowledgeBaseEntity(
            id: 'voc-case-${voc.id}-${selected.id}',
            question: voc.title,
            answer: selected.content,
            category: voc.category,
            customer: voc.customer,
            project: voc.project,
            vocId: voc.id,
            resolvedAt: selected.updatedAt,
            createdAt: selected.createdAt,
          ),
          similarityScore: similarity,
          adoptionCount: selected.adoptionCount,
          usageCount: selected.usageCount,
          lastUsedAt: selected.lastUsedAt,
        ),
      );
    }

    results.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    if (results.isNotEmpty) {
      return topK == null ? results : results.take(topK).toList();
    }

    if (!includeLowSimilarityFallback) {
      return [];
    }

    final fallback = <SimilarVocResult>[];
    for (final voc in vocs) {
      final responses = await _vocRepository.getResponsesByVocId(voc.id);
      if (responses.isEmpty) continue;

      responses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final selected = responses.firstWhere(
        (r) => r.status == AppConstants.responseApproved,
        orElse: () => responses.first,
      );

      final lexicalScore = _keywordOverlapRatio(
        query.toLowerCase(),
        '${voc.title} ${voc.content} ${selected.content}'.toLowerCase(),
      );
      if (lexicalScore <= 0) continue;

      fallback.add(
        SimilarVocResult(
          knowledgeBase: KnowledgeBaseEntity(
            id: 'voc-case-${voc.id}-${selected.id}',
            question: voc.title,
            answer: selected.content,
            category: voc.category,
            customer: voc.customer,
            project: voc.project,
            vocId: voc.id,
            resolvedAt: selected.updatedAt,
            createdAt: selected.createdAt,
          ),
          similarityScore: lexicalScore.clamp(0.0, 1.0),
          adoptionCount: selected.adoptionCount,
          usageCount: selected.usageCount,
          lastUsedAt: selected.lastUsedAt,
        ),
      );
    }

    fallback.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return topK == null ? fallback : fallback.take(topK).toList();
  }

  /// 3단계: 확인된 AI 연결은 검토용 초안, 미연결은 자료 기반 답변.
  Future<AiAnswerResult?> generateAnswer(String title, String content, {String? excludeVocId, bool useLocal = false}) async {
    if (_isGenerating || _isSearching) return null;
    final revision = _configurationRevision;
    final requestAi = !useLocal && hasAiConfiguration;
    _isGenerating = true;
    _error = null;
    _answerResult = null;
    _hasPartialAnswer = false;
    _generatedEvidence = null;
    _suppliedEvidence = [];
    _isAiAnswer = false;
    _isClarificationAnswer = false;
    notifyListeners();

    try {
      final query = '$title\n$content';
      await searchSimilarVocs(query, excludeVocId: excludeVocId);
      if (_disposed || revision != _configurationRevision) {
        _error = '연결 설정이 변경되었습니다. 답변을 다시 생성해 주세요.';
        return null;
      }
      if (requestAi) {
        final references = _similarVocs.where((r) =>
            r.similarityScore >= 0.40 &&
            _localAnswers.isAnswerSource(r.knowledgeBase) &&
            _localAnswers.focusedEvidence(query, r.knowledgeBase)).take(5).toList();
        _suppliedEvidence = List.unmodifiable(references);
        notifyListeners();
        try {
          final result = await _aiService.generateReviewDraft(title, content, references)
              .timeout(const Duration(seconds: 60));
          if (_disposed || revision != _configurationRevision) {
            _error = '연결 설정이 변경되었습니다. 답변을 다시 생성해 주세요.';
            return null;
          }
          _generatedEvidence = references.where((r) =>
              result.referencedCaseIds.contains(r.knowledgeBase.id)).toList();
          _aiConnected = true;
          _isAiAnswer = true;
          _hasPartialAnswer = !_localAnswers.canAnswer(query, references) ||
              _localAnswers.evidenceGap(query, references).isNotEmpty ||
              _generatedEvidence!.isEmpty;
          _answerResult = result;
          return result;
        } catch (_) {
          if (_disposed || revision != _configurationRevision) {
            _error = '연결 설정이 변경되었습니다. 답변을 다시 생성해 주세요.';
            return null;
          }
          _aiConnected = false;
          _error = 'AI 답변 요청에 실패했습니다. 답변 다시 생성으로 재시도하거나, 저장 자료로 초안 만들기를 선택해 주세요.';
          return null;
        }
      }
      if (_searchError != null) {
        _error = _searchError;
        return null;
      }
      if (!_localAnswers.canAnswer(query, _similarVocs)) {
        if (!_localAnswers.needsWholeDataset(query)) {
          _isClarificationAnswer = true;
          _hasPartialAnswer = true;
          _generatedEvidence = const [];
          _answerResult = AiAnswerResult(
            answer: _localAnswers.clarificationDraft(title, content),
            confidence: 0,
            referencedCases: const [],
            notes: '내부 자료만으로 해결 절차를 확정할 수 없어 추가 확인용 초안을 작성했습니다. '
                '인공지능을 호출하지 않았으며, 검증된 해결 답변이 아닙니다.',
          );
          return _answerResult;
        }
        _error = _localAnswers.needsWholeDataset(query)
            ? '이 질문은 전체 자료의 분석이 필요합니다. 인공지능 연결 후 코파일럿을 이용해 주세요.'
            : (_similarVocs.isEmpty
                ? '검색한 자료에서 질문과 연결되는 설명을 찾지 못했습니다. 자료 자체가 없다는 뜻은 아닙니다. 제품·버전과 찾으시는 기능명을 확인해 주세요.'
                : '관련 자료는 찾았지만 요청하신 내용을 답변으로 확정할 근거가 부족합니다. 왼쪽 참고 자료에서 확인 가능한 설명과 출처를 확인해 주세요.');
        return null;
      }
      _hasPartialAnswer = _localAnswers.evidenceGap(
          query, _localAnswers.answerReferences(_similarVocs, query: query)).isNotEmpty;
      _generatedEvidence = _localAnswers.answerReferences(_similarVocs, query: query);
      _answerResult = AiAnswerResult(
        answer: _localAnswers.answerForQuery(query, _similarVocs),
        confidence: _similarVocs.first.similarityScore,
        referencedCases: _localAnswers.answerReferences(_similarVocs, query: query)
            .map((r) => r.knowledgeBase.question).toList(),
        notes: 'AI 연결 없이 매뉴얼과 승인된 답변에서 안내를 구성했습니다. 검색 점수는 정답 확률이 아닙니다. 출처의 제품·버전과 제한 조건을 확인해 주세요.',
      );
      return _answerResult;
    } catch (e) {
      _error = '답변 생성 실패: $e';
      return null;
    } finally {
      _isGenerating = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> checkCopilotConnection() async {
    if (_checkingConnection) return false;
    try {
      await testConnection();
      return _aiConnected;
    } catch (_) {
      return false;
    }
  }

  Future<String> testConnection() async {
    _connectionAttempted = true;
    _configureServices();
    final revision = _configurationRevision;
    _checkingConnection = true;
    notifyListeners();
    try {
      if (!_aiService.isConfigured) throw StateError('인공지능 설정이 필요합니다.');
      final result = await _aiService.testConnection()
          .timeout(const Duration(seconds: 8));
      if (result.trim().isEmpty) throw StateError('연결 응답이 없습니다.');
      if (_disposed || revision != _configurationRevision) {
        throw StateError('연결 설정이 변경되었습니다. 다시 확인해 주세요.');
      }
      if (_settingsViewModel.settings.isNotEmpty) {
        await _settingsViewModel.saveSetting('ai_connection_configured', 'true');
      }
      _aiConnected = true;
      _error = null;
      _chatError = null;
      return result;
    } catch (e) {
      _aiConnected = false;
      _error = copilotUnavailable;
      _chatError = copilotUnavailable;
      rethrow;
    } finally {
      _checkingConnection = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// 지식베이스에 VOC+답변 저장
  Future<KnowledgeBaseEntity> saveToKnowledgeBase({
    required String question,
    required String answer,
    required String category,
    String? customer,
    String? project,
    String? vocId,
  }) async {
    final now = DateTime.now();
    final entry = KnowledgeBaseEntity(
      id: _uuid.v4(),
      question: question,
      answer: answer,
      category: category,
      customer: customer,
      project: project,
      vocId: vocId,
      resolvedAt: now,
      createdAt: now,
    );
    final saved = await _kbRepository.createEntry(entry);
    return saved;
  }

  Future<void> startChatSession(String sessionId) async {
    _activeChatSessionId = sessionId;
    _chatError = null;
    await loadChatMessages(sessionId);
  }

  Future<String> createChatSession() async {
    final sessionId = _uuid.v4();
    _activeChatSessionId = sessionId;
    _chatMessages = [];
    _chatError = null;
    notifyListeners();
    return sessionId;
  }

  Future<List<AiChatSessionSummary>> loadChatSessions() async {
    final db = await DatabaseHelper.instance.database;
    final latestRows = await db.rawQuery('''
      SELECT session_id, content, created_at
      FROM ai_chat_messages
      WHERE created_at IN (
        SELECT MAX(created_at)
        FROM ai_chat_messages
        GROUP BY session_id
      )
      ORDER BY created_at DESC
    ''');

    final sessions = <AiChatSessionSummary>[];
    for (final row in latestRows) {
      final sessionId = row['session_id'] as String;
      final preview = (row['content'] as String? ?? '').trim();
      final updatedAt = DateTime.tryParse((row['created_at'] as String?) ?? '') ?? DateTime.now();

      final countRows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ai_chat_messages WHERE session_id = ?',
        [sessionId],
      );
      final messageCount = (countRows.first['cnt'] as int?) ?? 0;

      final firstUserRows = await db.query(
        'ai_chat_messages',
        columns: ['content'],
        where: 'session_id = ? AND role = ?',
        whereArgs: [sessionId, 'user'],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      final titleSource = firstUserRows.isNotEmpty
          ? (firstUserRows.first['content'] as String? ?? '')
          : preview;

      sessions.add(
        AiChatSessionSummary(
          sessionId: sessionId,
          title: _generateSessionTitle(titleSource),
          preview: preview,
          messageCount: messageCount,
          updatedAt: updatedAt,
        ),
      );
    }

    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  Future<List<AiChatMessageEntity>> loadChatMessages(String sessionId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'ai_chat_messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    _chatMessages = rows.map(_mapChatMessage).toList();
    _chatError = null;
    notifyListeners();
    return _chatMessages;
  }

  Future<AiChatMessageEntity?> sendChatMessage(String content) async {
    if (_isChatting || _checkingConnection) return null;
    if (!_aiConnected && !await checkCopilotConnection()) return null;
    final revision = _configurationRevision;
    final sessionId = _activeChatSessionId;
    if (sessionId == null) {
      _chatError = '채팅 세션이 초기화되지 않았습니다.';
      notifyListeners();
      return null;
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;

    _isChatting = true;
    _chatError = null;
    notifyListeners();

    try {
      final userMessage = await _insertChatMessage(
        sessionId: sessionId,
        role: 'user',
        content: trimmed,
        category: 'general',
      );
      _chatMessages = [..._chatMessages, userMessage];
      notifyListeners();

      final previousReferenceIds = _chatMessages
          .take(_chatMessages.length - 1)
          .toList()
          .reversed
          .expand((message) => message.referencedVocIds)
          .toSet()
          .toList();
      final references = await resolveChatReferences(
        trimmed,
        preferredVocIds:
            _isContextFollowUp(trimmed) ? previousReferenceIds : const [],
      );
      final reply = await _aiService.generateChatReply(
        message: trimmed,
        history: _chatMessages.take(_chatMessages.length - 1).toList(),
        references: references,
      ).timeout(const Duration(seconds: 60));
      if (reply.trim().isEmpty) throw StateError('인공지능 응답이 없습니다.');
      if (_disposed || revision != _configurationRevision ||
          sessionId != _activeChatSessionId) return null;
      final citedReferences = references;

      final assistantMessage = await _insertChatMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: reply,
        category: 'general',
        referencedVocIds: citedReferences.map((item) => item.knowledgeBase.vocId).whereType<String>().toList(),
        confidence: citedReferences.isEmpty ? null : citedReferences.first.similarityScore,
      );
      _chatMessages = [..._chatMessages, assistantMessage];
      notifyListeners();
      return assistantMessage;
    } catch (e) {
      _aiConnected = false;
      _chatError = '$copilotUnavailable 답변을 생성하지 않았습니다.';
      notifyListeners();
      return null;
    } finally {
      _isChatting = false;
      notifyListeners();
    }
  }

  Future<void> clearChatSession() async {
    _activeChatSessionId = null;
    _chatMessages = [];
    _chatError = null;
    notifyListeners();
  }

  void clearResults() {
    _isAiAnswer = false;
    _suppliedEvidence = [];
    _searchError = null;
    _isClarificationAnswer = false;
    _generatedEvidence = null;
    _hasPartialAnswer = false;
    _analysisResult = null;
    _intelligenceResult = null;
    _similarVocs = [];
    _answerResult = null;
    _urgencyReason = null;
    _topAssignees = [];
    _error = null;
    notifyListeners();
  }

  AiChatMessageEntity _mapChatMessage(Map<String, Object?> row) {
    final rawRefs = row['referenced_voc_ids'] as String?;
    final refs = rawRefs == null || rawRefs.isEmpty
        ? <String>[]
        : List<String>.from(jsonDecode(rawRefs) as List);
    return AiChatMessageEntity(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      category: row['category'] as String,
      role: row['role'] as String,
      content: row['content'] as String,
      referencedVocIds: refs,
      confidence: (row['confidence'] as num?)?.toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<AiChatMessageEntity> _insertChatMessage({
    required String sessionId,
    required String role,
    required String content,
    required String category,
    List<String>? referencedVocIds,
    double? confidence,
  }) async {
    final now = DateTime.now();
    final message = AiChatMessageEntity(
      id: _uuid.v4(),
      sessionId: sessionId,
      category: category,
      role: role,
      content: content,
      referencedVocIds: referencedVocIds ?? const [],
      confidence: confidence,
      createdAt: now,
    );
    final db = await DatabaseHelper.instance.database;
    await db.insert('ai_chat_messages', {
      'id': message.id,
      'session_id': message.sessionId,
      'category': message.category,
      'role': message.role,
      'content': message.content,
      'referenced_voc_ids': jsonEncode(message.referencedVocIds),
      'confidence': message.confidence,
      'created_at': message.createdAt.toIso8601String(),
    });
    return message;
  }

  /// AI Chat에서 지식베이스와 현재 등록된 VOC를 함께 검색한다.
  Future<List<SimilarVocResult>> resolveChatReferences(
    String query, {
    List<String> preferredVocIds = const [],
  }) => _localReferences(query,
      preferredVocIds: preferredVocIds, includeRegisteredQuestions: true);

  Future<List<SimilarVocResult>> _localReferences(
    String query, {
    List<String> preferredVocIds = const [],
    bool includeRegisteredQuestions = false,
    String? excludeVocId,
  }) async {
    if (!includeRegisteredQuestions && _kbRepository is IndexedKnowledgeRepository) {
      return (_kbRepository as IndexedKnowledgeRepository)
          .searchOffline(query, excludeVocId: excludeVocId);
    }
    final entries = <KnowledgeBaseEntity>[
      ...await _kbRepository.getAllEntries(),
    ];
    for (final voc in await _vocRepository.getAllVocs()) {
      final approved = (await _vocRepository.getResponsesByVocId(voc.id))
          .where((response) => response.isApproved)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (approved.isNotEmpty) {
        final response = approved.first;
        entries.add(KnowledgeBaseEntity(
          id: 'approved-voc-${voc.id}-${response.id}',
          question: '${voc.title} ${voc.content}',
          answer: response.content,
          category: voc.category,
          customer: voc.customer,
          project: voc.project,
          vocId: voc.id,
          resolvedAt: response.updatedAt,
          createdAt: response.createdAt,
        ));
      } else if (includeRegisteredQuestions) {
        entries.add(KnowledgeBaseEntity(
          id: 'registered-voc-${voc.id}',
          question: '${voc.title} ${voc.content}',
          answer: '등록된 VOC 상태: ${voc.status}\n내용: ${voc.content}',
          category: voc.category,
          customer: voc.customer,
          project: voc.project,
          vocId: voc.id,
          resolvedAt: voc.updatedAt,
          createdAt: voc.createdAt,
        ));
      }
    }
    final candidates = entries.where((entry) =>
        (excludeVocId == null || entry.vocId != excludeVocId) &&
        (includeRegisteredQuestions || _localAnswers.isAnswerSource(entry)));
    if (includeRegisteredQuestions || !query.contains('\n')) {
      return _localAnswers.rank(query, candidates,
          preferredVocIds: preferredVocIds);
    }
    final matches = <String, SimilarVocResult>{};
    final entriesForRanking = candidates.toList();
    for (final variant in _localAnswers.retrievalQueries(query)) {
      for (final result in _localAnswers.rank(variant, entriesForRanking,
          preferredVocIds: preferredVocIds)) {
        if (!_localAnswers.focusedEvidence(query, result.knowledgeBase)) continue;
        final id = result.knowledgeBase.id;
        if (!matches.containsKey(id) ||
            result.similarityScore > matches[id]!.similarityScore) {
          matches[id] = result;
        }
      }
      if (_localAnswers.canAnswer(query, matches.values.toList()) &&
          _localAnswers.evidenceGap(query,
              _localAnswers.answerReferences(matches.values.toList(), query: query)).isEmpty) {
        break;
      }
    }
    return (matches.values.toList()
      ..sort((a, b) => b.similarityScore.compareTo(a.similarityScore))).take(16).toList();
  }

  Future<List<SimilarVocResult>> _searchRegisteredVocReferences(
    String query, {
    int topK = 20,
    List<String> preferredVocIds = const [],
  }) async {
    final queryEmbedding = VectorUtils.simpleTextEmbedding(
      SearchQueryExpander.expand(query),
    );
    final vocs = await _vocRepository.getAllVocs();
    final results = <SimilarVocResult>[];

    for (final voc in vocs) {
      final isPreferred = preferredVocIds.contains(voc.id);
      final corpus = [
        voc.title,
        voc.content,
        voc.category,
        voc.tags ?? '',
        voc.customer,
        voc.project,
        voc.priority,
        voc.status,
      ].where((value) => value.trim().isNotEmpty).join(' ');
      final vocEmbedding =
          voc.embedding ?? VectorUtils.simpleTextEmbedding(corpus);
      final semanticScore =
          VectorUtils.cosineSimilarity(queryEmbedding, vocEmbedding);
      final lexicalScore = _keywordOverlapRatio(
        query.toLowerCase(),
        corpus.toLowerCase(),
      );
      final similarity = isPreferred
          ? 1.0
          : (semanticScore * 0.75 + lexicalScore * 0.25).clamp(0.0, 1.0);

      if (!isPreferred &&
          lexicalScore <= 0 &&
          semanticScore < AppConstants.similarityThreshold) {
        continue;
      }

      results.add(
        SimilarVocResult(
          knowledgeBase: KnowledgeBaseEntity(
            id: 'registered-voc-${voc.id}',
            question: voc.title,
            answer: '''VOC 내용: ${voc.content}
상태: ${voc.status}
우선순위: ${voc.priority}
고객사: ${voc.customer}
프로젝트: ${voc.project}''',
            category: voc.category,
            customer: voc.customer,
            project: voc.project,
            vocId: voc.id,
            resolvedAt: voc.updatedAt,
            createdAt: voc.createdAt,
          ),
          similarityScore: similarity,
        ),
      );
    }

    results.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return results.take(topK).toList();
  }

  bool _isContextFollowUp(String query) {
    final normalized = query.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.contains('그 voc') ||
        normalized.contains('그 사례') ||
        normalized.contains('해당 voc') ||
        normalized.contains('해당 사례') ||
        normalized.contains('방금') ||
        normalized.contains('앞서') ||
        normalized.startsWith('그럼 그') ||
        normalized.startsWith('그러면 그');
  }

  bool _ensureAiConfigured({bool forChat = false}) {
    if (_aiService.isConfigured) return true;
    final message = 'AI 제공자 설정이 완료되지 않았습니다. 설정 > AI 설정에서 API Key/모델을 확인해 주세요.';
    if (forChat) {
      _chatError = message;
    } else {
      _error = message;
    }
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _settingsViewModel.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  String _generateSessionTitle(String content) {
    final normalized = content
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .trim();
    if (normalized.isEmpty) return '새 채팅';

    final sentence = normalized.split(RegExp(r'[.!?]')).first.trim();
    final title = sentence.isEmpty ? normalized : sentence;
    if (title.length <= 26) return title;
    return '${title.substring(0, 26).trim()}...';
  }
}
