import 'package:flutter/material.dart';

import '../../core/utils/voc_category_catalog.dart';
import '../../domain/entities/voc_entity.dart';

String analysisUrgencyLabel(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '분석 전';
  }
  return switch (value.toLowerCase()) {
    'critical' => '매우 긴급',
    'high' => '높음',
    'medium' || 'normal' => '보통',
    'low' => '낮음',
    _ => value,
  };
}

/// Explanations describe stored analysis scores, not calibrated probabilities.
class VocAnalysisMetrics extends StatelessWidget {
  const VocAnalysisMetrics({super.key, required this.voc});
  final VocEntity voc;

  static const scoreHelp = '판단 점수는 분석 결과에 함께 저장된 참고 수치입니다. '
      '실제 정답 확률이나 검증된 정확도가 아니며, 100%여도 담당자의 확인이 필요합니다. '
      '점수가 없으면 아직 분석하지 않았거나 점수가 저장되지 않은 상태입니다.';

  @override
  Widget build(BuildContext context) {
    final metrics = <_Metric>[
      _Metric('business', '업무 관련성',
          voc.businessScore == null ? '분석 전' : (voc.isBusinessRelated ? '관련' : '비관련'),
          voc.businessScore,
          '문의 내용이 회사의 업무 또는 지원 대상 서비스와 관련되는지 분석한 결과입니다. '
          '관련은 업무 문의로 보았다는 뜻입니다. 현재 앱은 비관련 분석 결과를 적용하면 문의 상태를 반려로 변경하므로 결과를 확인해 주세요.'),
      _Metric('category', '추천 문의 유형',
          voc.aiCategory == null ? '분석 전' : VocCategoryCatalog.displayName(voc.aiCategory),
          voc.categoryScore,
          '문의 내용을 사용법·장애·개선 요청 등의 유형으로 분류한 추천 결과입니다. '
          '실제로 등록된 문의 유형과 다를 수 있으므로 내용을 확인한 뒤 적용해 주세요.'),
      _Metric('urgency', '긴급도', analysisUrgencyLabel(voc.urgency), voc.urgencyScore,
          '문의 내용에서 업무 영향과 신속한 대응 필요성을 추정한 등급입니다. '
          '매우 긴급 → 높음 → 보통 → 낮음 순서이며, 처리 기한이나 완료 시각을 뜻하지 않습니다. '
          '실제 업무 영향과 회사 대응 기준을 함께 확인해 주세요.'),
      _Metric('department', '검토 부서', voc.department ?? '분석 전', voc.departmentScore,
          '문의 내용을 검토할 곳으로 분석에서 제안한 부서입니다. '
          '제안된 부서명은 분석 결과를 저장할 때 문의 정보에 반영됩니다. 실제 조직도와 담당 업무에 맞는지는 운영 담당자가 확인해 주세요.'),
      _Metric('duplicate', '중복 판단 점수',
          voc.duplicateScore == null ? '분석 전' : '${(voc.duplicateScore! * 100).toStringAsFixed(0)}%',
          null,
          '기존 문의 후보와 비교해 같은 사안일 가능성을 판단한 참고 점수입니다. '
          '높을수록 중복으로 판단한 것이지만, 실제 중복 확률이나 문장 일치율은 아닙니다. '
          '100%여도 두 문의의 고객·발생 상황·내용을 직접 비교해야 하며 자동으로 합쳐지지 않습니다.',
          duplicate: true),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = ((constraints.maxWidth + 10) / (260 * scale.clamp(1.0, 1.6)))
          .floor().clamp(1, 3);
      final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final metric in metrics)
          SizedBox(width: width, child: _MetricTile(metric: metric)),
      ]);
    });
  }
}

class _Metric {
  const _Metric(this.id, this.label, this.value, this.score, this.help,
      {this.duplicate = false});
  final String id;
  final String label;
  final String value;
  final double? score;
  final String help;
  final bool duplicate;
  String get explanation => duplicate ? help : '$help\n\n${VocAnalysisMetrics.scoreHelp}';
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});
  final _Metric metric;

  void _showHelp(BuildContext context) {
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text('${metric.label} 안내'),
      scrollable: true,
      content: Text(metric.explanation, style: const TextStyle(height: 1.6)),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('analysis-metric-${metric.id}'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(13), border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metric.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant))),
          Tooltip(
            message: metric.explanation,
            waitDuration: const Duration(milliseconds: 350),
            child: IconButton(
              key: ValueKey('analysis-help-${metric.id}'),
              onPressed: () => _showHelp(context),
              icon: Icon(Icons.info_outline, size: 20, semanticLabel: '${metric.label} 설명 보기'),
              color: cs.onSurfaceVariant,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ]),
        Text(metric.value, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(metric.duplicate
            ? (metric.value == '분석 전' ? '아직 분석하지 않음' : '기존 문의와 비교한 참고 점수')
            : metric.score == null ? '판단 점수 없음'
            : '판단 점수 ${(metric.score! * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
