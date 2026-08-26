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
  const VocListScreen({super.key, this.initialStatus = '', this.initialCategory = ''});
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
      if (widget.initialStatus.isNotEmpty) vm.setFilterStatus(widget.initialStatus);
      if (widget.initialCategory.isNotEmpty) vm.setFilterCategory(widget.initialCategory);
      vm.loadVocs();
    });
  }

  Future<void> _register() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const VocRegisterScreen()));
    if (!mounted) return;
    await context.read<VocViewModel>().loadVocs();
    unawaited(context.read<DashboardViewModel>().loadDashboard());
  }

  Future<void> _bulk() async {
    if (_bulkRunning) return;
    final count = context.read<VocViewModel>().pendingVocCount;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('미처리 VOC가 없습니다.')));
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('실행')),
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
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          if (p.lastError != null) _lastError = p.lastError;
          _bulkMessage = '${p.completed} / ${p.total} 처리 완료 · 성공 ${p.success} · 실패 ${p.failed}';
        });
      },
    );
    if (!mounted) return;

    await context.read<VocViewModel>().loadVocs();
    unawaited(context.read<DashboardViewModel>().loadDashboard());

    // 건마다 네트워크 동기화를 기다리지 않고 마지막에 스냅샷을 한 번만 전송한다.
    if (settings.vocAutoForwardEnabled && settings.vocForwardWebhookTargets.isNotEmpty) {
      unawaited(context.read<IntegrationViewModel>().forwardFullVocAndManualToPeerApps());
    }

    setState(() {
      _bulkRunning = false;
      _bulkMessage = result.stopped
          ? 'AI 일괄 처리 중지 · 성공 ${result.success} · 실패 ${result.failed}'
          : 'AI 일괄 처리 완료 · 성공 ${result.success} · 실패 ${result.failed} · 기존 답변 재사용 ${result.reused}';
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
    return LayoutBuilder(builder: (context, box) {
      final desktop = box.maxWidth >= 980;
      return Scaffold(
        appBar: AppBar(
          title: Text(desktop ? 'VOC 관리' : 'VOC 목록'),
          actions: [
            IconButton(
              tooltip: _bulkRunning ? 'AI 일괄 처리 중지' : '미처리 VOC AI 일괄 처리',
              onPressed: _bulkRunning ? _stop : _bulk,
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
            : FloatingActionButton.extended(onPressed: _register, icon: const Icon(Icons.add), label: const Text('VOC 등록')),
        bottomNavigationBar: _statusBar(),
        body: Consumer<VocViewModel>(builder: (context, vm, _) {
          final sorted = _sortVocs(vm.vocs);
          final int pages = _pageSize == -1 ? 1 : (sorted.length / _pageSize).ceil().clamp(1, 999999).toInt();
          final int current = _page < 1 ? 1 : (_page > pages ? pages : _page);
          final visible = _pageSize == -1
              ? sorted
              : sorted.skip((current - 1) * _pageSize).take(_pageSize).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1540),
              child: Padding(
                padding: EdgeInsets.fromLTRB(desktop ? 20 : 12, 14, desktop ? 20 : 12, 0),
                child: Column(children: [
                  _Filters(
                    desktop: desktop,
                    vm: vm,
                    sort: _sort,
                    ascending: _ascending,
                    pageSize: _pageSize,
                    current: current,
                    pages: pages,
                    total: sorted.length,
                    mobileExpanded: _mobileFilters,
                    onRegister: _register,
                    onToggleMobile: () => setState(() => _mobileFilters = !_mobileFilters),
                    onSort: (v) => setState(() { _sort = v; _page = 1; }),
                    onDirection: () => setState(() => _ascending = !_ascending),
                    onPageSize: (v) => setState(() { _pageSize = v; _page = 1; }),
                    onPrev: current > 1 ? () => setState(() => _page = current - 1) : null,
                    onNext: current < pages ? () => setState(() => _page = current + 1) : null,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: vm.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : visible.isEmpty
                            ? _Empty(onRegister: _register)
                            : desktop
                                ? _Table(vocs: visible)
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 90),
                                    itemCount: visible.length,
                                    itemBuilder: (_, i) => _Card(voc: visible[i]),
                                  ),
                  ),
                ]),
              ),
            ),
          );
        }),
      );
    });
  }

  Widget? _statusBar() {
    if (!_bulkRunning && _bulkMessage.isEmpty) return null;
    final p = _progress;
    final double? value = p == null || p.total == 0 ? null : p.completed / p.total;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        color: cs.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_bulkRunning) LinearProgressIndicator(value: value),
            if (_bulkRunning) const SizedBox(height: 8),
            Row(children: [
              Icon(_bulkRunning ? Icons.auto_awesome : Icons.check_circle_outline, color: cs.primary, size: 20),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_bulkMessage, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (p?.currentTitle != null)
                  Text('최근 처리: ${p!.currentTitle}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                if (_lastError != null)
                  Text('최근 오류: $_lastError', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error)),
              ])),
              if (_bulkRunning) TextButton.icon(onPressed: _stop, icon: const Icon(Icons.stop_circle_outlined), label: const Text('중지')),
            ]),
          ]),
        ),
      ),
    );
  }

  List<VocEntity> _sortVocs(List<VocEntity> input) {
    final list = [...input];
    int priority(String p) => p == 'HIGH' ? 0 : p == 'MEDIUM' ? 1 : p == 'LOW' ? 2 : 3;
    int cmp(VocEntity a, VocEntity b) => switch (_sort) {
      'updated' => a.updatedAt.compareTo(b.updatedAt),
      'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      'customer' => a.customer.toLowerCase().compareTo(b.customer.toLowerCase()),
      'priority' => priority(a.priority).compareTo(priority(b.priority)),
      'status' => a.status.compareTo(b.status),
      _ => a.createdAt.compareTo(b.createdAt),
    };
    list.sort(cmp);
    return _ascending ? list : list.reversed.toList();
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.desktop, required this.vm, required this.sort, required this.ascending,
    required this.pageSize, required this.current, required this.pages, required this.total,
    required this.mobileExpanded, required this.onRegister, required this.onToggleMobile,
    required this.onSort, required this.onDirection, required this.onPageSize,
    required this.onPrev, required this.onNext,
  });
  final bool desktop, ascending, mobileExpanded;
  final VocViewModel vm;
  final String sort;
  final int pageSize, current, pages, total;
  final VoidCallback onRegister, onToggleMobile, onDirection;
  final ValueChanged<String> onSort;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<SettingsViewModel>().allCategories;
    final category = categories.contains(vm.filterCategory) ? vm.filterCategory : '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          if (desktop)
            Row(children: [
              Expanded(child: _Search(vm: vm)),
              const SizedBox(width: 10),
              SizedBox(width: 155, child: _Sort(value: sort, onChanged: onSort)),
              IconButton.filledTonal(onPressed: onDirection, icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward)),
              const SizedBox(width: 10),
              SizedBox(width: 210, child: _Category(value: category, categories: categories, onChanged: vm.setFilterCategory)),
              const SizedBox(width: 10),
              FilledButton.icon(onPressed: onRegister, icon: const Icon(Icons.add), label: const Text('VOC 등록')),
            ])
          else _Search(vm: vm),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Wrap(spacing: 7, runSpacing: 7, children: [
              _Status('전체', '', vm), _Status('미처리', AppConstants.vocStatusOpen, vm),
              _Status('처리중', AppConstants.vocStatusInProgress, vm), _Status('해결', AppConstants.vocStatusResolved, vm),
              _Status('반려', AppConstants.vocStatusRejected, vm),
            ])),
            if (!desktop) TextButton.icon(onPressed: onToggleMobile, icon: Icon(mobileExpanded ? Icons.expand_less : Icons.tune), label: Text(mobileExpanded ? '접기' : '상세 필터')),
          ]),
          if (!desktop && mobileExpanded) ...[
            const SizedBox(height: 10),
            Row(children: [Expanded(child: _Sort(value: sort, onChanged: onSort)), IconButton.filledTonal(onPressed: onDirection, icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward))]),
            const SizedBox(height: 10),
            _Category(value: category, categories: categories, onChanged: vm.setFilterCategory),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Text('총 $total건 · $current / $pages 페이지'),
            const Spacer(),
            SizedBox(width: 105, child: DropdownButtonFormField<int>(initialValue: pageSize, decoration: const InputDecoration(labelText: '페이지'), items: const [
              DropdownMenuItem(value: 25, child: Text('25건')), DropdownMenuItem(value: 50, child: Text('50건')),
              DropdownMenuItem(value: 100, child: Text('100건')), DropdownMenuItem(value: -1, child: Text('전체')),
            ], onChanged: (v) { if (v != null) onPageSize(v); })),
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ]),
        ]),
      ),
    );
  }
}

