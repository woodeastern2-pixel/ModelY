import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/response_entity.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../viewmodels/ai_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/jira_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';
import '../../widgets/priority_chip.dart';
import '../../widgets/voc_status_chip.dart';
import 'ai_answer_screen.dart';

class VocDetailScreen extends StatefulWidget {
  const VocDetailScreen({super.key, required this.vocId});
  final String vocId;

  @override
  State<VocDetailScreen> createState() => _VocDetailScreenState();
}

class _VocDetailScreenState extends State<VocDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VocViewModel>().selectVoc(widget.vocId);
      context.read<JiraViewModel>().loadLinksForVoc(widget.vocId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VocViewModel>(
      builder: (context, vm, _) {
        final voc = vm.selectedVoc;
        if (voc == null || voc.id != widget.vocId) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final jiraConfigured = context.watch<JiraViewModel>().isConfigured;

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1000;
            return Scaffold(
              appBar: AppBar(
                title: Text(voc.title, overflow: TextOverflow.ellipsis),
                actions: [
                  PopupMenuButton<String>(
                    tooltip: 'VOC 작업',
                    onSelected: (action) => _handleAction(context, action, vm),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('수정')),
                      if (voc.status == AppConstants.vocStatusOpen)
                        const PopupMenuItem(
                          value: 'in_progress',
                          child: Text('처리중으로 변경'),
                        ),
                      if (voc.status != AppConstants.vocStatusResolved)
                        const PopupMenuItem(value: 'resolve', child: Text('해결 완료')),
                      if (voc.status != AppConstants.vocStatusRejected)
                        const PopupMenuItem(value: 'reject', child: Text('반려 처리')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('삭제')),
                    ],
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 28 : 14,
                  desktop ? 24 : 14,
                  desktop ? 28 : 14,
                  56,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 430, child: _VocSummaryCard(voc: voc)),
                              const SizedBox(width: 16),
                              Expanded(child: _VocContentCard(voc: voc)),
                            ],
                          )
                        else ...[
                          _VocSummaryCard(voc: voc),
                          const SizedBox(height: 12),
                          _VocContentCard(voc: voc),
                        ],
                        const SizedBox(height: 16),
                        _IntelligencePanel(voc: voc, desktop: desktop),
                        const SizedBox(height: 16),
                        if (voc.businessScore != null && !voc.isBusinessRelated)
                          const _RejectBanner()
                        else
                          _AiAnswerEntry(voc: voc),
                        const SizedBox(height: 16),
                        _ResponsesWorkspace(voc: voc, vm: vm, desktop: desktop),
                        const SizedBox(height: 16),
                        if (desktop && jiraConfigured)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CollaborationActions(
                                  voc: voc,
                                  responses: vm.responses,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _JiraSection(
                                  vocId: voc.id,
                                  vocTitle: voc.title,
                                  vocContent: voc.content,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _CollaborationActions(voc: voc, responses: vm.responses),
                          if (jiraConfigured) ...[
                            const SizedBox(height: 12),
                            _JiraSection(
                              vocId: voc.id,
                              vocTitle: voc.title,
                              vocContent: voc.content,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    VocViewModel vm,
  ) async {
    final voc = vm.selectedVoc!;
    if (action == 'edit') {
      await _showEditDialog(context, vm, voc);
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('VOC 삭제'),
          content: const Text('이 VOC와 연결된 답변을 포함해 삭제합니다. 계속하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await context.read<IntegrationViewModel>().forwardVocChangeToPeerApps(
              voc: voc,
              event: 'voc.deleted',
            );
        await vm.deleteVoc(voc.id);
        if (context.mounted) Navigator.pop(context);
      }
      return;
    }

    final status = switch (action) {
      'in_progress' => AppConstants.vocStatusInProgress,
      'resolve' => AppConstants.vocStatusResolved,
      'reject' => AppConstants.vocStatusRejected,
      _ => null,
    };
    if (status == null) return;
    await vm.updateVocStatus(voc.id, status);
    if (context.mounted && vm.selectedVoc != null) {
      await context.read<IntegrationViewModel>().forwardVocChangeToPeerApps(
            voc: vm.selectedVoc!,
            event: 'voc.status_changed',
          );
      context.read<DashboardViewModel>().loadDashboard();
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    VocViewModel vm,
    VocEntity voc,
  ) async {
    final title = TextEditingController(text: voc.title);
    final content = TextEditingController(text: voc.content);
    final customer = TextEditingController(text: voc.customer);
    final project = TextEditingController(text: voc.project);
    final categories = context.read<SettingsViewModel>().allCategories;
    var category = categories.contains(voc.category)
        ? voc.category
        : (categories.isEmpty ? '' : categories.first);
    var priority = voc.priority;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('VOC 수정'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: customer, decoration: const InputDecoration(labelText: '고객명')),
                  const SizedBox(height: 10),
                  TextField(controller: project, decoration: const InputDecoration(labelText: '프로젝트')),
                  const SizedBox(height: 10),
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: '카테고리'),
                      items: categories
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => category = value);
                      },
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: '우선순위'),
                    items: const [
                      DropdownMenuItem(value: 'HIGH', child: Text('높음')),
                      DropdownMenuItem(value: 'MEDIUM', child: Text('보통')),
                      DropdownMenuItem(value: 'LOW', child: Text('낮음')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => priority = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: const InputDecoration(labelText: '제목')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: content,
                    minLines: 5,
                    maxLines: 9,
                    decoration: const InputDecoration(labelText: '내용', alignLabelWithHint: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
          ],
        ),
      ),
    );

    if (saved == true) {
      if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('제목과 내용은 비워둘 수 없습니다.')),
          );
        }
      } else {
        await vm.updateVocFields(
          voc.id,
          title: title.text.trim(),
          content: content.text.trim(),
          category: category,
          customer: customer.text.trim(),
          project: project.text.trim(),
          priority: priority,
        );
        if (context.mounted && vm.selectedVoc != null) {
          await context.read<IntegrationViewModel>().forwardVocChangeToPeerApps(
                voc: vm.selectedVoc!,
                event: 'voc.updated',
              );
        }
      }
    }
    title.dispose();
    content.dispose();
    customer.dispose();
    project.dispose();
  }
}

