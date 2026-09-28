/// AI 정확도 추적 시스템
/// AI 권장사항과 실제 결과 비교를 통한 정확도 측정

/// AI 정확도 메트릭
class AiAccuracyMetric {
  final String? id;
  final String vocId;
  final bool categoryCorrect; // AI 카테고리 분류 정확도
  final bool assigneeCorrect; // AI 담당자 추천 정확도
  final bool urgencyCorrect; // AI 긴급도 예측 정확도
  final bool answerAdopted; // AI 생성 답변 채택 여부
  final double categoryConfidence; // 0.0 ~ 1.0
  final double assigneeConfidence;
  final double urgencyConfidence;
  final String? userFeedback; // 사용자 피드백
  final DateTime createdAt;

  AiAccuracyMetric({
    this.id,
    required this.vocId,
    required this.categoryCorrect,
    required this.assigneeCorrect,
    required this.urgencyCorrect,
    required this.answerAdopted,
    required this.categoryConfidence,
    required this.assigneeConfidence,
    required this.urgencyConfidence,
    this.userFeedback,
    required this.createdAt,
  });

  /// 평균 정확도
  double get averageAccuracy {
    int correctCount = 0;
    if (categoryCorrect) correctCount++;
    if (assigneeCorrect) correctCount++;
    if (urgencyCorrect) correctCount++;
    if (answerAdopted) correctCount++;
    return correctCount / 4;
  }

