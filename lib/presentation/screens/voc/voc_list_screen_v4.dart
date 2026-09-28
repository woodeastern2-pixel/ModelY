import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/services/bulk_ai_resolve_service.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';
import '../../widgets/priority_chip.dart';
import '../../widgets/voc_status_chip.dart';
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
  String _sortBy = 'latest';
  bool _ascending = false;
  int _pageSize = 25;
  int _page = 1;
  bool _mobileFilters = false;
  bool _bulkRunning = false;
  bool _bulkStopRequested = false;
  BulkAiProgress? _bulkProgress;
  String _bulkMessage = '';
  String? _bulkLastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<VocViewModel>();
      if (widget.initialStatus.isNotEmpty) vm.setFilterStatus(widget.initialStatus);
      if (widget.initialCategory.isNotEmpty) vm.setFilterCategory(widget.initialCategory);
      vm.loadVocs();
    });
  }

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VocRegisterScreen()),
    );
    if (!mounted) return;
    await context.read<VocViewModel>().loadVocs();
    unawaited(context.read<DashboardViewModel>().loadDashboard());
  }

  Future<void> _runBulk() async {
    if (_bulkRunning) return;
    final vocVm = context.read<VocViewModel>();
    final count = vocVm.pendingVocCount;
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
          '미처리 VOC $count건을 AI가 답변하고 해결 상태로 변경합니다.\n\n'
          '처리 속도를 높이기 위해 제한된 동시 작업을 사용합니다. '
          '중지하면 새 작업 배정은 멈추고 이미 진행 중인 요청만 마무리합니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('실행')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _bulkRunning = true;
      _bulkStopRequested = false;
      _bulkProgress = null;
      _bulkMessage = 'AI 일괄 처리를 준비하고 있습니다.';
      _bulkLastError = null;
    });

    final settings = context.read<SettingsViewModel>();
    final result = await BulkAiResolveService(settings).run(
      shouldStop: () => _bulkStopRequested,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() {
          _bulkProgress = progress;
          _bulkLastError = progress.lastError ?? _bulkLastError;
          _bulkMessage = progress.lastError == null
              ? '${progress.completed} / ${progress.total} 처리 완료'
              : '${progress.completed} / ${progress.total} 처리 · 최근 1건 실패';
        });
      },
    );

    if (!mounted) return;
    await vocVm.loadVocs();
    unawaited(context.read<DashboardViewModel>().loadDashboard());

    // 건별 네트워크 대기를 없애고 마지막에 한 번만 전체 동기화한다.
    final integration = context.read<IntegrationViewModel>();
    if (settings.vocAutoForwardEnabled && settings.vocForwardWebhookTargets.isNotEmpty) {
      unawaited(integration.forwardFullVocAndManualToPeerApps());
    }

    setState(() {
      _bulkRunning = false;
      _bulkMessage = result.stopped
          ? 'AI 일괄 처리 중지 · 성공 ${result.success}건 · 실패 ${result.failed}건'
          : 'AI 일괄 처리 완료 · 성공 ${result.success}건 · 실패 ${result.failed}건 · 기존 답변 재사용 ${result.reused}건';
      _bulkLastError = result.lastError;
    });
  }

  void _stopBulk() {
    if (!_bulkRunning) return;
    setState(() {
      _bulkStopRequested = true;
      _bulkMessage = '중지 요청됨 · 진행 중인 AI 요청을 마무리하고 있습니다.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final desktop = c.maxWidth >= 980;
        return Scaffold(
          appBar: AppBar(
            title: Text(desktop ? 'VOC 관리' : 'VOC 목록'),
            actions: [
              IconButton(
                tooltip: _bulkRunning ? 'AI 일괄 처리 중지' : '미처리 VOC AI 일괄 처리',
                onPressed: _bulkRunning ? _stopBulk : _runBulk,
                icon: Icon(
                  _bulkRunning ? Icons.stop_circle_outlined : Icons.auto_awesome_outlined,
                  color: _bulkRunning ? Theme.of(context).colorScheme.error : null,
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: () => context.read<VocViewModel>().loadVocs(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: desktop
              ? null
              : FloatingActionButton.extended(
                  onPressed: _openRegister,
                  icon: const Icon(Icons.add),
                  label: const Text('VOC 등록'),
                ),
          bottomNavigationBar: _bulkStatusBar(),
          body: Consumer<VocViewModel>(
            builder: (context, vm, _) {
              final sorted = _sorted(vm.vocs);
              final pages = _pageSize == -1 ? 1 : (sorted.length / _pageSize).ceil().clamp(1, 999999);
              final page = _page.clamp(1, pages);
              final visible = _pageSize == -1
                  ? sorted
                  : sorted.skip((page - 1) * _pageSize).take(_pageSize).toList();

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1540),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(desktop ? 20 : 12, 14, desktop ? 20 : 12, 0),
                    child: Column(
                      children: [
                        _Toolbar(
                          desktop: desktop,
                          vm: vm,
                          sortBy: _sortBy,
                          ascending: _ascending,
                          pageSize: _pageSize,
                          page: page,
                          pages: pages,
                          total: sorted.length,
                          expanded: _mobileFilters,
                          onRegister: _openRegister,
                          onToggleMobile: () => setState(() => _mobileFilters = !_mobileFilters),
                          onSort: (v) => setState(() { _sortBy = v; _page = 1; }),
                          onDirection: () => setState(() => _ascending = !_ascending),
                          onPageSize: (v) => setState(() { _pageSize = v; _page = 1; }),
                          onPrev: page > 1 ? () => setState(() => _page--) : null,
                          onNext: page < pages ? () => setState(() => _page++) : null,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: vm.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : visible.isEmpty
                                  ? _EmptyState(onRegister: _openRegister)
                                  : desktop
                                      ? _DesktopTable(vocs: visible)
                                      : ListView.builder(
                                          padding: const EdgeInsets.only(bottom: 90),
                                          itemCount: visible.length,
                                          itemBuilder: (_, i) => _VocCard(voc: visible[i]),
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

  Widget? _bulkStatusBar() {
    if (!_bulkRunning && _bulkMessage.isEmpty) return null;
    final p = _bulkProgress;
    final total = p?.total ?? 0;
    final completed = p?.completed ?? 0;
    final progress = total == 0 ? null : completed / total;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Material(
        color: cs.surfaceContainerHigh,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_bulkRunning) LinearProgressIndicator(value: progress),
              if (_bulkRunning) const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _bulkRunning ? Icons.auto_awesome : Icons.check_circle_outline,
                    color: _bulkRunning ? cs.primary : cs.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_bulkMessage, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (p?.currentTitle != null)
                          Text(
                            '최근 처리: ${p!.currentTitle} · 성공 ${p.success} · 실패 ${p.failed}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (_bulkLastError != null)
                          Text(
                            '최근 오류: $_bulkLastError',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
                          ),
                      ],
                    ),
                  ),
                  if (_bulkRunning)
                    TextButton.icon(
                      onPressed: _stopBulk,
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

  List<VocEntity> _sorted(List<VocEntity> source) {
    final list = [...source];
    int rank(String p) => p == 'HIGH' ? 0 : p == 'MEDIUM' ? 1 : p == 'LOW' ? 2 : 3;
    int compare(VocEntity a, VocEntity b) {
      return switch (_sortBy) {
        'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        'customer' => a.customer.toLowerCase().compareTo(b.customer.toLowerCase()),
        'status' => a.status.compareTo(b.status),
        'priority' => rank(a.priority).compareTo(rank(b.priority)),
        'updated' => a.updatedAt.compareTo(b.updatedAt),
        _ => a.createdAt.compareTo(b.createdAt),
      };
    }
    list.sort(compare);
    return _ascending ? list : list.reversed.toList();
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.desktop,
    required this.vm,
    required this.sortBy,
    required this.ascending,
    required this.pageSize,
    required this.page,
    required this.pages,
    required this.total,
    required this.expanded,
    required this.onRegister,
    required this.onToggleMobile,
    required this.onSort,
    required this.onDirection,
    required this.onPageSize,
    required this.onPrev,
    required this.onNext,
  });

  final bool desktop;
  final VocViewModel vm;
  final String sortBy;
  final bool ascending;
  final int pageSize;
  final int page;
  final int pages;
  final int total;
  final bool expanded;
  final VoidCallback onRegister;
  final VoidCallback onToggleMobile;
  final ValueChanged<String> onSort;
  final VoidCallback onDirection;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<SettingsViewModel>().allCategories;
    final category = categories.contains(vm.filterCategory) ? vm.filterCategory : '';
    final controls = [
      Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'VOC 검색'), onChanged: vm.setSearch)),
      const SizedBox(width: 10),
      SizedBox(width: 160, child: DropdownButtonFormField<String>(initialValue: sortBy, decoration: const InputDecoration(labelText: '정렬'), items: const [
        DropdownMenuItem(value: 'latest', child: Text('등록일')),
        DropdownMenuItem(value: 'updated', child: Text('수정일')),
        DropdownMenuItem(value: 'title', child: Text('제목')),
        DropdownMenuItem(value: 'customer', child: Text('고객')),
        DropdownMenuItem(value: 'priority', child: Text('우선순위')),
        DropdownMenuItem(value: 'status', child: Text('상태')),
      ], onChanged: (v) { if (v != null) onSort(v); })),
      const SizedBox(width: 8),
      IconButton.filledTonal(onPressed: onDirection, icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward)),
      const SizedBox(width: 10),
      SizedBox(width: 210, child: DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: '카테고리'), items: [
        const DropdownMenuItem(value: '', child: Text('전체 카테고리')),
        ...categories.map((e) => DropdownMenuItem(value: e, child: Text(e))),
      ], onChanged: (v) => vm.setFilterCategory(v ?? ''))),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            if (desktop)
              Row(children: [...controls, const SizedBox(width: 10), FilledButton.icon(onPressed: onRegister, icon: const Icon(Icons.add), label: const Text('VOC 등록'))])
            else ...[
              TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'VOC 검색'), onChanged: vm.setSearch),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Wrap(spacing: 7, runSpacing: 7, children: [
                  _Status('전체', '', vm),
                  _Status('미처리', AppConstants.vocStatusOpen, vm),
                  _Status('처리중', AppConstants.vocStatusInProgress, vm),
                  _Status('해결', AppConstants.vocStatusResolved, vm),
                  _Status('반려', AppConstants.vocStatusRejected, vm),
                ])),
                if (!desktop)
                  TextButton.icon(onPressed: onToggleMobile, icon: Icon(expanded ? Icons.expand_less : Icons.tune), label: Text(expanded ? '접기' : '상세 필터')),
              ],
            ),
            if (!desktop && expanded) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(initialValue: sortBy, decoration: const InputDecoration(labelText: '정렬'), items: const [
                  DropdownMenuItem(value: 'latest', child: Text('등록일')),
                  DropdownMenuItem(value: 'updated', child: Text('수정일')),
                  DropdownMenuItem(value: 'title', child: Text('제목')),
                  DropdownMenuItem(value: 'customer', child: Text('고객')),
                ], onChanged: (v) { if (v != null) onSort(v); })),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: onDirection, icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward)),
              ]),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: '카테고리'), items: [
                const DropdownMenuItem(value: '', child: Text('전체 카테고리')),
                ...categories.map((e) => DropdownMenuItem(value: e, child: Text(e))),
              ], onChanged: (v) => vm.setFilterCategory(v ?? '')),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Text('총 $total건 · $page / $pages 페이지'),
              const Spacer(),
              SizedBox(width: 110, child: DropdownButtonFormField<int>(initialValue: pageSize, decoration: const InputDecoration(labelText: '페이지'), items: const [
                DropdownMenuItem(value: 25, child: Text('25건')),
                DropdownMenuItem(value: 50, child: Text('50건')),
                DropdownMenuItem(value: 100, child: Text('100건')),
                DropdownMenuItem(value: -1, child: Text('전체')),
              ], onChanged: (v) { if (v != null) onPageSize(v); })),
              IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
              IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.label, this.value, this.vm);
  final String label;
  final String value;
  final VocViewModel vm;

  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: vm.filterStatus == value,
        onSelected: (_) => vm.setFilterStatus(value),
      );
}

