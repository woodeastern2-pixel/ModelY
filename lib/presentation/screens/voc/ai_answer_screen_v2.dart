import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/user_facing_text.dart';
import '../../../core/utils/voc_display_utils.dart';
import '../../../domain/entities/knowledge_base_entity.dart';
import '../../viewmodels/ai_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';

class AiAnswerScreen extends StatefulWidget {
  const AiAnswerScreen({
    super.key,
    required this.vocId,
    required this.vocTitle,
    required this.vocContent,
    required this.category,
    required this.customer,
    required this.project,
  });

  final String vocId;
  final String vocTitle;
  final String vocContent;
  final String category;
  final String customer;
  final String project;

  @override
  State<AiAnswerScreen> createState() => _AiAnswerScreenState();
}

class _AiAnswerScreenState extends State<AiAnswerScreen> {
  final _feedbackController = TextEditingController();
  String _answer = '';
  String _feedbackType = 'useful';
  bool _adopting = false;
  bool _feedbackSaving = false;
  int _selectedCase = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPipeline());
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _runPipeline() async {
    final vm = context.read<AiViewModel>();
    await vm.searchSimilarVocs('${widget.vocTitle} ${widget.vocContent}');
    final result = await vm.generateAnswer(widget.vocTitle, widget.vocContent);
    if (!mounted) return;
    setState(() {
      _answer = result?.answer ?? '';
      if (_selectedCase >= vm.similarVocs.length) _selectedCase = 0;
    });
  }

  Future<void> _copy(String text, String message) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _adopt() async {
    final answer = _answer.trim();
    if (answer.isEmpty || _adopting) return;
    setState(() => _adopting = true);
    final aiVm = context.read<AiViewModel>();
    final vocVm = context.read<VocViewModel>();
    try {
      final adopted = await vocVm.adoptAiAnswer(
        vocId: widget.vocId,
        content: answer,
        confidence: aiVm.answerResult?.confidence,
        referencedVocIds: aiVm.similarVocs
            .map((item) => item.knowledgeBase.vocId)
            .whereType<String>()
            .toList(),
      );
      final match = vocVm.allVocs.where((item) => item.id == widget.vocId);
      final voc = match.isNotEmpty ? match.first : vocVm.selectedVoc;
      if (adopted != null && voc != null && mounted) {
        await context.read<IntegrationViewModel>().forwardVocChangeToPeerApps(
              voc: voc,
              event: 'response.approved',
              response: adopted,
            );
      }
      await aiVm.saveToKnowledgeBase(
        question: widget.vocTitle,
        answer: answer,
        category: widget.category,
        customer: widget.customer,
        project: widget.project,
        vocId: widget.vocId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 추천 답변을 채택하고 VOC 답변으로 저장했습니다.')),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _adopting = false);
    }
  }

  Future<void> _saveFeedback() async {
    if (_feedbackSaving) return;
    setState(() => _feedbackSaving = true);
    try {
      await context.read<VocViewModel>().recordAiFeedback(
            vocId: widget.vocId,
            feedbackType: _feedbackType,
            note: _feedbackController.text.trim().isEmpty
                ? null
                : _feedbackController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 피드백을 저장했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _feedbackSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1050;
        return Scaffold(
          appBar: AppBar(title: const Text('AI 답변 추천')),
          body: Consumer<AiViewModel>(
            builder: (context, vm, _) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 28 : 14,
                  desktop ? 22 : 14,
                  desktop ? 28 : 14,
                  48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _VocHeader(
                          title: widget.vocTitle,
                          content: widget.vocContent,
                        ),
                        const SizedBox(height: 16),
                        if (desktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 430,
                                child: _CaseNavigator(
                                  vm: vm,
                                  selectedIndex: _selectedCase,
                                  onSelected: (index) => setState(() => _selectedCase = index),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _AnswerWorkspace(
                                  vm: vm,
                                  answer: _answer,
                                  selectedCase: _selectedCase,
                                  onRegenerate: _runPipeline,
                                  onCopy: () => _copy(_answer, 'AI 추천 답변을 복사했습니다.'),
                                  onAdopt: _adopting ? null : _adopt,
                                  adopting: _adopting,
                                  feedbackType: _feedbackType,
                                  feedbackController: _feedbackController,
                                  feedbackSaving: _feedbackSaving,
                                  onFeedbackTypeChanged: (value) => setState(() => _feedbackType = value),
                                  onFeedbackSave: _saveFeedback,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          _CaseNavigator(
                            vm: vm,
                            selectedIndex: _selectedCase,
                            onSelected: (index) => setState(() => _selectedCase = index),
                          ),
                          const SizedBox(height: 14),
                          _AnswerWorkspace(
                            vm: vm,
                            answer: _answer,
                            selectedCase: _selectedCase,
                            onRegenerate: _runPipeline,
                            onCopy: () => _copy(_answer, 'AI 추천 답변을 복사했습니다.'),
                            onAdopt: _adopting ? null : _adopt,
                            adopting: _adopting,
                            feedbackType: _feedbackType,
                            feedbackController: _feedbackController,
                            feedbackSaving: _feedbackSaving,
                            onFeedbackTypeChanged: (value) => setState(() => _feedbackType = value),
                            onFeedbackSave: _saveFeedback,
                          ),
                        ],
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
}

class _VocHeader extends StatelessWidget {
  const _VocHeader({required this.title, required this.content});
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: .25),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: .14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.support_agent_outlined, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(content, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseNavigator extends StatelessWidget {
  const _CaseNavigator({required this.vm, required this.selectedIndex, required this.onSelected});
  final AiViewModel vm;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '유사 사례',
      subtitle: '답변 생성에 참고한 VOC와 지식베이스 후보입니다.',
      icon: Icons.manage_search_outlined,
      child: vm.isSearching
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          : vm.similarVocs.isEmpty
              ? const _EmptyCases()
              : Column(
                  children: List.generate(vm.similarVocs.length, (index) {
                    final item = vm.similarVocs[index];
                    final kb = item.knowledgeBase;
                    final selected = index == selectedIndex;
                    final code = VocDisplayUtils.codeFromProject(kb.project);
                    final manual = kb.category == '시스템매뉴얼' ||
                        kb.project == 'manual-upload' ||
                        kb.question.contains('매뉴얼 섹션');
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == vm.similarVocs.length - 1 ? 0 : 8),
                      child: _CaseRow(
                        selected: selected,
                        title: kb.question,
                        subtitle: manual
                            ? '시스템 매뉴얼'
                            : '${code.isEmpty ? 'VOC 이력' : code} · ${kb.category}',
                        score: item.similarityScore,
                        onTap: () => onSelected(index),
                      ),
                    );
                  }),
                ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final String subtitle;
  final double score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surfaceContainerLow;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ScoreBadge(score: score),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerWorkspace extends StatelessWidget {
  const _AnswerWorkspace({
    required this.vm,
    required this.answer,
    required this.selectedCase,
    required this.onRegenerate,
    required this.onCopy,
    required this.onAdopt,
    required this.adopting,
    required this.feedbackType,
    required this.feedbackController,
    required this.feedbackSaving,
    required this.onFeedbackTypeChanged,
    required this.onFeedbackSave,
  });

  final AiViewModel vm;
  final String answer;
  final int selectedCase;
  final VoidCallback onRegenerate;
  final VoidCallback onCopy;
  final VoidCallback? onAdopt;
  final bool adopting;
  final String feedbackType;
  final TextEditingController feedbackController;
  final bool feedbackSaving;
  final ValueChanged<String> onFeedbackTypeChanged;
  final VoidCallback onFeedbackSave;

  @override
  Widget build(BuildContext context) {
    final safeIndex = selectedCase < 0
        ? 0
        : selectedCase >= vm.similarVocs.length
            ? vm.similarVocs.length - 1
            : selectedCase;
    final selected = vm.similarVocs.isEmpty ? null : vm.similarVocs[safeIndex];
    return Column(
      children: [
        _Panel(
          title: 'AI 추천 답변',
          subtitle: '근거에 없는 내용은 최종 채택 전에 반드시 확인하세요.',
          icon: Icons.auto_awesome_outlined,
          trailing: Wrap(
            spacing: 4,
            children: [
              if (vm.answerResult != null) _ScoreBadge(score: vm.answerResult!.confidence),
              IconButton(onPressed: answer.trim().isEmpty ? null : onCopy, tooltip: '답변 복사', icon: const Icon(Icons.copy_outlined)),
              IconButton(onPressed: vm.isGenerating ? null : onRegenerate, tooltip: '재생성', icon: const Icon(Icons.refresh)),
            ],
          ),
          child: vm.isGenerating
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 38),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('근거를 바탕으로 답변을 생성하고 있습니다.'),
                      ],
                    ),
                  ),
                )
              : vm.error != null
                  ? _ErrorBox(message: vm.error!)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          answer.trim().isEmpty ? '생성된 답변이 없습니다.' : UserFacingText.fromAi(answer),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
                        ),
                        if (vm.answerResult?.notes.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          _NoteBox(text: UserFacingText.fromAi(vm.answerResult!.notes)),
                        ],
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: answer.trim().isEmpty ? null : onAdopt,
                            icon: adopting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('답변 채택'),
                          ),
                        ),
                      ],
                    ),
        ),
        const SizedBox(height: 14),
        if (selected != null) _SelectedEvidence(item: selected),
        const SizedBox(height: 14),
        _FeedbackPanel(
          type: feedbackType,
          controller: feedbackController,
          saving: feedbackSaving,
          onTypeChanged: onFeedbackTypeChanged,
          onSave: onFeedbackSave,
        ),
      ],
    );
  }
}