  /// 평균 신뢰도
  double get averageConfidence {
    return (categoryConfidence + assigneeConfidence + urgencyConfidence) / 3;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'voc_id': vocId,
      'category_correct': categoryCorrect ? 1 : 0,
      'assignee_correct': assigneeCorrect ? 1 : 0,
      'urgency_correct': urgencyCorrect ? 1 : 0,
      'answer_adopted': answerAdopted ? 1 : 0,
      'category_confidence': categoryConfidence,
      'assignee_confidence': assigneeConfidence,
      'urgency_confidence': urgencyConfidence,
      'user_feedback': userFeedback,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AiAccuracyMetric.fromMap(Map<String, dynamic> map) {
    return AiAccuracyMetric(
      id: map['id'] as String?,
      vocId: map['voc_id'] as String,
      categoryCorrect: (map['category_correct'] as int?) == 1,
      assigneeCorrect: (map['assignee_correct'] as int?) == 1,
      urgencyCorrect: (map['urgency_correct'] as int?) == 1,
      answerAdopted: (map['answer_adopted'] as int?) == 1,
      categoryConfidence: (map['category_confidence'] as num?)?.toDouble() ?? 0,
      assigneeConfidence: (map['assignee_confidence'] as num?)?.toDouble() ?? 0,
      urgencyConfidence: (map['urgency_confidence'] as num?)?.toDouble() ?? 0,
      userFeedback: map['user_feedback'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// AI 정확도 통계
class AiAccuracyStats {
  final int totalMetrics;
  final double categoryAccuracy; // 0.0 ~ 1.0
  final double assigneeAccuracy;
  final double urgencyAccuracy;
  final double answerAdoptionRate;
  final double overallAccuracy;
  final Map<String, double> accuracyByCategory; // 카테고리별 정확도
  final Map<String, double> accuracyByDepartment; // 부서별 정확도
  final double avgConfidence;
  final int improvementCount; // 개선된 항목

  AiAccuracyStats({
    required this.totalMetrics,
    required this.categoryAccuracy,
    required this.assigneeAccuracy,
    required this.urgencyAccuracy,
    required this.answerAdoptionRate,
    required this.overallAccuracy,
    required this.accuracyByCategory,
    required this.accuracyByDepartment,
    required this.avgConfidence,
    required this.improvementCount,
  });
}

/// AI 정확도 추적 서비스
abstract class AiAccuracyService {
  /// 정확도 메트릭 저장
  Future<AiAccuracyMetric> saveMetric(AiAccuracyMetric metric);

  /// VOC별 정확도 조회
  Future<AiAccuracyMetric?> getMetricByVocId(String vocId);

  /// 전체 정확도 통계 조회
  Future<AiAccuracyStats> getAccuracyStats();

  /// 기간별 정확도 추이
  Future<List<AiAccuracyMetric>> getMetricsForPeriod(
    DateTime startDate,
    DateTime endDate,
  );

  /// 사용자 피드백 저장
  Future<void> saveFeedback(String vocId, String feedback);

  /// 정확도 기준 개선 추천
  Future<List<String>> getImprovementRecommendations();
}

/// 기본 AI 정확도 서비스 구현
class DefaultAiAccuracyService implements AiAccuracyService {
  final Map<String, AiAccuracyMetric> _metricsCache = {};

  @override
  Future<AiAccuracyMetric> saveMetric(AiAccuracyMetric metric) async {
    // 실제 구현에서는 DB에 저장
    _metricsCache[metric.vocId] = metric;
    return metric;
  }

  @override
  Future<AiAccuracyMetric?> getMetricByVocId(String vocId) async {
    return _metricsCache[vocId];
  }

  @override
  Future<AiAccuracyStats> getAccuracyStats() async {
    if (_metricsCache.isEmpty) {
      return AiAccuracyStats(
        totalMetrics: 0,
        categoryAccuracy: 0,
        assigneeAccuracy: 0,
        urgencyAccuracy: 0,
        answerAdoptionRate: 0,
        overallAccuracy: 0,
        accuracyByCategory: {},
        accuracyByDepartment: {},
        avgConfidence: 0,
        improvementCount: 0,
      );
    }

    final metrics = _metricsCache.values.toList();
    int categoryCorrect = 0;
    int assigneeCorrect = 0;
    int urgencyCorrect = 0;
    int answerAdopted = 0;
    double totalConfidence = 0;

    for (final metric in metrics) {
      if (metric.categoryCorrect) categoryCorrect++;
      if (metric.assigneeCorrect) assigneeCorrect++;
      if (metric.urgencyCorrect) urgencyCorrect++;
      if (metric.answerAdopted) answerAdopted++;
      totalConfidence += metric.averageConfidence;
    }

    final count = metrics.length;

    return AiAccuracyStats(
      totalMetrics: count,
      categoryAccuracy: categoryCorrect / count,
      assigneeAccuracy: assigneeCorrect / count,
      urgencyAccuracy: urgencyCorrect / count,
      answerAdoptionRate: answerAdopted / count,
      overallAccuracy: (categoryCorrect + assigneeCorrect + urgencyCorrect + answerAdopted) /
          (count * 4),
      accuracyByCategory: {},
      accuracyByDepartment: {},
      avgConfidence: totalConfidence / count,
      improvementCount: count ~/2,
    );
  }

  @override
  Future<List<AiAccuracyMetric>> getMetricsForPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return _metricsCache.values
        .where((m) =>
            m.createdAt.isAfter(startDate) && m.createdAt.isBefore(endDate))
        .toList();
  }

  @override
  Future<void> saveFeedback(String vocId, String feedback) async {
    final metric = _metricsCache[vocId];
    if (metric != null) {
      _metricsCache[vocId] = metric.copyWith(userFeedback: feedback);
    }
  }

  @override
  Future<List<String>> getImprovementRecommendations() async {
    final stats = await getAccuracyStats();

    final recommendations = <String>[];

    if (stats.categoryAccuracy < 0.8) {
      recommendations.add(
          '📌 카테고리 분류 정확도(${(stats.categoryAccuracy * 100).toStringAsFixed(1)}%)를 높이기 위해 학습 데이터 추가 필요');
    }

    if (stats.assigneeAccuracy < 0.75) {
      recommendations.add(
          '👤 담당자 추천 정확도(${(stats.assigneeAccuracy * 100).toStringAsFixed(1)}%)를 개선하기 위해 부서별 기술 프로필 업데이트 권장');
    }

    if (stats.urgencyAccuracy < 0.85) {
      recommendations.add(
          '⚡ 긴급도 예측 정확도(${(stats.urgencyAccuracy * 100).toStringAsFixed(1)}%)를 높이기 위해 과거 긴급도 기준 재검토');
    }

    if (stats.answerAdoptionRate < 0.6) {
      recommendations.add(
          '💬 AI 생성 답변 채택률(${(stats.answerAdoptionRate * 100).toStringAsFixed(1)}%)이 낮으니 답변 생성 로직 점검');
    }

    if (stats.avgConfidence < 0.7) {
      recommendations.add('🎯 AI 신뢰도(${(stats.avgConfidence * 100).toStringAsFixed(1)}%)가 낮으니 모델 재학습 고려');
    }

    if (recommendations.isEmpty) {
      recommendations.add('✅ AI 정확도가 우수합니다. 현재 설정을 유지하세요.');
    }

    return recommendations;
  }
}

extension _Copy on AiAccuracyMetric {
  AiAccuracyMetric copyWith({String? userFeedback}) {
    return AiAccuracyMetric(
      id: id,
      vocId: vocId,
      categoryCorrect: categoryCorrect,
      assigneeCorrect: assigneeCorrect,
      urgencyCorrect: urgencyCorrect,
      answerAdopted: answerAdopted,
      categoryConfidence: categoryConfidence,
      assigneeConfidence: assigneeConfidence,
      urgencyConfidence: urgencyConfidence,
      userFeedback: userFeedback ?? this.userFeedback,
      createdAt: createdAt,
    );
  }
}
