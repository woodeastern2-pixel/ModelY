import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/ai_service.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';
import '../../data/services/manual_document_import_service.dart';
import 'settings_viewmodel.dart';

class KnowledgeBaseViewModel extends ChangeNotifier {
  final KnowledgeBaseRepository _repository;
  final SettingsViewModel _settingsViewModel;
  late final ManualDocumentImportService _manualImportService;
  final AiService _aiService = AiService();

  List<KnowledgeBaseEntity> _entries = [];
  bool _isLoading = false;
  bool _isImportingManual = false;
  int _manualImportTotalSections = 0;
  int _manualImportProcessedSections = 0;
  int _manualImportGeneratedEntries = 0;
  String? _manualImportCurrentFile;
  String? _error;
  String _filterCategory = '';
  String _searchQuery = '';
  String _manualFileFilter = '';
  static const String _manualCategory = ManualDocumentImportService.manualCategory;
  static const String _manualProjectMarker = 'manual-upload';

  KnowledgeBaseViewModel(this._repository, this._settingsViewModel) {
    _manualImportService = ManualDocumentImportService(_repository);
    _configureAiService();
    _settingsViewModel.addListener(_configureAiService);
    loadEntries();
  }

  @override
  void dispose() {
    _settingsViewModel.removeListener(_configureAiService);
    super.dispose();
  }

  List<KnowledgeBaseEntity> get entries => _filtered;
  bool get isLoading => _isLoading;
  bool get isImportingManual => _isImportingManual;
  int get manualImportTotalSections => _manualImportTotalSections;
  int get manualImportProcessedSections => _manualImportProcessedSections;
  int get manualImportGeneratedEntries => _manualImportGeneratedEntries;
  String? get manualImportCurrentFile => _manualImportCurrentFile;
  double? get manualImportProgress {
    if (!_isImportingManual) return null;
    if (_manualImportTotalSections <= 0) return null;
    final ratio = _manualImportProcessedSections / _manualImportTotalSections;
    return ratio.clamp(0.0, 1.0);
  }
  String? get error => _error;
  String get filterCategory => _filterCategory;
  String get searchQuery => _searchQuery;
  String get manualFileFilter => _manualFileFilter;

