import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/response_entity.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../viewmodels/ai_viewmodel.dart';
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

  bool _bulkRunning = false;
  bool _stopRequested = false;
  int _bulkTotal = 0;
  int _bulkCurrent = 0;
  int _bulkSuccess = 0;
  int _bulkFailed = 0;
  int _bulkExisting = 0;
  String _bulkTitle = '';
  String _bulkMessage = '';
  String _bulkError = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<VocViewModel>();
      if (widget.initialStatus.isNotEmpty) vm.setFilterStatus(widget.initialStatus);
      if (widget.initialCategory.isNotEmpty) vm.setFilterCategory(widget.initialCategory);
      await vm.loadVocs();
    });
  }

  Future<void> _openRegister() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VocRegisterScreen()),
    );
    if (!mounted) return;
    await context.read<VocViewModel>().loadVocs();
    await context.read<DashboardViewModel>().loadDashboard();
  }

  Future<void> _openDetail(VocEntity voc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VocDetailScreen(vocId: voc.id)),
    );
    if (!mounted) return;
    await context.read<VocViewModel>().loadVocs();
    await context.read<DashboardViewModel>().loadDashboard();
  }

  void _requestStop() {
    if (!_bulkRunning) return;
    setState(() {
      _stopRequested = true;
      _bulkMessage = '중지 요청됨 · 현재 AI 요청 종료 후 중지합니다.';
    });
  }

  Future<void> _runBulkAi() async {
    if (_bulkRunning) return;

    final vocVm = context.read<VocViewModel>();
    final aiVm = context.read<AiViewModel>();
    final integrationVm = context.read<IntegrationViewModel>();
    final dashboardVm = context.read<DashboardViewModel>();

    await vocVm.loadVocs();
    final targets = vocVm.allVocs
        .where((voc) =>
            voc.status == AppConstants.vocStatusOpen ||
            voc.status == AppConstants.vocStatusInProgress)
        .toList();

    if (!mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미처리 VOC가 없습니다.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('미처리 VOC AI 답변 일괄 등록'),
        content: Text(
          '미처리 VOC ${targets.length}건을 순서대로 처리합니다.\n\n'
          'AI 답변 저장이 성공한 항목만 해결 상태로 변경합니다. AI 호출 실패 또는 근거 부족 항목은 미처리 상태로 유지합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('실행'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _bulkRunning = true;
      _stopRequested = false;
      _bulkTotal = targets.length;
      _bulkCurrent = 0;
      _bulkSuccess = 0;
      _bulkFailed = 0;
      _bulkExisting = 0;
      _bulkTitle = '';
      _bulkError = '';
      _bulkMessage = 'AI 답변 일괄 처리를 시작합니다.';
    });

    for (var i = 0; i < targets.length; i++) {
      if (_stopRequested || !mounted) break;
      final voc = targets[i];

      setState(() {
        _bulkCurrent = i + 1;
        _bulkTitle = voc.title;
        _bulkError = '';
        _bulkMessage = '$_bulkCurrent / $_bulkTotal 번째 답변 처리 중';
      });

      try {
        await vocVm.loadResponsesForVoc(voc.id);
        final responses = List<ResponseEntity>.from(vocVm.responses);
        final approved = responses.where((item) => item.isApproved).toList();
        ResponseEntity? stored;
        var usedExistingApproved = false;

        if (approved.isNotEmpty) {
          stored = approved.first;
          usedExistingApproved = true;
          _bulkExisting += 1;
        } else {
          final reusable = responses.where((item) => item.aiGenerated).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (reusable.isNotEmpty) {
            final existing = reusable.first;
            stored = await vocVm.adoptAiAnswer(
              vocId: voc.id,
              content: existing.content,
              confidence: existing.confidenceScore,
              referencedVocIds: existing.referencedVocIds,
              responseId: existing.id,
            );
          } else {
            aiVm.clearResults();
            await aiVm.searchSimilarVocs('${voc.title} ${voc.content}');
            if (_stopRequested) break;

            final result = await aiVm.generateAnswer(voc.title, voc.content);
            if (_stopRequested) break;

            if (result == null) {
              throw StateError(aiVm.error ?? 'AI 답변 생성에 실패했습니다.');
            }
            final answer = result.answer.trim();
            if (answer.isEmpty) {
              throw StateError(aiVm.error ?? 'AI가 빈 답변을 반환했습니다.');
            }
            if (result.confidence <= 0.25 && result.referencedCases.isEmpty) {
              throw StateError(
                result.notes.trim().isNotEmpty
                    ? result.notes.trim()
                    : '근거가 충분하지 않아 자동 답변을 등록하지 않았습니다.',
              );
            }

            final referenceVocIds = aiVm.similarVocs
                .map((item) => item.knowledgeBase.vocId)
                .whereType<String>()
                .toSet()
                .toList();

            stored = await vocVm.adoptAiAnswer(
              vocId: voc.id,
              content: answer,
              confidence: result.confidence,
              referencedVocIds: referenceVocIds,
            );
          }
        }

        if (stored == null) {
          throw StateError('AI 답변 저장에 실패했습니다.');
        }
        final savedResponse = stored;

        if (!usedExistingApproved) {
          try {
            await integrationVm.forwardVocChangeToPeerApps(
              voc: voc,
              event: 'response.approved',
              response: savedResponse,
            );
          } catch (_) {
            // 외부 동기화 실패는 로컬 저장 성공을 취소하지 않는다.
          }
        }

        if (voc.status != AppConstants.vocStatusResolved) {
          await vocVm.updateVocStatus(voc.id, AppConstants.vocStatusResolved);
          final updated = vocVm.allVocs.where((item) => item.id == voc.id);
          if (updated.isNotEmpty) {
            try {
              await integrationVm.forwardVocChangeToPeerApps(
                voc: updated.first,
                event: 'voc.status_changed',
              );
            } catch (_) {
              // 외부 동기화 실패는 로컬 상태 변경을 취소하지 않는다.
            }
          }
        }

        if (!mounted) break;
        setState(() {
          _bulkSuccess += 1;
          _bulkMessage = '$_bulkCurrent / $_bulkTotal 완료 · 성공 $_bulkSuccess · 실패 $_bulkFailed';
        });
      } catch (e) {
        if (!mounted) break;
        setState(() {
          _bulkFailed += 1;
          _bulkError = e.toString().replaceFirst('Bad state: ', '');
          _bulkMessage = '$_bulkCurrent / $_bulkTotal 실패 · 다음 VOC 계속 진행';
        });
      }
    }

    await vocVm.loadVocs();
    await dashboardVm.loadDashboard();
    if (!mounted) return;

    final wasStopped = _stopRequested;
    setState(() {
      _bulkRunning = false;
      _bulkTitle = '';
      _bulkMessage = wasStopped
          ? '일괄 처리 중지 · 성공 $_bulkSuccess · 실패 $_bulkFailed · 기존 답변 $_bulkExisting'
          : '일괄 처리 완료 · 성공 $_bulkSuccess · 실패 $_bulkFailed · 기존 답변 $_bulkExisting';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_bulkMessage), duration: const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final desktop = bounds.maxWidth >= 980;
        return Scaffold(
          appBar: AppBar(
            title: Text(desktop ? 'VOC 관리' : 'VOC 목록'),
            actions: [
              IconButton(
                onPressed: _bulkRunning ? _requestStop : _runBulkAi,
                tooltip: _bulkRunning ? '일괄 처리 중지' : '미처리 VOC AI 답변 일괄 등록',
                color: _bulkRunning ? Theme.of(context).colorScheme.error : null,
                icon: Icon(
                  _bulkRunning ? Icons.stop_circle_outlined : Icons.auto_awesome_outlined,
                ),
              ),
              IconButton(
                onPressed: _bulkRunning ? null : () => context.read<VocViewModel>().loadVocs(),
                tooltip: '새로고침',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: desktop
              ? null
              : FloatingActionButton.extended(
                  onPressed: _bulkRunning ? null : _openRegister,
                  icon: const Icon(Icons.add),
                  label: const Text('VOC 등록'),
                ),
          bottomNavigationBar: _bulkStatusBar(context),
          body: Consumer<VocViewModel>(
            builder: (context, vm, _) {
              final sorted = _sort(vm.vocs);
              final totalPages = _pageSize == -1 || sorted.isEmpty
                  ? 1
                  : (sorted.length / _pageSize).ceil();
              final int safePage = _page < 1
                  ? 1
                  : _page > totalPages
                      ? totalPages
                      : _page;
              final visible = _pageSize == -1
                  ? sorted
                  : _slicePage(sorted, safePage, _pageSize);

              if (safePage != _page) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _page = safePage);
                });
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1540),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(desktop ? 20 : 12, 14, desktop ? 20 : 12, 0),
                    child: Column(
                      children: [
                        _FilterBar(
                          vm: vm,
                          desktop: desktop,
                          sortBy: _sortBy,
                          ascending: _ascending,
                          pageSize: _pageSize,
                          page: safePage,
                          pages: totalPages,
                          total: sorted.length,
                          onSort: (value) => setState(() {
                            _sortBy = value;
                            _page = 1;
                          }),
                          onDirection: () => setState(() => _ascending = !_ascending),
                          onPageSize: (value) => setState(() {
                            _pageSize = value;
                            _page = 1;
                          }),
                          onPrevious: safePage > 1 ? () => setState(() => _page--) : null,
                          onNext: safePage < totalPages ? () => setState(() => _page++) : null,
                          onRegister: _bulkRunning ? null : _openRegister,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: vm.isLoading && !_bulkRunning
                              ? const Center(child: CircularProgressIndicator())
                              : visible.isEmpty
                                  ? const Center(child: Text('조건에 맞는 VOC가 없습니다.'))
                                  : ListView.separated(
                                      padding: const EdgeInsets.only(bottom: 90),
                                      itemCount: visible.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                                      itemBuilder: (_, index) => _VocRow(
                                        voc: visible[index],
                                        desktop: desktop,
                                        onTap: () => _openDetail(visible[index]),
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

  Widget? _bulkStatusBar(BuildContext context) {
    if (!_bulkRunning && _bulkMessage.isEmpty) return null;
    final cs = Theme.of(context).colorScheme;
    final rawProgress = _bulkTotal == 0 ? 0.0 : _bulkCurrent / _bulkTotal;
    final double progress = rawProgress < 0
        ? 0.0
        : rawProgress > 1
            ? 1.0
            : rawProgress;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        color: cs.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_bulkRunning) LinearProgressIndicator(value: progress),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(_bulkRunning ? Icons.auto_awesome : Icons.task_alt, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_bulkMessage, style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (_bulkRunning && _bulkTitle.isNotEmpty)
                          Text(
                            '현재 처리: $_bulkTitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (_bulkError.isNotEmpty)
                          Text(
                            '최근 오류: $_bulkError',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$_bulkCurrent / $_bulkTotal', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (_bulkRunning) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _stopRequested ? null : _requestStop,
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('중지'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<VocEntity> _slicePage(List<VocEntity> list, int page, int size) {
    final start = (page - 1) * size;
    if (start >= list.length) return const [];
    final end = start + size > list.length ? list.length : start + size;
    return list.sublist(start, end);
  }

  List<VocEntity> _sort(List<VocEntity> source) {
    final list = [...source];
    int compare(VocEntity a, VocEntity b) {
      switch (_sortBy) {
        case 'updated':
          return a.updatedAt.compareTo(b.updatedAt);
        case 'title':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'customer':
          return a.customer.toLowerCase().compareTo(b.customer.toLowerCase());
        case 'status':
          return a.status.compareTo(b.status);
        case 'priority':
          return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
        default:
          return a.createdAt.compareTo(b.createdAt);
      }
    }
    list.sort(compare);
    return _ascending ? list : list.reversed.toList();
  }

  int _priorityRank(String value) {
    if (value == AppConstants.priorityHigh) return 0;
    if (value == AppConstants.priorityMedium) return 1;
    if (value == AppConstants.priorityLow) return 2;
    return 3;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.vm,
    required this.desktop,
    required this.sortBy,
    required this.ascending,
    required this.pageSize,
    required this.page,
    required this.pages,
    required this.total,
    required this.onSort,
    required this.onDirection,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onRegister,
  });

  final VocViewModel vm;
  final bool desktop;
  final String sortBy;
  final bool ascending;
  final int pageSize;
  final int page;
  final int pages;
  final int total;
  final ValueChanged<String> onSort;
  final VoidCallback onDirection;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<SettingsViewModel>().allCategories;
    final category = categories.contains(vm.filterCategory) ? vm.filterCategory : '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: desktop ? 290 : 320,
              child: TextField(
                onChanged: vm.setSearch,
                decoration: const InputDecoration(hintText: 'VOC 검색', prefixIcon: Icon(Icons.search)),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: vm.filterStatus,
                decoration: const InputDecoration(labelText: '상태'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('전체')),
                  DropdownMenuItem(value: AppConstants.vocStatusOpen, child: Text('미처리')),
                  DropdownMenuItem(value: AppConstants.vocStatusInProgress, child: Text('처리중')),
                  DropdownMenuItem(value: AppConstants.vocStatusResolved, child: Text('해결')),
                  DropdownMenuItem(value: AppConstants.vocStatusRejected, child: Text('반려')),
                ],
                onChanged: (value) => vm.setFilterStatus(value ?? ''),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('전체')),
                  ...categories.map((item) => DropdownMenuItem(value: item, child: Text(item))),
                ],
                onChanged: (value) => vm.setFilterCategory(value ?? ''),
              ),
            ),
            SizedBox(
              width: 145,
              child: DropdownButtonFormField<String>(
                initialValue: sortBy,
                decoration: const InputDecoration(labelText: '정렬'),
                items: const [
                  DropdownMenuItem(value: 'latest', child: Text('등록일')),
                  DropdownMenuItem(value: 'updated', child: Text('수정일')),
                  DropdownMenuItem(value: 'title', child: Text('제목')),
                  DropdownMenuItem(value: 'customer', child: Text('고객')),
                  DropdownMenuItem(value: 'status', child: Text('상태')),
                  DropdownMenuItem(value: 'priority', child: Text('우선순위')),
                ],
                onChanged: (value) {
                  if (value != null) onSort(value);
                },
              ),
            ),
            IconButton.filledTonal(
              onPressed: onDirection,
              icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
            ),
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<int>(
                initialValue: pageSize,
                decoration: const InputDecoration(labelText: '표시'),
                items: const [
                  DropdownMenuItem(value: 25, child: Text('25개')),
                  DropdownMenuItem(value: 50, child: Text('50개')),
                  DropdownMenuItem(value: 100, child: Text('100개')),
                  DropdownMenuItem(value: -1, child: Text('전체')),
                ],
                onChanged: (value) {
                  if (value != null) onPageSize(value);
                },
              ),
            ),
            Text('총 $total건 · $page / $pages'),
            IconButton.filledTonal(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
            IconButton.filledTonal(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            if (desktop)
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

class _VocRow extends StatelessWidget {
  const _VocRow({
    required this.voc,
    required this.desktop,
    required this.onTap,
  });

  final VocEntity voc;
  final bool desktop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: desktop
              ? Row(
                  children: [
                    SizedBox(width: 100, child: VocStatusChip(status: voc.status)),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(voc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(voc.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(voc.customer, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(voc.category, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 12),
                    SizedBox(width: 90, child: PriorityChip(priority: voc.priority)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        VocStatusChip(status: voc.status),
                        PriorityChip(priority: voc.priority),
                        Chip(label: Text(voc.category), visualDensity: VisualDensity.compact),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(voc.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(voc.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 7),
                    Text('${voc.customer} · ${voc.project}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
        ),
      ),
    );
  }
}
