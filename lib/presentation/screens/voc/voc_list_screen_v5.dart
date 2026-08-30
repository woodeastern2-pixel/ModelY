import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../data/services/bulk_ai_resolve_service.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';
import '../../widgets/priority_chip.dart';
import '../../widgets/voc_status_chip.dart';
import '../../widgets/workspace_ui.dart';
import 'voc_detail_screen.dart';
import 'voc_register_screen.dart';

class VocListScreen extends StatefulWidget {
  const VocListScreen({
    super.key,
    this.initialStatus = '',
    this.initialCategory = '',
  });

  final String initialStatus;
  final String initialCategory;

  @override
  State<VocListScreen> createState() => _VocListScreenState();
}

class _VocListScreenState extends State<VocListScreen> {
  String _sort = 'latest';
  bool _ascending = false;
  int _pageSize = 25;
  int _page = 1;
  bool _mobileFilters = false;
  bool _bulkRunning = false;
  bool _stopRequested = false;
  BulkAiProgress? _progress;
  String _bulkMessage = '';
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<VocViewModel>();
      if (widget.initialStatus.isNotEmpty) {
        vm.setFilterStatus(widget.initialStatus);
      }
      if (widget.initialCategory.isNotEmpty) {
        vm.setFilterCategory(widget.initialCategory);
      }
      vm.loadVocs();
    });
  }

  Future<void> _register() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VocRegisterScreen()),
    );
    if (!mounted) return;
    await context.read<VocViewModel>().loadVocs();
    unawaited(context.read<DashboardViewModel>().loadDashboard());
  }

  Future<void> _bulk() async {
    if (_bulkRunning) return;
    final count = context.read<VocViewModel>().pendingVocCount;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미처리 VOC가 없습니다.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('미처리 VOC AI 일괄 처리'),
        content: Text(
          '미처리 VOC $count건을 처리합니다.\n\n'
          '속도 향상을 위해 로컬 AI는 최대 2건, 외부 AI는 최대 3건을 동시에 처리합니다. '
          '각 답변이 저장된 뒤에만 해당 VOC를 해결 상태로 변경합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('실행'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _bulkRunning = true;
      _stopRequested = false;
      _progress = null;
      _bulkMessage = 'AI 일괄 처리 준비 중';
      _lastError = null;
    });

    final settings = context.read<SettingsViewModel>();
    final result = await BulkAiResolveService(settings).run(
      shouldStop: () => _stopRequested,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          if (progress.lastError != null) {
            _lastError = progress.lastError;
          }
          _bulkMessage = '${progress.completed} / ${progress.total} 처리 완료 · '
              '성공 ${progress.success} · 실패 ${progress.failed}';
        });
      },
    );
    if (!mounted) return;

    await context.read<VocViewModel>().loadVocs();
    unawaited(context.read<DashboardViewModel>().loadDashboard());

    if (settings.vocAutoForwardEnabled &&
        settings.vocForwardWebhookTargets.isNotEmpty) {
      unawaited(
        context
            .read<IntegrationViewModel>()
            .forwardFullVocAndManualToPeerApps(),
      );
    }

    setState(() {
      _bulkRunning = false;
      _bulkMessage = result.stopped
          ? 'AI 일괄 처리 중지 · 성공 ${result.success} · 실패 ${result.failed}'
          : 'AI 일괄 처리 완료 · 성공 ${result.success} · 실패 ${result.failed} · '
              '기존 답변 재사용 ${result.reused}';
      _lastError = result.lastError;
    });
  }

  void _stop() {
    if (!_bulkRunning) return;
    setState(() {
      _stopRequested = true;
      _bulkMessage = '중지 요청됨 · 진행 중인 요청만 마무리합니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final desktop = box.maxWidth >= 1050;
        final compact = box.maxWidth < AppBreakpoints.mobile;
        return Scaffold(
          backgroundColor: context.visualColors.canvas,
          appBar: AppBar(
            title: const Text('VOC 작업함'),
            actions: [
              IconButton(
                tooltip: _bulkRunning ? 'AI 일괄 처리 중지' : '미처리 VOC AI 일괄 처리',
                onPressed: _bulkRunning ? _stop : _bulk,
                icon: Icon(
                  _bulkRunning
                      ? Icons.stop_circle_outlined
                      : Icons.auto_awesome_outlined,
                  color:
                      _bulkRunning ? Theme.of(context).colorScheme.error : null,
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: () => context.read<VocViewModel>().loadVocs(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: compact
              ? FloatingActionButton.extended(
                  key: const Key('voc-register-fab'),
                  onPressed: _register,
                  icon: const Icon(Icons.add),
                  label: const Text('VOC 등록'),
                )
              : null,
          bottomNavigationBar: _statusBar(),
          body: Consumer<VocViewModel>(
            builder: (context, vm, _) {
              final sorted = _sortVocs(vm.vocs);
              final pages = _pageSize == -1
                  ? 1
                  : (sorted.length / _pageSize).ceil().clamp(1, 999999).toInt();
              final current = _page < 1 ? 1 : (_page > pages ? pages : _page);
              final visible = _pageSize == -1
                  ? sorted
                  : sorted
                      .skip((current - 1) * _pageSize)
                      .take(_pageSize)
                      .toList();

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1540),
                  child: RefreshIndicator(
                    onRefresh: vm.loadVocs,
                    child: CustomScrollView(
                      key: const Key('voc-queue-scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? AppSpacing.sm : AppSpacing.lg,
                            compact ? AppSpacing.sm : AppSpacing.lg,
                            compact ? AppSpacing.sm : AppSpacing.lg,
                            0,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _QueueHero(
                              vocs: vm.allVocs,
                              compact: compact,
                              bulkRunning: _bulkRunning,
                              onRegister: _register,
                              onBulk: _bulkRunning ? _stop : _bulk,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? AppSpacing.sm : AppSpacing.lg,
                            AppSpacing.md,
                            compact ? AppSpacing.sm : AppSpacing.lg,
                            AppSpacing.sm,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _Filters(
                              desktop: desktop,
                              vm: vm,
                              sort: _sort,
                              ascending: _ascending,
                              pageSize: _pageSize,
                              current: current,
                              pages: pages,
                              total: sorted.length,
                              mobileExpanded: _mobileFilters,
                              onToggleMobile: () => setState(
                                () => _mobileFilters = !_mobileFilters,
                              ),
                              onSort: (value) => setState(() {
                                _sort = value;
                                _page = 1;
                              }),
                              onDirection: () => setState(
                                () => _ascending = !_ascending,
                              ),
                              onPageSize: (value) => setState(() {
                                _pageSize = value;
                                _page = 1;
                              }),
                              onPrev: current > 1
                                  ? () => setState(() => _page = current - 1)
                                  : null,
                              onNext: current < pages
                                  ? () => setState(() => _page = current + 1)
                                  : null,
                            ),
                          ),
                        ),
                        if (vm.isLoading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (visible.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _Empty(onRegister: _register),
                          )
                        else if (desktop)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.xxl,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _QueueTable(vocs: visible),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? AppSpacing.sm : AppSpacing.lg,
                              0,
                              compact ? AppSpacing.sm : AppSpacing.lg,
                              compact ? 100 : AppSpacing.xxl,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == visible.length - 1
                                        ? 0
                                        : AppSpacing.xs,
                                  ),
                                  child: _QueueCard(voc: visible[index]),
                                ),
                                childCount: visible.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget? _statusBar() {
    if (!_bulkRunning && _bulkMessage.isEmpty) return null;
    final progress = _progress;
    final value = progress == null || progress.total == 0
        ? null
        : progress.completed / progress.total;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: colors.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_bulkRunning) LinearProgressIndicator(value: value),
              if (_bulkRunning) const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _bulkRunning
                        ? Icons.auto_awesome
                        : Icons.check_circle_outline,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bulkMessage,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (progress?.currentTitle != null)
                          Text(
                            '최근 처리: ${progress!.currentTitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (_lastError != null)
                          Text(
                            '최근 오류: $_lastError',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.error),
                          ),
                      ],
                    ),
                  ),
                  if (_bulkRunning)
                    TextButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('중지'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<VocEntity> _sortVocs(List<VocEntity> input) {
    final list = [...input];
    int priority(String value) => switch (value) {
          'HIGH' => 0,
          'MEDIUM' => 1,
          'LOW' => 2,
          _ => 3,
        };
    int compare(VocEntity a, VocEntity b) => switch (_sort) {
          'updated' => a.updatedAt.compareTo(b.updatedAt),
          'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          'customer' =>
            a.customer.toLowerCase().compareTo(b.customer.toLowerCase()),
          'priority' => priority(a.priority).compareTo(priority(b.priority)),
          'status' => a.status.compareTo(b.status),
          _ => a.createdAt.compareTo(b.createdAt),
        };
    list.sort(compare);
    return _ascending ? list : list.reversed.toList();
  }
}

class _QueueHero extends StatelessWidget {
  const _QueueHero({
    required this.vocs,
    required this.compact,
    required this.bulkRunning,
    required this.onRegister,
    required this.onBulk,
  });

  final List<VocEntity> vocs;
  final bool compact;
  final bool bulkRunning;
  final VoidCallback onRegister;
  final VoidCallback onBulk;

  @override
  Widget build(BuildContext context) {
    final pending = vocs.where(_isPending).length;
    final urgent =
        vocs.where((voc) => _isPending(voc) && voc.priority == 'HIGH').length;
    final resolved = vocs
        .where((voc) => voc.status == AppConstants.vocStatusResolved)
        .length;
    final resolvedRate = vocs.isEmpty ? 0 : resolved / vocs.length * 100;

    return WorkspaceHero(
      key: const Key('voc-queue-hero'),
      eyebrow: 'VOC QUEUE',
      title: pending == 0 ? '처리 대기열이 비었습니다.' : '지금 처리할 VOC $pending건',
      description: urgent > 0
          ? '고위험 $urgent건을 먼저 확인하고, AI 초안과 담당 정보를 연결하세요.'
          : '검색과 상태 필터로 고객 신호를 좁히고 다음 업무를 바로 실행하세요.',
      icon: Icons.inbox_rounded,
      metrics: [
        WorkspaceMetric(label: '전체', value: '${vocs.length}'),
        WorkspaceMetric(
          label: '미처리',
          value: '$pending',
          color: pending > 0 ? const Color(0xFFF2B45F) : null,
        ),
        WorkspaceMetric(
          label: '해결률',
          value: '${resolvedRate.toStringAsFixed(0)}%',
          color: const Color(0xFF55CDBE),
        ),
      ],
      actions: compact
          ? const []
          : [
              FilledButton.icon(
                key: const Key('voc-register-primary'),
                onPressed: onRegister,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppPalette.ink,
                ),
                icon: const Icon(Icons.add),
                label: const Text('새 VOC 등록'),
              ),
              OutlinedButton.icon(
                onPressed: onBulk,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.32),
                  ),
                ),
                icon: Icon(
                  bulkRunning
                      ? Icons.stop_circle_outlined
                      : Icons.auto_awesome_outlined,
                ),
                label: Text(bulkRunning ? 'AI 처리 중지' : 'AI 일괄 처리'),
              ),
            ],
    );
  }

  bool _isPending(VocEntity voc) =>
      voc.status == AppConstants.vocStatusOpen ||
      voc.status == AppConstants.vocStatusInProgress;
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.desktop,
    required this.vm,
    required this.sort,
    required this.ascending,
    required this.pageSize,
    required this.current,
    required this.pages,
    required this.total,
    required this.mobileExpanded,
    required this.onToggleMobile,
    required this.onSort,
    required this.onDirection,
    required this.onPageSize,
    required this.onPrev,
    required this.onNext,
  });

  final bool desktop;
  final VocViewModel vm;
  final String sort;
  final bool ascending;
  final int pageSize;
  final int current;
  final int pages;
  final int total;
  final bool mobileExpanded;
  final VoidCallback onToggleMobile;
  final ValueChanged<String> onSort;
  final VoidCallback onDirection;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<SettingsViewModel>().allCategories;
    final category =
        categories.contains(vm.filterCategory) ? vm.filterCategory : '';
    return WorkspacePanel(
      key: const Key('voc-queue-filters'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(flex: 4, child: _Search(vm: vm)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  flex: 2,
                  child: _Category(
                    value: category,
                    categories: categories,
                    onChanged: vm.setFilterCategory,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 150,
                  child: _Sort(value: sort, onChanged: onSort),
                ),
                IconButton(
                  onPressed: onDirection,
                  tooltip: ascending ? '오름차순' : '내림차순',
                  icon: Icon(
                    ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _Search(vm: vm)),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  onPressed: onToggleMobile,
                  tooltip: '상세 필터',
                  icon: Icon(
                    mobileExpanded ? Icons.expand_less : Icons.tune,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _Status('전체', '', vm),
                    _Status('미처리', AppConstants.vocStatusOpen, vm),
                    _Status(
                      '처리중',
                      AppConstants.vocStatusInProgress,
                      vm,
                    ),
                    _Status('해결', AppConstants.vocStatusResolved, vm),
                    _Status('반려', AppConstants.vocStatusRejected, vm),
                  ],
                ),
              ),
            ],
          ),
          if (!desktop && mobileExpanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: _Sort(value: sort, onChanged: onSort)),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  onPressed: onDirection,
                  icon: Icon(
                    ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _Category(
              value: category,
              categories: categories,
              onChanged: vm.setFilterCategory,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '검색 결과 $total건 · $current / $pages',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              SizedBox(
                width: 104,
                child: DropdownButtonFormField<int>(
                  initialValue: pageSize,
                  decoration: const InputDecoration(labelText: '표시'),
                  items: const [
                    DropdownMenuItem(value: 25, child: Text('25건')),
                    DropdownMenuItem(value: 50, child: Text('50건')),
                    DropdownMenuItem(value: 100, child: Text('100건')),
                    DropdownMenuItem(value: -1, child: Text('전체')),
                  ],
                  onChanged: (value) {
                    if (value != null) onPageSize(value);
                  },
                ),
              ),
              IconButton(
                onPressed: onPrev,
                tooltip: '이전 페이지',
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: onNext,
                tooltip: '다음 페이지',
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.vm});

  final VocViewModel vm;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '제목, 내용, 고객, 프로젝트 검색',
      ),
      onChanged: vm.setSearch,
    );
  }
}

