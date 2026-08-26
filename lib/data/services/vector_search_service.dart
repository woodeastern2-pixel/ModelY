import '../../core/constants/app_constants.dart';
import '../../core/utils/privacy_masking_service.dart';
import '../../core/utils/vector_utils.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';
import '../datasources/remote/gemini_service.dart';
import '../datasources/remote/ollama_service.dart';
import '../datasources/remote/openai_service.dart';
import 'faiss_search_service.dart';

/// FAISS 대체 - 순수 Dart 코사인 유사도 벡터 검색
class VectorSearchService {
  final KnowledgeBaseRepository _kbRepository;
  OllamaService? _ollamaService;
  OpenAiService? _openAiService;
  GeminiService? _geminiService;
  FaissSearchService? _faissService;
  String _provider = AppConstants.aiProviderOllama;

  VectorSearchService(this._kbRepository);

  void configureOllama(String baseUrl, String model) {
    _ollamaService = OllamaService(baseUrl: baseUrl, model: model);
    _provider = AppConstants.aiProviderOllama;
  }

  void configureOpenAi(String apiKey, String model) {
    _openAiService = OpenAiService(apiKey: apiKey, chatModel: model);
    _provider = AppConstants.aiProviderOpenAi;
  }

  void configureGemini(String apiKey, String model) {
    _geminiService = GeminiService(apiKey: apiKey, chatModel: model);
    _provider = AppConstants.aiProviderGemini;
  }

  void setProvider(String provider) {
    _provider = provider;
  }

  void configureFaiss(String endpoint) {
    if (endpoint.trim().isEmpty) {
      _faissService = null;
      return;
    }
    _faissService = FaissSearchService(endpoint: endpoint.trim());
  }

  /// 쿼리 텍스트와 유사한 Top-K 지식베이스 항목 검색
  Future<List<SimilarVocResult>> searchSimilar(
    String query, {
    int? topK,
  }) async {
    final allEntries = await _kbRepository.getAllEntries();
    if (allEntries.isEmpty) return [];

    // 임베딩이 없는 항목들 임베딩 생성
    for (final entry in allEntries) {
      if (entry.embedding == null) {
        await _generateAndSaveEmbedding(entry);
      }
    }

    // 갱신된 임베딩 다시 로드
    final entriesWithEmb = await _kbRepository.getEntriesWithEmbeddings();
    if (entriesWithEmb.isEmpty) {
      // 폴백: 텍스트 기반 유사도
      return _textBasedSearch(query, allEntries, topK);
    }

    // 쿼리 임베딩 생성
    List<double> queryEmbedding;
    try {
      queryEmbedding = await _generateEmbedding(query);
    } catch (_) {
      queryEmbedding = VectorUtils.simpleTextEmbedding(query);
    }

    // FAISS 브릿지 사용 가능 시 우선 사용
    if (_faissService != null && await _faissService!.health()) {
      try {
        final effectiveTopK = topK ?? allEntries.length;
        final faissResults = await _faissService!
            .search(queryVector: queryEmbedding, topK: effectiveTopK);
        final byId = {
          for (final e in allEntries) e.id: e,
        };
        final mapped = <SimilarVocResult>[];
        for (final item in faissResults) {
          final id = item['id'] as String?;
          if (id == null || !byId.containsKey(id)) continue;
          mapped.add(
            SimilarVocResult(
              knowledgeBase: byId[id]!,
              similarityScore: (item['score'] as num?)?.toDouble() ?? 0.0,
            ),
          );
        }
        if (mapped.isNotEmpty) return mapped;
      } catch (_) {
        // FAISS 실패 시 로컬 코사인 검색으로 폴백
      }
    }

    // 코사인 유사도 계산
    final results = <SimilarVocResult>[];
    for (final entry in entriesWithEmb) {
      if (entry.embedding == null) continue;
      final score =
          VectorUtils.cosineSimilarity(queryEmbedding, entry.embedding!);
      if (score >= AppConstants.similarityThreshold) {
        results.add(
          SimilarVocResult(knowledgeBase: entry, similarityScore: score),
        );
      }
    }

    results.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return topK == null ? results : results.take(topK).toList();
  }

  Future<void> _generateAndSaveEmbedding(KnowledgeBaseEntity entry) async {
    try {
      final text = '${entry.question} ${entry.answer}';
      final embedding = await _generateEmbedding(text);
      await _kbRepository.updateEmbedding(entry.id, embedding);
      if (_faissService != null) {
        _faissService!.upsert(
          id: entry.id,
          vector: embedding,
          payload: {
            'question': PrivacyMaskingService.mask(entry.question),
            'answer': PrivacyMaskingService.mask(entry.answer),
            'category': entry.category,
          },
        );
      }
    } catch (_) {
      // 임베딩 생성 실패 시 폴백 저장
      final text = '${entry.question} ${entry.answer}';
      final embedding = VectorUtils.simpleTextEmbedding(text);
      await _kbRepository.updateEmbedding(entry.id, embedding);
    }
  }

  Future<List<double>> _generateEmbedding(String text) async {
    if (_provider == AppConstants.aiProviderGemini && _geminiService != null) {
      return await _geminiService!.embed(text);
    }
    if (_provider == AppConstants.aiProviderOpenAi && _openAiService != null) {
      return await _openAiService!.embed(text);
    }
    if (_ollamaService != null) {
      return await _ollamaService!.embed(text);
    }
    return VectorUtils.simpleTextEmbedding(text);
  }

  /// 텍스트 기반 폴백 검색
  List<SimilarVocResult> _textBasedSearch(
    String query,
    List<KnowledgeBaseEntity> entries,
    int? topK,
  ) {
    final queryEmb = VectorUtils.simpleTextEmbedding(query);
    final results = entries.map((entry) {
      final text = '${entry.question} ${entry.answer}';
      final entryEmb = VectorUtils.simpleTextEmbedding(text);
      final score = VectorUtils.cosineSimilarity(queryEmb, entryEmb);
      return SimilarVocResult(
        knowledgeBase: entry,
        similarityScore: score,
      );
    }).toList();

    results.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    final filtered = results.where((r) => r.similarityScore > 0).toList();
    return topK == null ? filtered : filtered.take(topK).toList();
  }

  /// 새 지식베이스 항목 임베딩 즉시 생성
  Future<void> indexEntry(KnowledgeBaseEntity entry) async {
    await _generateAndSaveEmbedding(entry);
  }
}
