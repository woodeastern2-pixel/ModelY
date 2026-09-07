import 'package:flutter/foundation.dart';
import '../../domain/repositories/voc_repository.dart';
import '../../domain/repositories/knowledge_base_repository.dart';
import '../../domain/services/ai_accuracy_service.dart';
import '../../domain/services/executive_dashboard_service.dart';
import '../../data/services/ai_service.dart';
import 'settings_viewmodel.dart';

class DashboardViewModel extends ChangeNotifier {
  final VocRepository _vocRepository;
  final KnowledgeBaseRepository _kbRepository;
  final SettingsViewModel _settingsViewModel;
  final RoiCalculator _roiCalculator = DefaultRoiCalculator();
  final AiAccuracyService _aiAccuracyService = DefaultAiAccuracyService();
  late final AiService _aiService;

  Map<String, int> _vocByStatus = {};
  Map<String, int> _vocByCategory = {};
  List<Map<String, dynamic>> _monthlyStats = [];
  int _totalVocs = 0;
  int _resolvedVocs = 0;
  int _kbCount = 0;
  double _duplicateReductionRate = 0.0;
  double _aiUsageRate = 0.0;
  double _avgProcessMinutes = 0.0;
  List<Map<String, dynamic>> _assigneeStats = [];
  double _reopenRate = 0.0;
  int _reopenedCount = 0;
  int _resolvedForReopenRate = 0;
  String _risingKeyword = '-';
  int _risingKeywordDelta = 0;
  String _topSegmentName = '-';
  double _topSegmentScore = 0.0;
  int _topSegmentVolume = 0;
  RoiResult? _roiResult;
  double _aiOverallAccuracy = 0.0;
  double _aiAnswerAdoptionRate = 0.0;
  List<String> _accuracyRecommendations = [];
  List<String> _executiveAiRecommendations = [];
  DateTime? _executiveAiUpdatedAt;
  RoiCalculatorInput? _roiInputSnapshot;
  ExecutiveKpiDashboard? _executiveKpi;
  bool _isLoading = false;
  String? _error;

  DashboardViewModel(
    this._vocRepository,
    this._kbRepository,
    this._settingsViewModel,
  ) {
    _aiService = AiService();
    _configureAiService();
    _settingsViewModel.addListener(_configureAiService);
    loadDashboard();
  }

  Map<String, int> get vocByStatus => _vocByStatus;
  Map<String, int> get vocByCategory => _vocByCategory;
  List<Map<String, dynamic>> get monthlyStats => _monthlyStats;
  int get totalVocs => _totalVocs;
  int get resolvedVocs => _resolvedVocs;
  int get kbCount => _kbCount;
  double get duplicateReductionRate => _duplicateReductionRate;
  double get aiUsageRate => _aiUsageRate;
  double get avgProcessMinutes => _avgProcessMinutes;
  List<Map<String, dynamic>> get assigneeStats => _assigneeStats;
  double get reopenRate => _reopenRate;
  int get reopenedCount => _reopenedCount;
  int get resolvedForReopenRate => _resolvedForReopenRate;
  String get risingKeyword => _risingKeyword;
  int get risingKeywordDelta => _risingKeywordDelta;
  String get topSegmentName => _topSegmentName;
  double get topSegmentScore => _topSegmentScore;
  int get topSegmentVolume => _topSegmentVolume;
  RoiResult? get roiResult => _roiResult;
  double get aiOverallAccuracy => _aiOverallAccuracy;
  double get aiAnswerAdoptionRate => _aiAnswerAdoptionRate;
  List<String> get accuracyRecommendations => _accuracyRecommendations;
  List<String> get executiveAiRecommendations => _executiveAiRecommendations;
  DateTime? get executiveAiUpdatedAt => _executiveAiUpdatedAt;
  RoiCalculatorInput? get roiInputSnapshot => _roiInputSnapshot;
  ExecutiveKpiDashboard? get executiveKpi => _executiveKpi;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get resolutionRate =>
      _totalVocs == 0 ? 0.0 : _resolvedVocs / _totalVocs;

  int get openVocs => _vocByStatus['OPEN'] ?? 0;
  int get inProgressVocs => _vocByStatus['IN_PROGRESS'] ?? 0;
  int get backlogVocs => openVocs + inProgressVocs;
  double get backlogRate => _totalVocs == 0 ? 0 : backlogVocs / _totalVocs;

  double get monthlyVocTrendPercent {
    if (_monthlyStats.length < 2) return 0.0;
    final last = (_monthlyStats.last['total'] as int?) ?? 0;
    final prev = (_monthlyStats[_monthlyStats.length - 2]['total'] as int?) ?? 0;
    if (prev == 0) return last == 0 ? 0.0 : 1.0;
    return (last - prev) / prev;
  }

  @override
  void dispose() {
    _settingsViewModel.removeListener(_configureAiService);
    super.dispose();
  }

