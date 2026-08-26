/// 경영진용 KPI 대시보드 및 ROI 계산기

/// ROI 계산 입력
class RoiCalculatorInput {
  final int monthlyVocVolume;      // 월간 VOC 건수
  final double avgHandleTimeHours; // 평균 처리 시간 (시간)
  final double hourlyLaborCost;    // 인건비 (시간당 USD)
  final double aiImplementationCost; // AI 구현 비용 (USD)
  final double monthlyAiMaintenanceCost; // 월간 유지비 (USD)
  final double automationRate; // 자동화율 (0.0 ~ 1.0)
  final double aiAccuracyRate; // AI 정확도 (0.0 ~ 1.0)

  RoiCalculatorInput({
    required this.monthlyVocVolume,
    required this.avgHandleTimeHours,
    required this.hourlyLaborCost,
    required this.aiImplementationCost,
    required this.monthlyAiMaintenanceCost,
    required this.automationRate,
    required this.aiAccuracyRate,
  });

  Map<String, dynamic> toMap() => {
    'monthlyVocVolume': monthlyVocVolume,
    'avgHandleTimeHours': avgHandleTimeHours,
    'hourlyLaborCost': hourlyLaborCost,
    'aiImplementationCost': aiImplementationCost,
    'monthlyAiMaintenanceCost': monthlyAiMaintenanceCost,
    'automationRate': automationRate,
    'aiAccuracyRate': aiAccuracyRate,
  };
}

/// ROI 계산 결과
class RoiResult {
  final double monthlySavingsHours;     // 월간 절감 시간 (시)
  final double monthlySavingsCost;      // 월간 총 절감액 (USD)
  final double monthlyNetSavingsCost;   // 월간 순 절감액 (USD)
  final double yearlySavingsCost;       // 연간 순 절감액 (USD)
  final double implementationPaybackMonths; // 회수 기간 (개월)
  final double productivityGainPercent; // 생산성 향상율 (%)
  final double roi; // ROI (%)
  final double aiEffectiveness; // AI 효과도 (0-100)
  final String recommendation;

  RoiResult({
    required this.monthlySavingsHours,
    required this.monthlySavingsCost,
    required this.monthlyNetSavingsCost,
    required this.yearlySavingsCost,
    required this.implementationPaybackMonths,
    required this.productivityGainPercent,
    required this.roi,
    required this.aiEffectiveness,
    required this.recommendation,
  });

  Map<String, dynamic> toMap() => {
    'monthlySavingsHours': monthlySavingsHours,
    'monthlySavingsCost': monthlySavingsCost,
    'monthlyNetSavingsCost': monthlyNetSavingsCost,
    'yearlySavingsCost': yearlySavingsCost,
    'implementationPaybackMonths': implementationPaybackMonths,
    'productivityGainPercent': productivityGainPercent,
    'roi': roi,
    'aiEffectiveness': aiEffectiveness,
    'recommendation': recommendation,
  };
}

/// Executive KPI Dashboard 데이터
class ExecutiveKpiDashboard {
  final int totalVocs;
  final int openVocs;
  final int inProgressVocs;
  final int resolvedVocs;
  final double resolutionRate;
  final double avgProcessingTimeHours;
  final double aiUtilizationRate;
  final double autoResponseRate;
  final double duplicateReductionRate;
  final Map<String, int> departmentLoadMap;
  final List<int> monthlyTrend; // 지난 12개월
  final double employeeProductivity; // VOC/person/month
  final RoiResult? roiResult;
  final List<String> aiAccuracyRecommendations;

  ExecutiveKpiDashboard({
    required this.totalVocs,
    required this.openVocs,
    required this.inProgressVocs,
    required this.resolvedVocs,
    required this.resolutionRate,
    required this.avgProcessingTimeHours,
    required this.aiUtilizationRate,
    required this.autoResponseRate,
    required this.duplicateReductionRate,
    required this.departmentLoadMap,
    required this.monthlyTrend,
    required this.employeeProductivity,
    this.roiResult,
    required this.aiAccuracyRecommendations,
  });

  /// 경영진 요약
  String get executiveSummary => '''
📊 AI VOC 플랫폼 운영 성과

✅ VOC 처리: $totalVocs건 ($resolvedVocs 해결)
✅ 해결율: ${(resolutionRate * 100).toStringAsFixed(1)}%
✅ 평균 처리: ${avgProcessingTimeHours.toStringAsFixed(1)}시간
✅ AI 활용률: ${(aiUtilizationRate * 100).toStringAsFixed(1)}%
✅ 자동응답: ${(autoResponseRate * 100).toStringAsFixed(1)}%
✅ 중복감소: ${(duplicateReductionRate * 100).toStringAsFixed(1)}%
✅ 생산성: ${employeeProductivity.toStringAsFixed(1)} VOC/인/월

${roiResult != null ? '''
💰 ROI 성과:
- 월간절감: \$${roiResult!.monthlySavingsCost.toStringAsFixed(0)}
- 연간절감: \$${roiResult!.yearlySavingsCost.toStringAsFixed(0)}
- ROI: ${roiResult!.roi.toStringAsFixed(1)}%
- 회수기간: ${roiResult!.implementationPaybackMonths.toStringAsFixed(1)}개월
''' : ''}
''';
}

