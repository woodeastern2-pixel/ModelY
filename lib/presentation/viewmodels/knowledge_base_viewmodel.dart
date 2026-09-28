import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/search_query_expander.dart';
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
  List<KnowledgeBaseEntity> _visible = [];
  Map<String, String> _searchBodies = {};
  Timer? _searchTimer;
  bool _disposed = false;
  int _loadGeneration = 0;
  int searchPasses = 0;
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;
  bool _isLoading = false;
  bool _isImportingManual = false;
  int _manualImportTotalSections = 0;
  int _manualImportProcessedSections = 0;
  int _manualImportGeneratedEntries = 0;
  String? _manualImportCurrentFile;
  String? _error;
  String _filterCategory = '';
  String _filterProduct = '';
  String _searchQuery = '';
  String _manualFileFilter = '';
  static const String _manualCategory =
      ManualDocumentImportService.manualCategory;

  KnowledgeBaseViewModel(this._repository, this._settingsViewModel) {
    _manualImportService = ManualDocumentImportService(_repository);
    _configureAiService();
    _settingsViewModel.addListener(_configureAiService);
    loadEntries();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _searchTimer?.cancel();
    _settingsViewModel.removeListener(_configureAiService);
    super.dispose();
  }

  List<KnowledgeBaseEntity> get entries => _visible;
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
  String get filterProduct => _filterProduct;
  String get searchQuery => _searchQuery;
  String get manualFileFilter => _manualFileFilter;

  List<KnowledgeBaseEntity> get _filtered {
    searchPasses++;
    var list = _entries;
    if (_filterCategory.isNotEmpty) {
      list = list.where((e) => e.category == _filterCategory).toList();
    }
    if (_filterProduct.isNotEmpty) {
      list = list.where((e) => e.project == _filterProduct).toList();
    }
    if (_manualFileFilter.isNotEmpty) {
      list = list
          .where(
            (entry) =>
                _isManualEntry(entry) &&
                _manualFileNameOf(entry) == _manualFileFilter,
          )
          .toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final matcher = SearchQueryExpander.compile(_searchQuery);
      list = list.where((e) => matcher.matchesNormalized(_searchBodies[e.id] ?? '')).toList();
    }
    return list;
  }

  void _refreshVisible() {
    _searchTimer?.cancel();
    _visible = List.unmodifiable(_filtered);
  }

  Future<void> _installEntries(List<KnowledgeBaseEntity> entries) async {
    final generation = ++_loadGeneration;
    final bodies = entries.length > 100
        ? await compute(_prepareSearchBodies, entries)
        : _prepareSearchBodies(entries);
    if (_disposed || generation != _loadGeneration) return;
    _entries = List.of(entries);
    _searchBodies = bodies;
    _sanitizeManualFileFilter();
    _refreshVisible();
  }

  Future<void> loadEntries() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _installEntries(await _repository.getAllEntries());
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      if (!_ready.isCompleted) _ready.complete();
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    _entries.removeWhere((e) => e.id == id);
    _searchBodies.remove(id);
    _refreshVisible();
    notifyListeners();
  }

  Future<ManualImportResult?> importManualDocuments(
    List<String> filePaths,
  ) async {
    final normalized = filePaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList();
    if (normalized.isEmpty) {
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
        onProgress: (progress) {
          _manualImportTotalSections = progress.totalSections;
          _manualImportProcessedSections = progress.processedSections;
          _manualImportGeneratedEntries = progress.generatedEntries;
          _manualImportCurrentFile = progress.currentFile;
          notifyListeners();
        },
      );
      await _installEntries(await _repository.getAllEntries());
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
    return {for (final key in sortedKeys) key: grouped[key]!};
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

    _entries.removeWhere(
      (entry) => toDelete.any((item) => item.id == entry.id),
    );
    _sanitizeManualFileFilter();
    _refreshVisible();
    notifyListeners();
    return toDelete.length;
  }

  void setFilter(String category) {
    _filterCategory = category;
    _refreshVisible();
    notifyListeners();
  }

  void setProductFilter(String product) {
    _filterProduct = product.trim();
    _refreshVisible();
    notifyListeners();
  }

  void setManualFileFilter(String fileName) {
    _manualFileFilter = fileName.trim();
    if (_manualFileFilter.isNotEmpty && _filterCategory != _manualCategory) {
      _filterCategory = _manualCategory;
    }
    _refreshVisible();
    notifyListeners();
  }

  void setSearch(String query) {
    if (_searchQuery == query || _disposed) return;
    _searchQuery = query;
    _searchTimer?.cancel();
    if (query.isEmpty) {
      _refreshVisible();
      notifyListeners();
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 180), () {
      if (_disposed) return;
      _refreshVisible();
      notifyListeners();
    });
  }

  List<String> get categories {
    final cats = _entries.map((e) => e.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<String> get products {
    final result = _entries
        .map((entry) => (entry.project ?? '').trim())
        .where((project) => project.startsWith('Brity '))
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  Map<String, int> get categoryStats {
    final map = <String, int>{};
    for (final e in _entries) {
      map[e.category] = (map[e.category] ?? 0) + 1;
    }
    return map;
  }

  bool _isManualEntry(KnowledgeBaseEntity entry) {
    return entry.category == _manualCategory;
  }

  String _manualFileNameOf(KnowledgeBaseEntity entry) {
    final source = (entry.customer ?? '').trim();
    return source.isNotEmpty ? source : '${entry.project ?? '기존 매뉴얼'} · 출처 미지정';
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


Map<String, String> _prepareSearchBodies(List<KnowledgeBaseEntity> entries) => {
  for (final e in entries) e.id: SearchQueryExpander.normalize(
      '${e.question} ${e.answer} ${e.project ?? ''} ${e.customer ?? ''} ${e.category}'),
};
