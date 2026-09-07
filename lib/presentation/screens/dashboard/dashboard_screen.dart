import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/voc_category_catalog.dart';
import '../../../data/services/demo_mode_service.dart';
import '../../../data/services/sample_voc_generator.dart';
import '../../../domain/services/executive_dashboard_service.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';
import '../voc/voc_register_screen.dart';
import '../voc/voc_list_screen.dart';
import '../knowledge_base/knowledge_base_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showCategorySection = false;
  int _categoryPage = 0;

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VocRegisterScreen()),
    );
    if (!mounted) return;
    context.read<DashboardViewModel>().loadDashboard();
    context.read<VocViewModel>().loadVocs();
  }

  Future<void> _openVocList({String initialStatus = ''}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VocListScreen(initialStatus: initialStatus),
      ),
    );
    if (!mounted) return;
    context.read<DashboardViewModel>().loadDashboard();
    context.read<VocViewModel>().loadVocs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOC 현황'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill_outlined),
            tooltip: '샘플 VOC로 둘러보기',
            onPressed: () => _showDemoModeDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () => context.read<DashboardViewModel>().loadDashboard(),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Consumer<DashboardViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.totalVocs == 0 && vm.vocByStatus.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: vm.loadDashboard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 600;
                      final pagePadding =
                          compact ? AppSpacing.sm : AppSpacing.lg;
                      return Padding(
                        padding: EdgeInsets.all(pagePadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (vm.error != null) ...[
                              _DashboardErrorBanner(onRetry: vm.loadDashboard),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            _DashboardHero(
                              vm: vm,
                              onRegister: _openRegister,
                              onOpenVocs: () => _openVocList(),
                            ),
                            if (vm.isLoading) ...[
                              const SizedBox(height: AppSpacing.xs),
                              const LinearProgressIndicator(minHeight: 2),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            _CoreKpiCards(vm: vm),
                            const SizedBox(height: AppSpacing.xl),
                            const _SectionHeading(
                              eyebrow: '오늘의 요약',
                              title: '오늘 확인할 VOC',
                              description: '오늘 확인해야 할 VOC와 AI 활용 현황입니다.',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _ExecutiveInsightsPanel(vm: vm),
                            const SizedBox(height: AppSpacing.xl),
                            const _SectionHeading(
                              eyebrow: '처리 현황',
                              title: 'VOC 처리 흐름',
                              description: '접수부터 완료까지의 처리 흐름을 확인하세요.',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _OperationalMetricCards(vm: vm),
                            const SizedBox(height: AppSpacing.xl),
                            _CategorySection(
                              data: vm.vocByCategory,
                              expanded: _showCategorySection,
                              page: _categoryPage,
                              onToggle: () {
                                setState(() {
                                  _showCategorySection = !_showCategorySection;
                                  if (!_showCategorySection) {
                                    _categoryPage = 0;
                                  }
                                });
                              },
                              onPageChanged: (page) {
                                setState(() => _categoryPage = page);
                              },
                            ),
                            if (vm.monthlyStats.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xl),
                              const _SectionHeading(
                                eyebrow: 'TREND',
                                title: '월별 VOC 추이',
                                description: '월별 접수 건수와 처리 완료 건수를 비교합니다.',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: _MonthlyChart(stats: vm.monthlyStats),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            const _SectionHeading(
                              eyebrow: 'TEAM',
                              title: '담당자별 처리 현황',
                              description: '담당자별 배정 건수와 처리 결과를 확인합니다.',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: vm.assigneeStats.isNotEmpty
                                    ? _AssigneeChart(stats: vm.assigneeStats)
                                    : Text(
                                        '담당자가 배정된 VOC가 없습니다. VOC를 배정하면 처리 현황이 표시됩니다.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDemoModeDialog(BuildContext context) async {
    final service = DefaultDemoModeService();
    final logs = <String>[];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
                title: const Text('3분 기능 둘러보기'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '샘플 VOC가 현재 데이터에 추가됩니다. 기존 VOC와 설정은 변경되지 않습니다.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value:
                          (service.getCurrentStatus()?.progressPercent ?? 0) /
                              100,
                    ),
                    const SizedBox(height: 12),
                    Text(service.getCurrentStatus()?.message ?? '기능 둘러보기를 준비하고 있습니다.'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (_, i) => Text(
                          logs[i],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await service.stopDemo();
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('닫기'),
                ),
                FilledButton.icon(
                  onPressed: service.isRunning()
                      ? null
                      : () async {
                          // 샘플 데이터 임포트
                          final samples =
                              SampleVocGenerator.generateSampleVocs();
                          final count = await context
                              .read<VocViewModel>()
                              .importSampleVocs(samples);
                          logs.add('샘플 VOC $count건을 추가했습니다.');

                          await service.startDemo((status) {
                            logs
                              ..clear()
                              ..addAll(status.logs);
                            if (ctx.mounted) setState(() {});
                          });
                          if (ctx.mounted) {
                            context.read<DashboardViewModel>().loadDashboard();
                            context.read<VocViewModel>().loadVocs();
                          }
                        },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('둘러보기 시작'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.vm,
    required this.onRegister,
    required this.onOpenVocs,
  });

  final DashboardViewModel vm;
  final Future<void> Function() onRegister;
  final Future<void> Function() onOpenVocs;

  @override
  Widget build(BuildContext context) {
    final needsAttention =
        vm.totalVocs > 0 && (vm.backlogRate >= 0.35 || vm.resolutionRate < 0.6);
    final String title;
    final String description;
    final Color signal;

    if (vm.totalVocs == 0) {
      title = '첫 VOC를 등록해 보세요.';
      description = 'VOC를 등록하면 AI가 유형과 우선순위를 분석하고 답변 작성을 도와드립니다.';
      signal = const Color(0xFF9FA1FF);
    } else if (needsAttention) {
      title = '처리되지 않은 VOC를 먼저 확인해 주세요.';
      description = '접수·처리 중인 VOC ${vm.backlogVocs}건을 우선순위에 따라 배정해 주세요.';
      signal = const Color(0xFFF2B45F);
    } else {
      title = 'VOC가 원활하게 처리되고 있습니다.';
      description = '현재 처리 완료율을 유지하면서 AI 답변 승인률을 높여보세요.';
      signal = const Color(0xFF57D1C0);
    }

    return Container(
      key: const Key('dashboard-hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF202536)
            : const Color(0xFF171A2B),
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: signal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: signal.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '오늘의 현황',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFB9BED0),
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: (compact
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.displaySmall)
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: const Color(0xFFC7CBD8), height: 1.55),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  FilledButton.icon(
                    key: const Key('dashboard-register'),
                    onPressed: () => onRegister(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppPalette.ink,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('VOC 등록'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('dashboard-open-vocs'),
                    onPressed: () => onOpenVocs(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('전체 목록 보기'),
                  ),
                ],
              ),
            ],
          );

          final pulse = _HeroPulse(vm: vm, signal: signal);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                copy,
                const SizedBox(height: AppSpacing.lg),
                pulse,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy),
              const SizedBox(width: AppSpacing.xl),
              SizedBox(width: 286, child: pulse),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPulse extends StatelessWidget {
  const _HeroPulse({required this.vm, required this.signal});

  final DashboardViewModel vm;
  final Color signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '미완료 VOC',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: const Color(0xFFB9BED0)),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                vm.backlogVocs.toString(),
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: Colors.white, height: 1),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '건',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: const Color(0xFFB9BED0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _HeroProgress(
            label: '처리 완료율',
            value: vm.resolutionRate.clamp(0.0, 1.0).toDouble(),
            display: '${(vm.resolutionRate * 100).toStringAsFixed(0)}%',
            color: signal,
          ),
          const SizedBox(height: AppSpacing.md),
          _HeroProgress(
            label: 'AI 답변 사용률',
            value: vm.aiUsageRate.clamp(0.0, 1.0).toDouble(),
            display: '${(vm.aiUsageRate * 100).toStringAsFixed(0)}%',
            color: const Color(0xFF9FA1FF),
          ),
        ],
      ),
    );
  }
}

class _HeroProgress extends StatelessWidget {
  const _HeroProgress({
    required this.label,
    required this.value,
    required this.display,
    required this.color,
  });

  final String label;
  final double value;
  final String display;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: const Color(0xFFB9BED0)),
              ),
            ),
            Text(
              display,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 5,
            color: color,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.15,
              ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(
          description,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DashboardErrorBanner extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _DashboardErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '일부 VOC 현황을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _ExecutiveInsightsPanel extends StatelessWidget {
  final DashboardViewModel vm;
  const _ExecutiveInsightsPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final roi = vm.roiResult;
    final roiInput = vm.roiInputSnapshot;
    final won = NumberFormat.currency(
      locale: 'ko_KR',
      symbol: '₩',
      decimalDigits: 0,
    );
    final trendPct = vm.monthlyVocTrendPercent * 100;
    final aiUpdatedAt = vm.executiveAiUpdatedAt;
    final aiRecommendations = vm.executiveAiRecommendations;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI 분석 요약',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '저장된 VOC를 기준으로 계산했으며 AI 분석값은 참고용입니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricChip(
                  context,
                  'AI 분석 정확도',
                  '${(vm.aiOverallAccuracy * 100).toStringAsFixed(1)}%',
                  Icons.verified_outlined,
                  Colors.teal,
                ),
                _metricChip(
                  context,
                  'AI 답변 승인률',
                  '${(vm.aiAnswerAdoptionRate * 100).toStringAsFixed(1)}%',
                  Icons.thumb_up_alt_outlined,
                  Colors.indigo,
                ),
                _metricChip(
                  context,
                  '복수 답변 등록 비율',
                  '${(vm.reopenRate * 100).toStringAsFixed(1)}%',
                  Icons.replay_circle_filled_outlined,
                  Colors.deepOrange,
                  subtitle:
                      '${vm.reopenedCount}건 / 처리 완료 ${vm.resolvedForReopenRate}건',
                ),
                _metricChip(
                  context,
                  '최근 늘어난 키워드',
                  vm.risingKeyword,
                  Icons.local_fire_department_outlined,
                  Colors.redAccent,
                  subtitle: vm.risingKeywordDelta > 0
                      ? '최근 30일 +${vm.risingKeywordDelta}'
                      : '최근 30일 동안 뚜렷하게 늘어난 키워드가 없습니다.',
                ),
                _metricChip(
                  context,
                  '우선 확인 고객군',
                  vm.topSegmentName == '-' ? '-' : vm.topSegmentName,
                  Icons.groups_2_outlined,
                  Colors.pink,
                  subtitle: vm.topSegmentName == '-'
                      ? '데이터 부족'
                      : 'VOC ${vm.topSegmentVolume}건 · 우선 확인 점수 ${vm.topSegmentScore.toStringAsFixed(1)}점',
                ),
                _metricChip(
                  context,
                  '월 예상 순절감액',
                  roi == null ? '-' : won.format(roi.monthlyNetSavingsCost),
                  Icons.savings_outlined,
                  Colors.green,
                  subtitle: roi == null
                      ? null
                      : '총 절감액 ${won.format(roi.monthlySavingsCost)} - 운영비 ${won.format(roiInput?.monthlyAiMaintenanceCost ?? 0)}',
                ),
                _metricChip(
                  context,
                  'ROI',
                  roi == null ? '-' : '${roi.roi.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.deepPurple,
                ),
                _metricChip(
                  context,
                  '투자비 회수 예상 기간',
                  roi == null || !roi.implementationPaybackMonths.isFinite
                      ? '-'
                      : '${roi.implementationPaybackMonths.toStringAsFixed(1)}개월',
                  Icons.schedule,
                  Colors.brown,
                ),
                _metricChip(
                  context,
                  '미완료 VOC 비율',
                  '${(vm.backlogRate * 100).toStringAsFixed(1)}%',
                  Icons.warning_amber_outlined,
                  Colors.orange,
                  subtitle: '${vm.backlogVocs}건 (접수+처리 중)',
                ),
                _metricChip(
                  context,
                  '전월 VOC 증감',
                  '${trendPct >= 0 ? '+' : ''}${trendPct.toStringAsFixed(1)}%',
                  trendPct >= 0 ? Icons.trending_up : Icons.trending_down,
                  trendPct >= 0 ? Colors.red : Colors.blue,
                ),
                _metricChip(
                  context,
                  'AI 활용 효과',
                  roi == null
                      ? '-'
                      : '${roi.aiEffectiveness.toStringAsFixed(1)}점',
                  Icons.auto_graph,
                  Colors.cyan,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _formulaPanel(context, roiInput, roi, won),
            const SizedBox(height: 14),
            Text(
              'ROI는 투자 대비 수익률(Return On Investment)입니다. 값이 높을수록 투자 효율이 높습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (aiRecommendations.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'AI 권장 조치',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (aiUpdatedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: Text(
                    '마지막 분석: ${DateFormat('yyyy-MM-dd HH:mm').format(aiUpdatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 6),
              ...aiRecommendations.take(4).map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '- $r',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: compact ? double.infinity : 240,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _formulaPanel(
    BuildContext context,
    RoiCalculatorInput? input,
    RoiResult? roi,
    NumberFormat won,
  ) {
    final hourlyCost = ((input?.hourlyLaborCost ?? 35.0) * 1400).round();
    final maintenanceCost =
        ((input?.monthlyAiMaintenanceCost ?? 2500) * 1400).round();
    final implementationCost =
        ((input?.aiImplementationCost ?? 50000) * 1400).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('산정 기준', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            '월 예상 총절감액 = 월 VOC 건수 × 평균 처리 시간 × 자동화율 × AI 정확도 × 시간당 인건비',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '월 예상 순절감액 = 월 예상 총절감액 - 월간 AI 운영비',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '연간 ROI = 연간 순절감액 ÷ (AI 도입비 + 연간 운영비) × 100',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            '현재 입력값: 월 VOC ${input?.monthlyVocVolume ?? '-'}건, 평균 처리 ${input?.avgHandleTimeHours.toStringAsFixed(2) ?? '-'}시간, 자동화율 ${((input?.automationRate ?? 0) * 100).toStringAsFixed(1)}%, AI 정확도 ${((input?.aiAccuracyRate ?? 0) * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '비용 가정: 시간당 인건비 약 ${won.format(hourlyCost)}, 월 유지비 약 ${won.format(maintenanceCost)}, 도입비 약 ${won.format(implementationCost)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (roi != null)
            Text(
              '예상 결과: 월 순절감액 ${won.format(roi.monthlyNetSavingsCost)}, 연간 순절감액 ${won.format(roi.yearlySavingsCost)}, ROI ${roi.roi.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _CoreKpiCards extends StatelessWidget {
  final DashboardViewModel vm;
  const _CoreKpiCards({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CardData(
        '전체 VOC',
        vm.totalVocs.toString(),
        Icons.inbox_rounded,
        AppPalette.indigo,
        '',
      ),
      _CardData(
        '접수',
        vm.openVocs.toString(),
        Icons.bolt_rounded,
        AppPalette.amber,
        'OPEN',
      ),
      _CardData(
        '처리 완료율',
        '${(vm.resolutionRate * 100).toStringAsFixed(1)}%',
        Icons.task_alt_rounded,
        AppPalette.teal,
        '',
      ),
      _CardData(
        'AI 답변 사용률',
        '${(vm.aiUsageRate * 100).toStringAsFixed(1)}%',
        Icons.auto_awesome_rounded,
        const Color(0xFF7A5AF8),
        '',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 1000 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: constraints.maxWidth < 520 ? 118 : 126,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _SummaryCard(data: cards[i], vm: vm),
        );
      },
    );
  }
}

class _OperationalMetricCards extends StatelessWidget {
  final DashboardViewModel vm;
  const _OperationalMetricCards({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CardData(
        '처리 중',
        vm.inProgressVocs.toString(),
        Icons.pending_actions,
        AppPalette.amber,
        'IN_PROGRESS',
      ),
      _CardData(
        '처리 완료',
        vm.resolvedVocs.toString(),
        Icons.check_circle_rounded,
        AppPalette.teal,
        'RESOLVED',
      ),
      _CardData(
        '지식 자료',
        vm.kbCount.toString(),
        Icons.menu_book_rounded,
        AppPalette.indigo,
        '',
      ),
      _CardData(
        '중복 감소율',
        '${(vm.duplicateReductionRate * 100).toStringAsFixed(1)}%',
        Icons.copy_all_rounded,
        const Color(0xFF0D8FA3),
        '',
      ),
      _CardData(
        '평균 처리 시간',
        '${(vm.avgProcessMinutes / 60).toStringAsFixed(1)}h',
        Icons.schedule_rounded,
        const Color(0xFF747B8E),
        '',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 1100
            ? 5
            : constraints.maxWidth >= 700
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisExtent: 118,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _SummaryCard(data: cards[i], vm: vm),
        );
      },
    );
  }
}

class _CardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String statusFilter;
  const _CardData(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.statusFilter,
  );
}

class _SummaryCard extends StatelessWidget {
  final _CardData data;
  final DashboardViewModel vm;
  const _SummaryCard({required this.data, required this.vm});

  void _navigateToFilteredList(BuildContext context) {
    if (data.label == '지식 자료') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const KnowledgeBaseScreen()),
      ).then((_) {
        vm.loadDashboard();
        context.read<VocViewModel>().loadVocs();
      });
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VocListScreen(initialStatus: data.statusFilter),
      ),
    ).then((_) {
      vm.loadDashboard();
      context.read<VocViewModel>().loadVocs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isClickable = data.statusFilter.isNotEmpty ||
        data.label == '전체 VOC' ||
        data.label == '지식 자료';

    return Card(
      key: Key('dashboard-metric-${data.label}'),
      child: InkWell(
        onTap: isClickable ? () => _navigateToFilteredList(context) : null,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: data.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                    ),
                    child: Icon(data.icon, color: data.color, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  if (isClickable)
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                ],
              ),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final Map<String, int> data;
  final bool expanded;
  final int page;
  final VoidCallback onToggle;
  final ValueChanged<int> onPageChanged;

  const _CategorySection({
    required this.data,
    required this.expanded,
    required this.page,
    required this.onToggle,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final pageSize = VocCategoryCatalog.dashboardVisibleLimit;
    final totalPages = (entries.length / pageSize).ceil();
    final safePage = totalPages == 0 ? 0 : page.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final end = totalPages == 0
        ? 0
        : (start + pageSize > entries.length
            ? entries.length
            : start + pageSize);
    final visibleEntries = totalPages == 0
        ? <MapEntry<String, int>>[]
        : entries.sublist(start, end);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'VOC 유형별 현황',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    expanded ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(expanded ? '접기' : '펼치기'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              expanded
                  ? '한 페이지에 VOC 유형을 최대 ${VocCategoryCatalog.dashboardVisibleLimit}개까지 표시합니다.'
                  : '필요할 때 펼쳐서 VOC 유형별 현황을 확인하세요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (data.isEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '분류된 VOC가 없습니다. VOC가 등록되면 유형별 현황이 표시됩니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            if (expanded) ...[
              const SizedBox(height: 12),
              _CategoryChart(data: data, visibleEntries: visibleEntries),
              if (totalPages > 1) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: safePage > 0
                          ? () => onPageChanged(safePage - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('이전'),
                    ),
                    const SizedBox(width: 8),
                    Text('${safePage + 1} / $totalPages'),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: safePage < totalPages - 1
                          ? () => onPageChanged(safePage + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('다음'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChart extends StatelessWidget {
  final Map<String, int> data;
  final List<MapEntry<String, int>> visibleEntries;

  const _CategoryChart({required this.data, required this.visibleEntries});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final colors = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.amber,
    ];

    final entries = data.entries.toList();
    final indexByKey = <String, int>{
      for (var i = 0; i < entries.length; i++) entries[i].key: i,
    };

    const minDegreeForInsideLabel = 24.0;
    final sections = entries.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      final pct = e.value / total * 100;
      final sweepDeg = e.value / total * 360;
      final showInsideLabel = sweepDeg >= minDegreeForInsideLabel;

      return PieChartSectionData(
        color: colors[i % colors.length],
        value: e.value.toDouble(),
        title: showInsideLabel ? '${pct.toStringAsFixed(0)}%' : '',
        radius: 60,
        titlePositionPercentageOffset: 0.58,
        titleStyle: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );
    }).toList();

    final chart = SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 34,
          centerSpaceColor: Theme.of(context).colorScheme.surface,
          startDegreeOffset: -90,
        ),
      ),
    );

    final legend = Wrap(
      runSpacing: 4,
      children: visibleEntries.asMap().entries.map((entry) {
        final e = entry.value;
        final i = indexByKey[e.key] ?? 0;
        final pct = e.value / total * 100;
        return Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                color: colors[i % colors.length],
              ),
              const SizedBox(width: 6),
              Text(
                '${VocCategoryCatalog.displayName(e.key)} (${e.value}, ${pct.toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useColumnLayout = constraints.maxWidth < 700;
        if (useColumnLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [chart, const SizedBox(height: 8), legend],
          );
        }

        return SizedBox(
          height: 240,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: chart),
              const SizedBox(width: 16),
              SizedBox(width: 240, child: legend),
            ],
          ),
        );
      },
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<Map<String, dynamic>> stats;
  const _MonthlyChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxY = stats.fold<double>(
      0,
      (m, s) => (s['total'] as int) > m ? (s['total'] as int).toDouble() : m,
    );

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY + 2,
          barGroups: stats.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final total = (s['total'] as int).toDouble();
            final resolved = (s['resolved'] as int).toDouble();
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: total,
                  color: colorScheme.primary.withOpacity(0.6),
                  width: 14,
                ),
                BarChartRodData(
                  toY: resolved,
                  color: colorScheme.secondary,
                  width: 14,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= stats.length) return const SizedBox();
                  final month = stats[idx]['month'] as String;
                  return Text(
                    month.substring(5),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
        ),
      ),
    );
  }
}

class _AssigneeChart extends StatelessWidget {
  final List<Map<String, dynamic>> stats;
  const _AssigneeChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxY = stats.fold<double>(
      0,
      (m, s) => ((s['handled'] as int?) ?? 0) > m
          ? ((s['handled'] as int).toDouble())
          : m,
    );

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          barGroups: stats.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: ((s['handled'] as int?) ?? 0).toDouble(),
                  color: Colors.teal,
                  width: 20,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= stats.length) return const SizedBox();
                  final name = stats[i]['assignee'] as String? ?? '-';
                  return Text(
                    name,
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
        ),
      ),
    );
  }
}