class _Sort extends StatelessWidget {
  const _Sort({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: '정렬'),
      items: const [
        DropdownMenuItem(value: 'latest', child: Text('등록일')),
        DropdownMenuItem(value: 'updated', child: Text('수정일')),
        DropdownMenuItem(value: 'title', child: Text('제목')),
        DropdownMenuItem(value: 'customer', child: Text('고객')),
        DropdownMenuItem(value: 'priority', child: Text('우선순위')),
        DropdownMenuItem(value: 'status', child: Text('상태')),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

class _Category extends StatelessWidget {
  const _Category({
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  final String value;
  final List<String> categories;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: '카테고리'),
      items: [
        const DropdownMenuItem(value: '', child: Text('전체 카테고리')),
        ...categories.map(
          (category) => DropdownMenuItem(
            value: category,
            child: Text(category),
          ),
        ),
      ],
      onChanged: (next) => onChanged(next ?? ''),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.label, this.value, this.vm);

  final String label;
  final String value;
  final VocViewModel vm;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: vm.filterStatus == value,
      onSelected: (_) => vm.setFilterStatus(value),
    );
  }
}

class _QueueTable extends StatelessWidget {
  const _QueueTable({required this.vocs});

  final List<VocEntity> vocs;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return WorkspacePanel(
      key: const Key('voc-queue-table'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            color: context.visualColors.mutedSurface,
            child: const _QueueColumns(
              title: 'VOC / 고객 신호',
              customer: '고객',
              category: '카테고리',
              priority: '우선순위',
              status: '상태',
              date: '업데이트',
              header: true,
            ),
          ),
          for (var index = 0; index < vocs.length; index++) ...[
            _QueueRow(voc: vocs[index]),
            if (index != vocs.length - 1) Divider(color: colors.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.voc});

  final VocEntity voc;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(context, voc),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: _QueueColumns(
            titleWidget: Row(
              children: [
                Container(
                  width: 3,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _priorityColor(voc.priority, context),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        voc.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            customerWidget: Text(
              voc.customer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            categoryWidget: Text(
              voc.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            priorityWidget: PriorityChip(priority: voc.priority),
            statusWidget: VocStatusChip(status: voc.status),
            dateWidget: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _date(voc.updatedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.arrow_outward,
                  size: 16,
                  color: colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueColumns extends StatelessWidget {
  const _QueueColumns({
    this.title,
    this.customer,
    this.category,
    this.priority,
    this.status,
    this.date,
    this.titleWidget,
    this.customerWidget,
    this.categoryWidget,
    this.priorityWidget,
    this.statusWidget,
    this.dateWidget,
    this.header = false,
  });

  final String? title;
  final String? customer;
  final String? category;
  final String? priority;
  final String? status;
  final String? date;
  final Widget? titleWidget;
  final Widget? customerWidget;
  final Widget? categoryWidget;
  final Widget? priorityWidget;
  final Widget? statusWidget;
  final Widget? dateWidget;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: header ? 0.25 : null,
        );
    Widget cell(String? text, Widget? widget) =>
        widget ?? Text(text ?? '', style: style);
    return Row(
      children: [
        Expanded(flex: 5, child: cell(title, titleWidget)),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: 2, child: cell(customer, customerWidget)),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: 2, child: cell(category, categoryWidget)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: cell(priority, priorityWidget)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: cell(status, statusWidget)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: cell(date, dateWidget)),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.voc});

  final VocEntity voc;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: Key('voc-queue-card-${voc.id}'),
      decoration: BoxDecoration(
        color: context.visualColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context, voc),
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 74,
                  decoration: BoxDecoration(
                    color: _priorityColor(voc.priority, context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${voc.customer} · ${voc.category}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                          Text(
                            _date(voc.updatedAt),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        voc.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PriorityChip(priority: voc.priority),
                          VocStatusChip(status: voc.status),
                          if (voc.aiCategory?.isNotEmpty == true)
                            Text(
                              'AI · ${voc.aiCategory}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.primary),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right, color: colors.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '조건에 맞는 VOC가 없습니다.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '필터를 바꾸거나 새 고객 신호를 등록해 보세요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.add),
              label: const Text('VOC 등록'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _priorityColor(String priority, BuildContext context) =>
    switch (priority) {
      'HIGH' => Theme.of(context).colorScheme.error,
      'LOW' => context.visualColors.success,
      _ => context.visualColors.warning,
    };

String _date(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

void _open(BuildContext context, VocEntity voc) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => VocDetailScreen(vocId: voc.id)),
  );
}
