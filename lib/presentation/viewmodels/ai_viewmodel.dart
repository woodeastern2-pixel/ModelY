import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/vector_utils.dart';
import '../../domain/entities/ai_chat_message_entity.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';
import '../../domain/repositories/voc_repository.dart';
import '../../data/services/ai_service.dart';
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
  String? _urgencyReason;
  List<AssigneeRecommendation> _topAssignees = [];
  List<AiChatMessageEntity> _chatMessages = [];
  String? _activeChatSessionId;
  static const String _manualCategory = '시스템매뉴얼';

  AiViewModel(this._kbRepository, this._vocRepository, this._settingsViewModel) {
    _aiService = AiService();
    _vectorSearch = VectorSearchService(_kbRepository);
    _configureServices();
    _settingsViewModel.addListener(_configureServices);
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
  AiAnswerResult? get answerResult => _answerResult;
  bool get hasAnswer => _answerResult != null;
  String? get urgencyReason => _urgencyReason;
  List<AssigneeRecommendation> get topAssignees => _topAssignees;
  List<AiChatMessageEntity> get chatMessages => _chatMessages;
  String? get activeChatSessionId => _activeChatSessionId;

  void _configureServices() {
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
  Future<List<SimilarVocResult>> searchSimilarVocs(String query) async {
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      final kbSimilar = await _vectorSearch.searchSimilar(query, topK: null);
      final vocResponseSimilar = await _searchSimilarFromVocResponses(query);

      final merged = <String, SimilarVocResult>{};
      for (final item in [...kbSimilar, ...vocResponseSimilar]) {
        final key = item.knowledgeBase.id;
        final prev = merged[key];
        if (prev == null || item.similarityScore > prev.similarityScore) {
          merged[key] = item;
        }
      }

      final mergedList = merged.values.toList()
        ..sort((a, b) => b.similarityScore.compareTo(a.similarityScore));

      final hasManualReference = mergedList.any((item) {
        if (!_isManualEntry(item)) return false;
        final kb = item.knowledgeBase;
        final corpus = '${kb.question} ${kb.answer}'.toLowerCase();
        return _keywordOverlapRatio(query.toLowerCase(), corpus) >= 0.2 ||
            item.similarityScore >= AppConstants.similarityThreshold;
      });

      List<SimilarVocResult> candidates = mergedList.toList();

      // 매뉴얼 적중이 없으면 기존 VOC 이력을 강제 폴백 후보로 추가한다.
      if (!hasManualReference) {
        final vocFallback = await _searchSimilarFromVocResponses(
          query,
          minSimilarity: 0.0,
          topK: null,
          includeLowSimilarityFallback: true,
        );

        final fallbackMerged = <String, SimilarVocResult>{
          for (final item in candidates) item.knowledgeBase.id: item,
        };
        for (final item in vocFallback) {
          final prev = fallbackMerged[item.knowledgeBase.id];
          if (prev == null || item.similarityScore > prev.similarityScore) {
            fallbackMerged[item.knowledgeBase.id] = item;
          }
        }
        candidates = fallbackMerged.values.toList();
        candidates.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
      }

      final reranked = await _aiService.rerankSimilarCases(
        query: query,
        candidates: candidates,
      );

      final prioritized = hasManualReference
          ? _prioritizeManualReferences(query, reranked)
          : _prioritizeVocReferences(reranked);

      _similarVocs = prioritized;
      return _similarVocs;
    } catch (e) {
      _error = '유사 VOC 검색 실패: $e';
      _similarVocs = [];
      return [];
    } finally {
      _isSearching = false;
      notifyListeners();
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
    final tokens = queryLower
        .replaceAll(RegExp(r'[^0-9a-z가-힣\s]'), ' ')
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toSet();
    if (tokens.isEmpty) return 0.0;
    final hits = tokens.where(corpus.contains).length;
    return hits / tokens.length;
  }

  Future<List<SimilarVocResult>> _searchSimilarFromVocResponses(
    String query, {
    double minSimilarity = AppConstants.similarityThreshold,
    int? topK,
    bool includeLowSimilarityFallback = false,
  }
  ) async {
    final queryEmb = VectorUtils.simpleTextEmbedding(query);
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

      final vocEmb =
          voc.embedding ?? VectorUtils.simpleTextEmbedding('${voc.title} ${voc.content}');
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

  /// 3단계: AI 답변 생성 (RAG)
  Future<AiAnswerResult?> generateAnswer(String title, String content) async {
    if (!_ensureAiConfigured()) {
      return null;
    }
    _isGenerating = true;
    _error = null;
    _answerResult = null;
    notifyListeners();

    try {
      // 유사 VOC 검색 (없으면 다시 검색)
      if (_similarVocs.isEmpty) {
        await searchSimilarVocs('$title $content');
      }
      final answerCases = _similarVocs;
      _answerResult = await _aiService.generateAnswer(title, content, answerCases);
      return _answerResult;
    } catch (e) {
      _error = '답변 생성 실패: $e';
      return null;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<String> testConnection() async {
    _configureServices();
    if (!_ensureAiConfigured()) {
      throw Exception(_error ?? 'AI 제공자 설정이 완료되지 않았습니다.');
    }

    try {
      final result = await _aiService.testConnection();
      _error = null;
      notifyListeners();
      return result;
    } catch (e) {
      _error = 'AI 통신 테스트 실패: $e';
      notifyListeners();
      rethrow;
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
    // 백그라운드로 임베딩 인덱싱
    _vectorSearch.indexEntry(saved);
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
    if (!_ensureAiConfigured(forChat: true)) {
      return null;
    }
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
      );

      final assistantMessage = await _insertChatMessage(
        sessionId: sessionId,
        role: 'assistant',
        content: reply,
        category: 'general',
        referencedVocIds: references.map((item) => item.knowledgeBase.vocId).whereType<String>().toList(),
        confidence: references.isEmpty ? null : references.first.similarityScore,
      );
      _chatMessages = [..._chatMessages, assistantMessage];
      notifyListeners();
      return assistantMessage;
    } catch (e) {
      _chatError = '채팅 실패: $e';
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
  }) async {
    final knowledgeReferences = await _vectorSearch.searchSimilar(query, topK: 20);
    final vocReferences = await _searchRegisteredVocReferences(
      query,
      topK: 20,
      preferredVocIds: preferredVocIds,
    );

    final merged = <String, SimilarVocResult>{};
    for (final item in [...knowledgeReferences, ...vocReferences]) {
      final key = item.knowledgeBase.id;
      final previous = merged[key];
      if (previous == null || item.similarityScore > previous.similarityScore) {
        merged[key] = item;
      }
    }

    final reranked = await _aiService.rerankSimilarCases(
      query: query,
      candidates: merged.values.toList(),
    );
    final prioritized = _prioritizeVocReferences(reranked);
    return prioritized.take(5).toList();
  }

  Future<List<SimilarVocResult>> _searchRegisteredVocReferences(
    String query, {
    int topK = 20,
    List<String> preferredVocIds = const [],
  }) async {
    final queryEmbedding = VectorUtils.simpleTextEmbedding(query);
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
      final vocEmbedding = voc.embedding ?? VectorUtils.simpleTextEmbedding(corpus);
      final semanticScore = VectorUtils.cosineSimilarity(queryEmbedding, vocEmbedding);
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
    _settingsViewModel.removeListener(_configureServices);
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