class _DesktopTable extends StatelessWidget {
  const _DesktopTable({required this.vocs});
  final List<VocEntity> vocs;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        DataTable(
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('제목')),
            DataColumn(label: Text('고객')),
            DataColumn(label: Text('카테고리')),
            DataColumn(label: Text('우선순위')),
            DataColumn(label: Text('상태')),
          ],
          rows: vocs.map((voc) => DataRow(onSelectChanged: (_) => _open(context, voc), cells: [
            DataCell(SizedBox(width: 420, child: Text(voc.title, overflow: TextOverflow.ellipsis))),
            DataCell(Text(voc.customer, overflow: TextOverflow.ellipsis)),
            DataCell(Text(voc.category)),
            DataCell(PriorityChip(priority: voc.priority)),
            DataCell(VocStatusChip(status: voc.status)),
          ])).toList(),
        ),
      ],
    );
  }
}

class _VocCard extends StatelessWidget {
  const _VocCard({required this.voc});
  final VocEntity voc;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          onTap: () => _open(context, voc),
          title: Text(voc.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Wrap(spacing: 7, runSpacing: 7, children: [
              Text(voc.customer),
              Text(voc.category),
              PriorityChip(priority: voc.priority),
              VocStatusChip(status: voc.status),
            ]),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRegister});
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 52, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('VOC가 없습니다.'),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: onRegister, icon: const Icon(Icons.add), label: const Text('VOC 등록')),
        ]),
      );
}

void _open(BuildContext context, VocEntity voc) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => VocDetailScreen(vocId: voc.id)),
  );
}