  void _configureAiService() {
    final provider = _settingsViewModel.aiProvider;
    _aiService.setProvider(provider);

    if (provider == 'ollama') {
      _aiService.configureOllama(
        _settingsViewModel.ollamaUrl,
        _settingsViewModel.ollamaModel,
        temperature: _settingsViewModel.aiTemperature,
        maxTokens: _settingsViewModel.aiMaxTokens,
      );
      return;
    }

    if (provider == 'gemini') {
      _aiService.configureGemini(
        _settingsViewModel.geminiKey,
        _settingsViewModel.geminiModel,
        temperature: _settingsViewModel.aiTemperature,
        maxTokens: _settingsViewModel.aiMaxTokens,
      );
      return;
    }

    if (provider == 'claude') {
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
      _duplicateReductionRate = (adv['duplicateReductionRate'] as num?)?.toDouble() ?? 0.0;
      _aiUsageRate = (adv['aiUsageRate'] as num?)?.toDouble() ?? 0.0;
      _avgProcessMinutes = (adv['avgProcessMinutes'] as num?)?.toDouble() ?? 0.0;
      _assigneeStats = (results[5] as List<Map<String, dynamic>>);
      final executiveInsights = results[6] as Map<String, dynamic>;
      _reopenRate =
          (executiveInsights['reopenRate'] as num?)?.toDouble() ?? 0.0;
      _reopenedCount = (executiveInsights['reopenedCount'] as int?) ?? 0;
      _resolvedForReopenRate =
          (executiveInsights['resolvedCount'] as int?) ?? 0;
      _risingKeyword = (executiveInsights['risingKeyword'] as String?) ?? '-';
      _risingKeywordDelta =
          (executiveInsights['risingKeywordDelta'] as int?) ?? 0;
      _topSegmentName =
          (executiveInsights['topSegmentName'] as String?) ?? '-';
      _topSegmentScore =
          (executiveInsights['topSegmentScore'] as num?)?.toDouble() ?? 0.0;
      _topSegmentVolume =
          (executiveInsights['topSegmentVolume'] as int?) ?? 0;

      _totalVocs = _vocByStatus.values.fold(0, (a, b) => a + b);
      _resolvedVocs = _vocByStatus['RESOLVED'] ?? 0;

      await _loadExecutiveAndRoiMetrics();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadExecutiveAndRoiMetrics() async {
    _executiveKpi = await _roiCalculator.getExecutiveDashboard();

    final accuracyStats = await _aiAccuracyService.getAccuracyStats();
    _aiOverallAccuracy = accuracyStats.overallAccuracy;
    _aiAnswerAdoptionRate = accuracyStats.answerAdoptionRate;

    _roiInputSnapshot = RoiCalculatorInput(
      monthlyVocVolume: _totalVocs == 0 ? 100 : _totalVocs,
      avgHandleTimeHours: _avgProcessMinutes <= 0 ? 3.5 : _avgProcessMinutes / 60,
      hourlyLaborCost: 35.0,
      aiImplementationCost: 50000,
      monthlyAiMaintenanceCost: 2500,
      automationRate: _aiUsageRate <= 0 ? 0.65 : _aiUsageRate.clamp(0.0, 1.0),
      aiAccuracyRate: _aiOverallAccuracy <= 0 ? 0.9 : _aiOverallAccuracy.clamp(0.0, 1.0),
    );
    _roiResult = _roiCalculator.calculateRoi(_roiInputSnapshot!);

    _accuracyRecommendations =
        await _aiAccuracyService.getImprovementRecommendations();

    await _buildExecutiveAiRecommendations();
  }

  Future<void> _buildExecutiveAiRecommendations() async {
    final roi = _roiResult;
    if (roi == null) {
      _executiveAiRecommendations = _accuracyRecommendations.take(3).toList();
      _executiveAiUpdatedAt = DateTime.now();
      return;
    }

    final metrics = {
      'total_vocs': _totalVocs,
      'resolved_vocs': _resolvedVocs,
      'backlog_vocs': backlogVocs,
      'backlog_rate': backlogRate,
      'ai_accuracy': _aiOverallAccuracy,
      'answer_adoption_rate': _aiAnswerAdoptionRate,
      'ai_usage_rate': _aiUsageRate,
      'duplicate_reduction_rate': _duplicateReductionRate,
      'monthly_voc_trend_percent': monthlyVocTrendPercent,
      'monthly_savings_hours': roi.monthlySavingsHours,
      'monthly_gross_savings_cost': roi.monthlySavingsCost,
      'monthly_net_savings_cost': roi.monthlyNetSavingsCost,
      'yearly_net_savings_cost': roi.yearlySavingsCost,
      'roi_percent': roi.roi,
      'payback_months': roi.implementationPaybackMonths,
      'ai_effectiveness': roi.aiEffectiveness,
    };

    if (_aiService.isConfigured) {
      try {
        final aiRecs = await _aiService.generateExecutiveRecommendations(
          metrics: metrics,
        );
        if (aiRecs.isNotEmpty) {
          _executiveAiRecommendations = aiRecs;
          _executiveAiUpdatedAt = DateTime.now();
          return;
        }
      } catch (_) {
        // fall through to deterministic fallback
      }
    }

    _executiveAiRecommendations = [
      if (backlogRate >= 0.25)
        '미완료 VOC가 많습니다. 오늘 안에 담당자를 다시 배정해 주세요.'
      else
        '미완료 VOC 비율이 안정적입니다. 현재 처리 기준을 유지해 주세요.',
      if (monthlyVocTrendPercent > 0.1)
        '지난달보다 VOC가 크게 늘었습니다. 가장 많이 늘어난 유형의 원인을 확인해 주세요.'
      else
        'VOC 증감이 크지 않습니다. 반복 문의부터 자동화를 검토해 주세요.',
      if (roi.roi < 50)
        '예상 투자 효과가 낮습니다. AI 답변 초안 기능을 우선 적용해 보세요.'
      else
        '예상 투자 효과가 양호합니다. 처리 비용이 높은 채널부터 적용 범위를 넓혀보세요.',
      if (_aiAnswerAdoptionRate < 0.6)
        'AI 답변 승인 여부를 매일 기록해 품질 개선에 활용하세요.'
      else
        '승인된 AI 답변을 다시 사용할 수 있도록 지식 자료로 정리하세요.',
    ];
    _executiveAiUpdatedAt = DateTime.now();
  }
}