/// ROI 계산 엔진
abstract class RoiCalculator {
  /// ROI 계산
  RoiResult calculateRoi(RoiCalculatorInput input);

  /// Executive Dashboard 조회
  Future<ExecutiveKpiDashboard> getExecutiveDashboard();
}

/// 기본 ROI 계산 구현
class DefaultRoiCalculator implements RoiCalculator {
  @override
  RoiResult calculateRoi(RoiCalculatorInput input) {
    // 1. 월간 절감 시간 계산
    // 자동화로 절감되는 시간 = VOC 건수 * 평균 처리시간 * 자동화율 * AI 정확도
    final monthlySavingsHours = input.monthlyVocVolume *
        input.avgHandleTimeHours *
        input.automationRate *
        input.aiAccuracyRate;

    // 2. 월간 절감 비용
    final monthlySavingsCost = monthlySavingsHours * input.hourlyLaborCost;

    // 3. 월간 순 절감 (유지비 차감)
    final monthlyNetSavings =
        monthlySavingsCost - input.monthlyAiMaintenanceCost;

    // 4. 연간 절감
    final yearlySavingsCost = monthlyNetSavings * 12;

    // 5. 회수 기간 계산
    final implementationPaybackMonths = monthlyNetSavings > 0
        ? input.aiImplementationCost / monthlyNetSavings
        : double.infinity;

    // 6. 생산성 향상율
    final productivityGainPercent = (input.automationRate * 100).toDouble();

    // 7. ROI 계산 (연간 기준)
    final totalInvestment =
        input.aiImplementationCost + (input.monthlyAiMaintenanceCost * 12);
    final roi =
        totalInvestment > 0 ? ((yearlySavingsCost / totalInvestment) * 100).toDouble() : 0.0;

    // 8. AI 효과도
    final aiEffectiveness =
        ((input.automationRate * 40) + (input.aiAccuracyRate * 60)).toDouble();

    // 9. 권장사항
    final recommendation = _generateRecommendation(
      roi: roi,
      paybackMonths: implementationPaybackMonths,
      aiAccuracy: input.aiAccuracyRate,
    );

    return RoiResult(
      monthlySavingsHours: monthlySavingsHours,
      monthlySavingsCost: monthlySavingsCost,
      monthlyNetSavingsCost: monthlyNetSavings,
      yearlySavingsCost: yearlySavingsCost,
      implementationPaybackMonths: implementationPaybackMonths,
      productivityGainPercent: productivityGainPercent,
      roi: roi,
      aiEffectiveness: aiEffectiveness,
      recommendation: recommendation,
    );
  }

  @override
  Future<ExecutiveKpiDashboard> getExecutiveDashboard() async {
    // 더미 데이터 반환 (실제로는 DB에서 조회)
    return ExecutiveKpiDashboard(
      totalVocs: 2345,
      openVocs: 67,
      inProgressVocs: 143,
      resolvedVocs: 2135,
      resolutionRate: 0.911,
      avgProcessingTimeHours: 4.2,
      aiUtilizationRate: 0.985,
      autoResponseRate: 0.642,
      duplicateReductionRate: 0.78,
      departmentLoadMap: {
        '기술지원': 450,
        '개발': 320,
        '운영': 280,
        '영업': 210,
        '기타': 1085,
      },
      monthlyTrend: [185, 192, 178, 203, 215, 198, 225, 212, 198, 210, 234, 245],
      employeeProductivity: 58.625,
      roiResult: DefaultRoiCalculator().calculateRoi(
        RoiCalculatorInput(
          monthlyVocVolume: 234,
          avgHandleTimeHours: 4.2,
          hourlyLaborCost: 35.0,
          aiImplementationCost: 50000.0,
          monthlyAiMaintenanceCost: 2500.0,
          automationRate: 0.65,
          aiAccuracyRate: 0.92,
        ),
      ),
      aiAccuracyRecommendations: [
        '✅ AI 정확도가 92%로 우수합니다.',
        '💡 카테고리 분류를 95% 이상으로 높이는 것을 목표로 추가 학습 데이터 확보 권장',
        '🎯 담당자 추천 정확도를 개선하면 처리 시간을 1시간 이상 단축 가능',
      ],
    );
  }

  String _generateRecommendation({
    required double roi,
    required double paybackMonths,
    required double aiAccuracy,
  }) {
    if (roi < 0) {
      return '⚠️ ROI가 음수입니다. AI 자동화율을 높이거나 운영 비용을 절감할 방안 검토 필요';
    }

    if (paybackMonths > 24) {
      return '📈 회수 기간이 2년을 초과합니다. 자동화 범위 확대 또는 추가 VOC 채널 개설 고려';
    }

    if (paybackMonths <= 12 && roi > 100) {
      return '🎉 우수한 투자 수익률입니다! 현재 설정을 유지하고 다른 부서로 확대 배포 추천';
    }

    if (aiAccuracy < 0.85) {
      return '🤖 AI 정확도를 85% 이상으로 높이면 ROI를 25% 개선할 수 있습니다.';
    }

    return '✅ 안정적인 운영 상태입니다. 정기적인 AI 모델 업데이트를 통해 성능 개선 권장';
  }
}