class _VocSummaryCard extends StatelessWidget {
  const _VocSummaryCard({required this.voc});
  final VocEntity voc;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'VOC 요약',
      icon: Icons.assignment_outlined,
      child: Column(
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
          const SizedBox(height: 14),
          _MetaRow(Icons.person_outline, '고객', voc.customer),
          if (voc.businessType != null)
            _MetaRow(Icons.work_outline, '업무 구분', voc.businessType!),
          _MetaRow(Icons.folder_outlined, '프로젝트', voc.project),
          _MetaRow(Icons.schedule_outlined, '등록일', _formatDate(voc.createdAt)),
          if (voc.aiCategory != null)
            _MetaRow(Icons.auto_awesome_outlined, 'AI 분류', voc.aiCategory!),
          if (voc.urgency != null)
            _MetaRow(Icons.priority_high_outlined, '긴급도', voc.urgency!),
          if (voc.department != null)
            _MetaRow(Icons.apartment_outlined, '담당 부서', voc.department!),
          if (voc.assignee != null)
            _MetaRow(Icons.badge_outlined, '담당자 추천', voc.assignee!),
          if (voc.duplicateScore != null)
            _MetaRow(
              Icons.copy_all_outlined,
              '중복 가능성',
              '${(voc.duplicateScore! * 100).toStringAsFixed(0)}%',
            ),
          if (voc.jiraScore != null)
            _MetaRow(
              Icons.bug_report_outlined,
              'JIRA 판단',
              voc.jiraRequired ? '필요' : '불필요',
            ),
        ],
      ),
    );
  }
}

class _VocContentCard extends StatelessWidget {
  const _VocContentCard({required this.voc});
  final VocEntity voc;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Panel(
      title: 'VOC 내용',
      icon: Icons.subject_outlined,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 190),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SelectableText(
          voc.content,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
        ),
      ),
    );
  }
}

class _IntelligencePanel extends StatefulWidget {
  const _IntelligencePanel({required this.voc, required this.desktop});
  final VocEntity voc;
  final bool desktop;

  @override
  State<_IntelligencePanel> createState() => _IntelligencePanelState();
}

