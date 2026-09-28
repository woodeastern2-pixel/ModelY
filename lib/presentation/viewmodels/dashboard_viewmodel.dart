import 'package:flutter/foundation.dart';
import '../../domain/repositories/voc_repository.dart';
import '../../domain/repositories/knowledge_base_repository.dart';

class DashboardViewModel extends ChangeNotifier {
  final VocRepository _vocRepository;
  final KnowledgeBaseRepository _kbRepository;

  Map<String, int> _vocByStatus = {};
  Map<String, int> _vocByCategory = {};
  List<Map<String, dynamic>> _monthlyStats = [];
  int _totalVocs = 0;
  int _resolvedVocs = 0;
  int _kbCount = 0;
  double _aiUsageRate = 0.0;
  int _aiGeneratedResponses = 0;
  int _totalResponses = 0;
  double _avgProcessMinutes = 0.0;
  List<Map<String, dynamic>> _assigneeStats = [];
  int _recent30DayVocs = 0;
  int _highPriorityBacklogVocs = 0;
  String _risingKeyword = '-';
  int _risingKeywordDelta = 0;
  bool _isLoading = false;
  String? _error;

  DashboardViewModel(this._vocRepository, this._kbRepository) {
    loadDashboard();
  }

  Map<String, int> get vocByStatus => _vocByStatus;
  Map<String, int> get vocByCategory => _vocByCategory;
  List<Map<String, dynamic>> get monthlyStats => _monthlyStats;
  int get totalVocs => _totalVocs;
  int get resolvedVocs => _resolvedVocs;
  int get kbCount => _kbCount;
  double get aiUsageRate => _aiUsageRate;
  int get aiGeneratedResponses => _aiGeneratedResponses;
  int get totalResponses => _totalResponses;
  double get avgProcessMinutes => _avgProcessMinutes;
  List<Map<String, dynamic>> get assigneeStats => _assigneeStats;
  int get recent30DayVocs => _recent30DayVocs;
  int get highPriorityBacklogVocs => _highPriorityBacklogVocs;
  String get risingKeyword => _risingKeyword;
  int get risingKeywordDelta => _risingKeywordDelta;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get resolutionRate =>
      _totalVocs == 0 ? 0.0 : _resolvedVocs / _totalVocs;

  int get openVocs => _vocByStatus['OPEN'] ?? 0;
  int get inProgressVocs => _vocByStatus['IN_PROGRESS'] ?? 0;
  int get backlogVocs => openVocs + inProgressVocs;
  double get backlogRate => _totalVocs == 0 ? 0 : backlogVocs / _totalVocs;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _vocRepository.getVocCountByStatus(),
        _vocRepository.getVocCountByCategory(),
        _vocRepository.getMonthlyStats(),
        _kbRepository.getTotalCount(),
        _vocRepository.getAdvancedMetrics(),
        _vocRepository.getTopAssigneeStats(topN: 5),
        _vocRepository.getExecutiveInsightMetrics(),
      ]);

      _vocByStatus = results[0] as Map<String, int>;
      _vocByCategory = results[1] as Map<String, int>;
      _monthlyStats = results[2] as List<Map<String, dynamic>>;
      _kbCount = results[3] as int;
      final adv = results[4] as Map<String, dynamic>;
      _aiUsageRate = (adv['aiUsageRate'] as num?)?.toDouble() ?? 0.0;
      _aiGeneratedResponses = (adv['aiResponses'] as int?) ?? 0;
      _totalResponses = (adv['totalResponses'] as int?) ?? 0;
      _avgProcessMinutes =
          (adv['avgProcessMinutes'] as num?)?.toDouble() ?? 0.0;
      _assigneeStats = (results[5] as List<Map<String, dynamic>>);
      final executiveInsights = results[6] as Map<String, dynamic>;
      _recent30DayVocs = (executiveInsights['recent30DayVocs'] as int?) ?? 0;
      _highPriorityBacklogVocs =
          (executiveInsights['highPriorityBacklogVocs'] as int?) ?? 0;
      _risingKeyword = (executiveInsights['risingKeyword'] as String?) ?? '-';
      _risingKeywordDelta =
          (executiveInsights['risingKeywordDelta'] as int?) ?? 0;

      _totalVocs = _vocByStatus.values.fold(0, (a, b) => a + b);
      _resolvedVocs = _vocByStatus['RESOLVED'] ?? 0;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