class _Search extends StatelessWidget {
  const _Search({required this.vm});
  final VocViewModel vm;
  @override Widget build(BuildContext context) => TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'VOC 검색'), onChanged: vm.setSearch);
}

class _Sort extends StatelessWidget {
  const _Sort({required this.value, required this.onChanged});
  final String value; final ValueChanged<String> onChanged;
  @override Widget build(BuildContext context) => DropdownButtonFormField<String>(initialValue: value, decoration: const InputDecoration(labelText: '정렬'), items: const [
    DropdownMenuItem(value: 'latest', child: Text('등록일')), DropdownMenuItem(value: 'updated', child: Text('수정일')),
    DropdownMenuItem(value: 'title', child: Text('제목')), DropdownMenuItem(value: 'customer', child: Text('고객')),
    DropdownMenuItem(value: 'priority', child: Text('우선순위')), DropdownMenuItem(value: 'status', child: Text('상태')),
  ], onChanged: (v) { if (v != null) onChanged(v); });
}

class _Category extends StatelessWidget {
  const _Category({required this.value, required this.categories, required this.onChanged});
  final String value; final List<String> categories; final ValueChanged<String> onChanged;
  @override Widget build(BuildContext context) => DropdownButtonFormField<String>(initialValue: value, decoration: const InputDecoration(labelText: '카테고리'), items: [
    const DropdownMenuItem(value: '', child: Text('전체 카테고리')), ...categories.map((e) => DropdownMenuItem(value: e, child: Text(e))),
  ], onChanged: (v) => onChanged(v ?? ''));
}