class _IntelligencePanelState extends State<_IntelligencePanel> {
  bool _running = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    final result = await context.read<AiViewModel>().analyzeVocIntelligence(
          widget.voc.title,
          widget.voc.content,
        );
    if (result != null && mounted) {
      await context.read<VocViewModel>().updateVocWithAiAnalysis(
            widget.voc.id,
            isBusinessRelated: result.isBusiness,
            aiCategory: result.category,
            businessScore: result.businessScore,
            categoryScore: result.categoryScore,
            urgency: result.urgency,
            urgencyScore: result.urgencyScore,
            department: result.department,
            departmentScore: result.departmentScore,
            assignee: result.assignee,
            assigneeScore: result.assigneeScore,
            duplicateOfVocId: result.duplicateOfVocId,
            duplicateScore: result.duplicateScore,
            jiraRequired: result.jiraRequired,
            jiraScore: result.jiraScore,
            analysisReason: result.reason,
          );
    }
    if (!mounted) return;
    setState(() => _running = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result == null ? 'AI 분석에 실패했습니다.' : 'AI 분석 결과를 갱신했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voc = widget.voc;
    final metrics = [
      _MetricData(
        '업무 관련성',
        voc.businessScore == null
            ? '분석 전'
            : (voc.isBusinessRelated ? '관련' : '비관련'),
        voc.businessScore,
      ),
      _MetricData('분류', voc.aiCategory ?? '분석 전', voc.categoryScore),
      _MetricData('긴급도', voc.urgency ?? '분석 전', voc.urgencyScore),
      _MetricData('담당 부서', voc.department ?? '분석 전', voc.departmentScore),
      _MetricData('담당자 추천', voc.assignee ?? '분석 전', voc.assigneeScore),
      _MetricData(
        '중복 가능성',
        voc.duplicateScore == null
            ? '분석 전'
            : '${(voc.duplicateScore! * 100).toStringAsFixed(0)}%',
        voc.duplicateScore,
      ),
      _MetricData(
        'JIRA 판단',
        voc.jiraScore == null
            ? '분석 전'
            : (voc.jiraRequired ? '필요' : '불필요'),
        voc.jiraScore,
      ),
    ];

    return _Panel(
      title: 'AI 분석 결과',
      icon: Icons.analytics_outlined,
      subtitle: '분석 결과와 AI의 판단 신뢰도를 구분해 표시합니다.',
      trailing: OutlinedButton.icon(
        onPressed: _running ? null : _run,
        icon: _running
            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.refresh_outlined, size: 18),
        label: Text(_running ? '분석 중' : 'AI 분석 실행'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = widget.desktop ? (constraints.maxWidth > 1200 ? 4 : 3) : 2;
              const gap = 10.0;
              final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: metrics
                    .map((item) => SizedBox(width: width, child: _MetricTile(data: item)))
                    .toList(),
              );
            },
          ),
          if (voc.analysisReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ReasonBox(text: voc.analysisReason!),
          ],
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.confidence);
  final String label;
  final String value;
  final double? confidence;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});
  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final confidence = data.confidence == null
        ? '신뢰도 분석 전'
        : '신뢰도 ${(data.confidence! * 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 5),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            confidence,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ReasonBox extends StatelessWidget {
  const _ReasonBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 19, color: cs.secondary),
          const SizedBox(width: 9),
          Expanded(child: Text('판단 근거 · $text', style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}

class _AiAnswerEntry extends StatelessWidget {
  const _AiAnswerEntry({required this.voc});
  final VocEntity voc;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'AI 답변 추천',
      subtitle: '유사 VOC와 지식베이스 근거를 확인한 뒤 답변을 생성합니다.',
      icon: Icons.auto_awesome_outlined,
      trailing: FilledButton.icon(
        onPressed: () {
          context.read<AiViewModel>().clearResults();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AiAnswerScreen(
                vocId: voc.id,
                vocTitle: voc.title,
                vocContent: voc.content,
                category: voc.category,
                customer: voc.customer,
                project: voc.project,
              ),
            ),
          );
        },
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('AI 추천 열기'),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class _RejectBanner extends StatelessWidget {
  const _RejectBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI 분석 결과 업무 관련 VOC로 분류되지 않았습니다.',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsesWorkspace extends StatefulWidget {
  const _ResponsesWorkspace({required this.voc, required this.vm, required this.desktop});
  final VocEntity voc;
  final VocViewModel vm;
  final bool desktop;

  @override
  State<_ResponsesWorkspace> createState() => _ResponsesWorkspaceState();
}

class _ResponsesWorkspaceState extends State<_ResponsesWorkspace> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responses = widget.vm.responses;
    final userName = context.watch<SettingsViewModel>().userName;
    final existing = Column(
      children: responses
          .map(
            (response) => _ResponseCard(
              response: response,
              onEdit: response.isDraft
                  ? () async {
                      final edited = await _editResponse(context, response.content);
                      if (edited == null) return;
                      final updated = await widget.vm.updateResponseContent(
                        responseId: response.id,
                        content: edited,
                      );
                      if (updated != null && context.mounted) {
                        await context.read<IntegrationViewModel>().forwardVocChangeToPeerApps(
                              voc: widget.vm.selectedVoc ?? widget.voc,
                              event: 'response.updated',
                              response: updated,
                            );
                      }
                    }
                  : null,
              onApprove: response.isDraft
                  ? () async {
                      await widget.vm.approveResponse(response.id, userName);
                      final stored = widget.vm.responses.firstWhere(
                        (item) => item.id == response.id,
                        orElse: () => response,
                      );
                      if (!context.mounted) return;
                      await context.read<IntegrationViewModel>().forwardVocChangeToPeerApps(
                            voc: widget.vm.selectedVoc ?? widget.voc,
                            event: 'response.approved',
                            response: stored,
                          );
                      await context.read<IntegrationViewModel>().publishApprovedToConfluence(
                            voc: widget.voc,
                            approvedAnswer: stored.content,
                          );
                    }
                  : null,
            ),
          )
          .toList(),
    );

    final composer = _Panel(
      title: '새 답변 작성',
      icon: Icons.edit_note_outlined,
      child: Column(
        children: [
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 9,
            decoration: const InputDecoration(
              hintText: '답변 내용을 작성해 주세요.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                final text = _controller.text.trim();
                if (text.isEmpty) return;
                final created = await widget.vm.createDraftResponse(
                  vocId: widget.voc.id,
                  content: text,
                );
                if (!context.mounted) return;
                await context.read<IntegrationViewModel>().forwardVocChangeToPeerApps(
                      voc: widget.vm.selectedVoc ?? widget.voc,
                      event: 'response.created',
                      response: created,
                    );
                _controller.clear();
              },
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('Draft 저장'),
            ),
          ),
        ],
      ),
    );

    return _Panel(
      title: '답변 워크스페이스',
      subtitle: '기존 답변을 검토하거나 새 답변을 작성합니다.',
      icon: Icons.forum_outlined,
      child: widget.desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: responses.isEmpty ? const _EmptyResponses() : existing,
                ),
                const SizedBox(width: 16),
                Expanded(flex: 5, child: composer),
              ],
            )
          : Column(
              children: [
                if (responses.isEmpty) const _EmptyResponses() else existing,
                const SizedBox(height: 12),
                composer,
              ],
            ),
    );
  }

  Future<String?> _editResponse(BuildContext context, String initial) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('답변 수정'),
        content: SizedBox(
          width: 620,
          child: TextField(controller: controller, minLines: 5, maxLines: 9),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('저장')),
        ],
      ),
    );
    controller.dispose();
    return value == null || value.isEmpty ? null : value;
  }
}