  List<KnowledgeBaseEntity> get _filtered {
    var list = _entries;
    if (_filterCategory.isNotEmpty) {
      list = list.where((e) => e.category == _filterCategory).toList();
    }
    if (_manualFileFilter.isNotEmpty) {
      list = list
          .where((entry) =>
              _isManualEntry(entry) && _manualFileNameOf(entry) == _manualFileFilter)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((e) =>
              e.question.toLowerCase().contains(q) ||
              e.answer.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _entries = await _repository.getAllEntries();
      _sanitizeManualFileFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  Future<ManualImportResult?> importManualDocuments(List<String> filePaths) async {
    final normalized = filePaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
      return null;
    }

    if (!_ensureManualImportAiReady()) {
      notifyListeners();
      return null;
    }

    _isImportingManual = true;
    _manualImportTotalSections = 0;
    _manualImportProcessedSections = 0;
    _manualImportGeneratedEntries = 0;
    _manualImportCurrentFile = null;
    _error = null;
    notifyListeners();

    try {
      final result = await _manualImportService.importDocuments(
        normalized,
        qaGenerator: (fileName, sectionNumber, sectionTitle, sectionBody) async {
          final pairs = await _aiService.generateManualQaPairs(
            fileName: fileName,
            sectionLabel: '매뉴얼 섹션 $sectionNumber: $sectionTitle',
            sectionText: sectionBody,
          );

          if (pairs.isEmpty) {
            final fallbackQuestion =
                '[$fileName] 매뉴얼 섹션 $sectionNumber $sectionTitle은 어떻게 하나요?';
            final fallbackAnswer = await _aiService.refineManualAnswer(
              question: fallbackQuestion,
              sourceText: sectionBody,
            );
            return [
              ManualGeneratedQa(
                question: fallbackQuestion,
                answer: fallbackAnswer,
              ),
            ];
          }

          return pairs
              .map(
                (item) => ManualGeneratedQa(
                  question: item.question,
                  answer: item.answer,
                ),
              )
              .toList();
        },
        onProgress: (progress) {
          _manualImportTotalSections = progress.totalSections;
          _manualImportProcessedSections = progress.processedSections;
          _manualImportGeneratedEntries = progress.generatedEntries;
          _manualImportCurrentFile = progress.currentFile;
          notifyListeners();
        },
        answerRefiner: (question, sourceText) => _aiService.refineManualAnswer(
          question: question,
          sourceText: sourceText,
        ),
      );
      _entries = await _repository.getAllEntries();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isImportingManual = false;
      _manualImportCurrentFile = null;
      notifyListeners();
    }
  }

  void _configureAiService() {
    final provider = _settingsViewModel.aiProvider;
    _aiService.setProvider(provider);

    if (provider == AppConstants.aiProviderOllama) {
      _aiService.configureOllama(
        _settingsViewModel.ollamaUrl,
        _settingsViewModel.ollamaModel,
        temperature: _settingsViewModel.aiTemperature,
        maxTokens: _settingsViewModel.aiMaxTokens,
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
  }

  bool _ensureManualImportAiReady() {
    if (_aiService.isConfigured) {
      return true;
    }
    _error = 'AI 설정이 필요합니다. 설정에서 AI 제공자/API를 먼저 구성해 주세요.';
    return false;
  }

  bool isSupportedManualFile(String fileName) {
    return _manualImportService.isSupported(fileName);
  }

  Map<String, int> get manualEntriesByFile {
    final grouped = <String, int>{};
    for (final entry in _entries) {
      if (!_isManualEntry(entry)) continue;
      final fileName = _manualFileNameOf(entry);
      if (fileName.isEmpty) continue;
      grouped[fileName] = (grouped[fileName] ?? 0) + 1;
    }

    final sortedKeys = grouped.keys.toList()..sort();
    return {
      for (final key in sortedKeys) key: grouped[key]!,
    };
  }

  Future<int> deleteManualEntriesByFile(String fileName) async {
    final target = fileName.trim();
    if (target.isEmpty) return 0;

    final toDelete = _entries.where((entry) {
      return _isManualEntry(entry) && _manualFileNameOf(entry) == target;
    }).toList();

    for (final entry in toDelete) {
      await _repository.deleteEntry(entry.id);
    }

    _entries.removeWhere((entry) => toDelete.any((item) => item.id == entry.id));
    _sanitizeManualFileFilter();
    notifyListeners();
    return toDelete.length;
  }

  void setFilter(String category) {
    _filterCategory = category;
    notifyListeners();
  }

  void setManualFileFilter(String fileName) {
    _manualFileFilter = fileName.trim();
    if (_manualFileFilter.isNotEmpty && _filterCategory != _manualCategory) {
      _filterCategory = _manualCategory;
    }
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<String> get categories {
    final cats = _entries.map((e) => e.category).toSet().toList();
    cats.sort();
    return cats;
  }

  Map<String, int> get categoryStats {
    final map = <String, int>{};
    for (final e in _entries) {
      map[e.category] = (map[e.category] ?? 0) + 1;
    }
    return map;
  }

  bool _isManualEntry(KnowledgeBaseEntity entry) {
    return entry.category == _manualCategory &&
        (entry.project == _manualProjectMarker ||
            entry.question.contains('매뉴얼 섹션'));
  }

  String _manualFileNameOf(KnowledgeBaseEntity entry) {
    return (entry.customer ?? '').trim();
  }

  void _sanitizeManualFileFilter() {
    if (_manualFileFilter.isEmpty) {
      return;
    }
    if (!manualEntriesByFile.containsKey(_manualFileFilter)) {
      _manualFileFilter = '';
    }
  }
}