class _Status extends StatelessWidget {
  const _Status(this.label, this.value, this.vm);
  final String label, value; final VocViewModel vm;
  @override Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: vm.filterStatus == value, onSelected: (_) => vm.setFilterStatus(value));
}

class _Table extends StatelessWidget {
  const _Table({required this.vocs}); final List<VocEntity> vocs;
  @override Widget build(BuildContext context) => ListView(children: [DataTable(showCheckboxColumn: false, columns: const [
    DataColumn(label: Text('제목')), DataColumn(label: Text('고객')), DataColumn(label: Text('카테고리')), DataColumn(label: Text('우선순위')), DataColumn(label: Text('상태')),
  ], rows: vocs.map((v) => DataRow(onSelectChanged: (_) => _open(context, v), cells: [
    DataCell(SizedBox(width: 420, child: Text(v.title, overflow: TextOverflow.ellipsis))), DataCell(Text(v.customer)), DataCell(Text(v.category)),
    DataCell(PriorityChip(priority: v.priority)), DataCell(VocStatusChip(status: v.status)),
  ])).toList())]);
}

class _Card extends StatelessWidget {
  const _Card({required this.voc}); final VocEntity voc;
  @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 9), child: ListTile(
    onTap: () => _open(context, voc), title: Text(voc.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Padding(padding: const EdgeInsets.only(top: 7), child: Wrap(spacing: 7, runSpacing: 7, children: [Text(voc.customer), Text(voc.category), PriorityChip(priority: voc.priority), VocStatusChip(status: voc.status)])),
    trailing: const Icon(Icons.chevron_right),
  ));
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onRegister}); final VoidCallback onRegister;
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.inbox_outlined, size: 52, color: Theme.of(context).colorScheme.outline), const SizedBox(height: 12), const Text('VOC가 없습니다.'),
    const SizedBox(height: 10), FilledButton.icon(onPressed: onRegister, icon: const Icon(Icons.add), label: const Text('VOC 등록')),
  ]));
}

void _open(BuildContext context, VocEntity voc) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => VocDetailScreen(vocId: voc.id)));
}