class _SelectedEvidence extends StatelessWidget {
  const _SelectedEvidence({required this.item});
  final SimilarVocResult item;

  @override
  Widget build(BuildContext context) {
    final kb = item.knowledgeBase;
    final adoption = item.adoptionCount ?? 0;
    final usage = item.usageCount ?? 0;
    final rate = usage == 0 ? 0.0 : adoption / usage * 100;
    final manual = kb.category == '시스템매뉴얼' ||
        kb.project == 'manual-upload' ||
        kb.question.contains('매뉴얼 섹션');
    final code = VocDisplayUtils.codeFromProject(kb.project);
    return _Panel(
      title: '선택한 답변 근거',
      subtitle: manual
          ? '시스템 매뉴얼'
          : '${code.isEmpty ? 'VOC 이력' : code} · 유사도 ${(item.similarityScore * 100).toStringAsFixed(1)}%',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kb.question, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SelectableText(UserFacingText.fromAi(kb.answer), style: const TextStyle(height: 1.55)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text('유사도 ${(item.similarityScore * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall),
              Text('채택률 ${rate.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall),
              if (item.lastUsedAt != null)
                Text(
                  '최근 사용 ${item.lastUsedAt!.year}-${item.lastUsedAt!.month.toString().padLeft(2, '0')}-${item.lastUsedAt!.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackPanel extends StatelessWidget {
  const _FeedbackPanel({
    required this.type,
    required this.controller,
    required this.saving,
    required this.onTypeChanged,
    required this.onSave,
  });
  final String type;
  final TextEditingController controller;
  final bool saving;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'AI 피드백',
      subtitle: '답변 품질 개선을 위해 결과를 평가해 주세요.',
      icon: Icons.feedback_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('도움됨'), selected: type == 'useful', onSelected: (_) => onTypeChanged('useful')),
              ChoiceChip(label: const Text('부분적'), selected: type == 'partial', onSelected: (_) => onTypeChanged('partial')),
              ChoiceChip(label: const Text('부정확'), selected: type == 'wrong', onSelected: (_) => onTypeChanged('wrong')),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '근거가 부족하거나 보완이 필요한 부분을 적어 주세요.'),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 17),
              label: const Text('피드백 저장'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child, this.subtitle, this.trailing});
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
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(11)),
                  child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (score * 100).toStringAsFixed(0);
    final bg = score >= .7
        ? const Color(0xFFE6F6EA)
        : score >= .5
            ? const Color(0xFFFFF2D8)
            : cs.surfaceContainerHigh;
    final fg = score >= .7
        ? const Color(0xFF18743D)
        : score >= .5
            ? const Color(0xFF9A6100)
            : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text('$pct%', style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _EmptyCases extends StatelessWidget {
  const _EmptyCases();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.search_off_outlined, size: 34, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          const Text('참고할 유사 사례가 없습니다.'),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Text(message, style: TextStyle(color: cs.onErrorContainer)),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
      child: Text('추가 확인 · $text', style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