class _EmptyResponses extends StatelessWidget {
  const _EmptyResponses();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.chat_bubble_outline, size: 34, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          const Text('등록된 답변이 없습니다.'),
        ],
      ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.response, this.onEdit, this.onApprove});
  final ResponseEntity response;
  final VoidCallback? onEdit;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final approved = response.status == AppConstants.responseApproved;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      color: approved ? cs.secondaryContainer.withValues(alpha: .38) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (response.aiGenerated)
                  const Chip(label: Text('AI'), visualDensity: VisualDensity.compact),
                Chip(
                  label: Text(approved ? '승인됨' : 'Draft'),
                  visualDensity: VisualDensity.compact,
                ),
                if (response.confidenceScore != null)
                  Text(
                    '신뢰도 ${(response.confidenceScore! * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (onEdit != null)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('수정'),
                  ),
                if (onApprove != null)
                  TextButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_outlined, size: 16),
                    label: const Text('승인'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(response.content, style: const TextStyle(height: 1.55)),
            if (approved && response.approvedBy != null) ...[
              const SizedBox(height: 8),
              Text('승인: ${response.approvedBy}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollaborationActions extends StatelessWidget {
  const _CollaborationActions({required this.voc, required this.responses});
  final VocEntity voc;
  final List<ResponseEntity> responses;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IntegrationViewModel>();
    ResponseEntity? responseToShare;
    for (final response in responses) {
      if (response.status == AppConstants.responseApproved) {
        responseToShare = response;
        break;
      }
    }
    responseToShare ??= responses.isEmpty ? null : responses.first;
    final answer = responseToShare?.content ?? '';
    final urgent = (voc.urgency ?? '').toLowerCase();
    final isUrgent = urgent == 'high' || urgent == 'critical' || urgent.contains('긴급');
    return _Panel(
      title: '협업 연동',
      subtitle: '필요한 경우에만 외부 채널로 공유합니다.',
      icon: Icons.share_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: !isUrgent || vm.isLoading
                ? null
                : () => context.read<IntegrationViewModel>().notifyUrgentVocToTeams(voc),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Teams 긴급 알림'),
          ),
          OutlinedButton.icon(
            onPressed: answer.isEmpty || vm.isLoading
                ? null
                : () => context.read<IntegrationViewModel>().shareAiAnswerToTeams(
                      voc: voc,
                      answer: answer,
                    ),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Teams 답변 공유'),
          ),
          OutlinedButton.icon(
            onPressed: vm.isLoading
                ? null
                : () => context.read<IntegrationViewModel>().shareVocToSlack(voc: voc),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Slack VOC 공유'),
          ),
          OutlinedButton.icon(
            onPressed: answer.isEmpty || vm.isLoading
                ? null
                : () => context.read<IntegrationViewModel>().shareAiAnswerToSlack(
                      voc: voc,
                      answer: answer,
                    ),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Slack 답변 공유'),
          ),
          if (vm.error != null)
            SizedBox(
              width: double.infinity,
              child: Text(vm.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (vm.success != null)
            SizedBox(
              width: double.infinity,
              child: Text(vm.success!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
        ],
      ),
    );
  }
}

class _JiraSection extends StatelessWidget {
  const _JiraSection({required this.vocId, required this.vocTitle, required this.vocContent});
  final String vocId;
  final String vocTitle;
  final String vocContent;

  @override
  Widget build(BuildContext context) {
    return Consumer<JiraViewModel>(
      builder: (context, vm, _) {
        if (!vm.isConfigured) return const SizedBox.shrink();
        return _Panel(
          title: 'JIRA 연동',
          subtitle: vm.vocLinks.isEmpty ? '연결된 JIRA 이슈가 없습니다.' : '${vm.vocLinks.length}개 이슈 연결됨',
          icon: Icons.task_alt_outlined,
          trailing: OutlinedButton.icon(
            onPressed: vm.isLoading ? null : () => _create(context, vm),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('이슈 생성'),
          ),
          child: vm.vocLinks.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  children: vm.vocLinks
                      .map<Widget>(
                        (link) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.link_outlined),
                          title: Text(link.jiraKey),
                          subtitle: Text(link.jiraSummary ?? ''),
                          trailing: Text(link.jiraStatus ?? ''),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }

  Future<void> _create(BuildContext context, JiraViewModel vm) async {
    final result = await vm.createIssueForVoc(
      vocId: vocId,
      summary: '[VOC] $vocTitle',
      description: vocContent,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result != null
              ? 'JIRA 이슈 ${result.jiraKey} 생성 완료'
              : (vm.error ?? 'JIRA 이슈 생성에 실패했습니다.'),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: cs.outline),
          const SizedBox(width: 8),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

String _formatDate(DateTime dt) =>
    '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
