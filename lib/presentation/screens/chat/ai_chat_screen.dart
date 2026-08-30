import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/user_facing_text.dart';
import '../../../core/utils/voc_display_utils.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../viewmodels/ai_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';
import '../../widgets/workspace_ui.dart';
import '../voc/voc_detail_screen.dart';

class VocCopilotQuickAction {
  final String label;
  final String prompt;
  final IconData icon;

  const VocCopilotQuickAction(this.label, this.prompt, this.icon);
}

const vocCopilotQuickActions = <VocCopilotQuickAction>[
  VocCopilotQuickAction(
    '오늘의 핵심 이슈',
    '오늘의 VOC 핵심 이슈를 중요도와 근거가 되는 VOC 중심으로 요약해줘.',
    Icons.today_outlined,
  ),
  VocCopilotQuickAction(
    '미처리 VOC 분석',
    '현재 미처리 VOC를 분석하고 우선 대응할 항목과 이유를 정리해줘.',
    Icons.pending_actions_outlined,
  ),
  VocCopilotQuickAction(
    '반복 불만 찾기',
    '반복되는 고객 불만과 유사 VOC를 찾아 공통 원인과 대응 방향을 알려줘.',
    Icons.repeat_outlined,
  ),
  VocCopilotQuickAction(
    '긴급 VOC 우선순위',
    '긴급 VOC의 처리 우선순위를 분석하고 우선순위별 근거를 설명해줘.',
    Icons.priority_high,
  ),
  VocCopilotQuickAction(
    '경영진 보고 요약',
    '현재 VOC 현황을 경영진 보고용으로 핵심 이슈, 영향, 권고 조치 순서로 작성해줘.',
    Icons.summarize_outlined,
  ),
];

class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key, this.previewSessions});

  /// Deterministic sessions for the responsive render harness.
  final List<AiChatSessionSummary>? previewSessions;

  @override
  Widget build(BuildContext context) {
    return _AiChatListScreen(previewSessions: previewSessions);
  }
}

class _AiChatListScreen extends StatefulWidget {
  const _AiChatListScreen({this.previewSessions});

  final List<AiChatSessionSummary>? previewSessions;

  @override
  State<_AiChatListScreen> createState() => _AiChatListScreenState();
}

class _AiChatListScreenState extends State<_AiChatListScreen> {
  bool _isLoading = true;
  List<AiChatSessionSummary> _sessions = [];

  @override
  void initState() {
    super.initState();
    final preview = widget.previewSessions;
    if (preview != null) {
      _sessions = preview;
      _isLoading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
    }
  }

  Future<void> _loadSessions() async {
    if (widget.previewSessions != null) return;
    setState(() => _isLoading = true);
    final sessions = await context.read<AiViewModel>().loadChatSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _openSession(AiChatSessionSummary session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AiChatConversationScreen(
          sessionId: session.sessionId,
          title: session.title,
        ),
      ),
    );
    if (!mounted) return;
    await _loadSessions();
  }

  Future<void> _createNewSession([VocCopilotQuickAction? initialAction]) async {
    final sessionId = await context.read<AiViewModel>().createChatSession();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AiChatConversationScreen(
          sessionId: sessionId,
          title: '새 채팅',
          initialAction: initialAction,
        ),
      ),
    );
    if (!mounted) return;
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.visualColors.canvas,
      appBar: AppBar(
        title: const Text('AI 코파일럿'),
        actions: [
          IconButton(
            onPressed: _loadSessions,
            tooltip: '대화 새로고침',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: CustomScrollView(
                    key: const Key('copilot-home-scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: WorkspaceHero(
                            key: const Key('copilot-home-hero'),
                            eyebrow: 'VOC COPILOT',
                            title: '저장된 VOC에 바로 질문하세요.',
                            description:
                                '고객 신호와 해결 지식을 근거로 우선순위, 반복 이슈, 보고용 요약을 만듭니다.',
                            icon: Icons.auto_awesome_rounded,
                            metrics: [
                              WorkspaceMetric(
                                label: '분석 대화',
                                value: '${_sessions.length}',
                              ),
                              const WorkspaceMetric(
                                label: 'Quick Action',
                                value: '5',
                                color: Color(0xFFBFC2FF),
                              ),
                              const WorkspaceMetric(
                                label: '근거',
                                value: 'VOC',
                                color: Color(0xFF55CDBE),
                              ),
                            ],
                            actions: [
                              FilledButton.icon(
                                key: const Key('copilot-new-session'),
                                onPressed: _createNewSession,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppPalette.ink,
                                ),
                                icon: const Icon(Icons.add_comment_outlined),
                                label: const Text('새 분석 시작'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _CopilotLaunchpad(
                            onSelected: (action) => _createNewSession(action),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _sessions.isEmpty
                              ? _ChatSessionEmptyState(
                                  onStart: _createNewSession,
                                )
                              : _SessionWorkspace(
                                  sessions: _sessions,
                                  onOpen: _openSession,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ChatSessionEmptyState extends StatelessWidget {
  final VoidCallback onStart;
  const _ChatSessionEmptyState({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      key: const Key('copilot-empty-sessions'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '아직 저장된 분석 대화가 없습니다.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '위 Quick Action을 선택하거나 새 분석을 시작해 보세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('새 분석 시작'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopilotLaunchpad extends StatelessWidget {
  const _CopilotLaunchpad({required this.onSelected});

  final ValueChanged<VocCopilotQuickAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      key: const Key('copilot-quick-actions'),
      title: '바로 분석하기',
      description: '자주 쓰는 운영 질문을 실제 VOC 근거와 함께 실행합니다.',
      icon: Icons.bolt_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
                  ? 2
                  : 1;
          const gap = AppSpacing.xs;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: vocCopilotQuickActions
                .map(
                  (action) => SizedBox(
                    width: width,
                    child: _QuickActionTile(
                      action: action,
                      onTap: () => onSelected(action),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final VocCopilotQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: context.visualColors.mutedSurface,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Icon(action.icon, size: 20, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  action.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.arrow_outward, size: 16, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionWorkspace extends StatelessWidget {
  const _SessionWorkspace({required this.sessions, required this.onOpen});

  final List<AiChatSessionSummary> sessions;
  final ValueChanged<AiChatSessionSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return WorkspacePanel(
      key: const Key('copilot-session-list'),
      title: '최근 분석',
      description: '이전 대화와 연결된 VOC 근거를 다시 확인할 수 있습니다.',
      icon: Icons.history,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < sessions.length; index++) ...[
            _SessionRow(
              session: sessions[index],
              onTap: () => onOpen(sessions[index]),
            ),
            if (index != sessions.length - 1)
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onTap});

  final AiChatSessionSummary session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 19,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${session.messageCount}개 메시지',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _sessionDate(session.updatedAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: colors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionDate(DateTime value) =>
    '${value.month.toString().padLeft(2, '0')}.${value.day.toString().padLeft(2, '0')}';

class _AiChatConversationScreen extends StatefulWidget {
  final String sessionId;
  final String title;
  final VocCopilotQuickAction? initialAction;

  const _AiChatConversationScreen({
    required this.sessionId,
    required this.title,
    this.initialAction,
  });

  @override
  State<_AiChatConversationScreen> createState() =>
      _AiChatConversationScreenState();
}

class _AiChatConversationScreenState extends State<_AiChatConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _speechToText = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _initialActionSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AiViewModel>().startChatSession(widget.sessionId);
      await _initSpeech();
      final initialAction = widget.initialAction;
      if (mounted && initialAction != null && !_initialActionSent) {
        _initialActionSent = true;
        await _sendQuickAction(initialAction);
      }
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speechToText.initialize();
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;

    if (_isListening) {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
      _focusNode.requestFocus();
      return;
    }

    final started = await _speechToText.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _controller.text = result.recognizedWords;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      partialResults: true,
      cancelOnError: true,
    );
    if (!mounted) return;
    setState(() => _isListening = started);
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    _controller.clear();
    await context.read<AiViewModel>().sendChatMessage(message);
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  Future<void> _sendQuickAction(VocCopilotQuickAction action) async {
    if (context.read<AiViewModel>().isChatting) return;
    _controller.text = action.prompt;
    await _send();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _copyText(String text, String doneMessage) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(doneMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiViewModel>(
      builder: (context, vm, _) {
        final messages = vm.chatMessages;
        final vocVm = context.watch<VocViewModel>();
        final compact = MediaQuery.sizeOf(context).width < 600;
        if (messages.isNotEmpty) {
          _scrollToBottom();
        }

        return Scaffold(
          backgroundColor: context.visualColors.canvas,
          appBar: AppBar(
            title: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (compact)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: Tooltip(
                    message: 'VOC 근거 기반',
                    child: Icon(Icons.link_rounded),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Chip(
                    avatar: const Icon(Icons.link_rounded, size: 16),
                    label: const Text('VOC 근거 기반'),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            key: const Key('copilot-conversation'),
            children: [
              if (vm.chatError != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: SelectableText(vm.chatError!)),
                      IconButton(
                        tooltip: '오류 복사',
                        onPressed: () => _copyText(
                          vm.chatError!,
                          '오류 메시지를 복사했습니다.',
                        ),
                        icon: const Icon(Icons.copy_all_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: messages.isEmpty
                    ? _CopilotConversationEmptyState(
                        onSelected: _sendQuickAction,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final side = constraints.maxWidth >= 900
                              ? AppSpacing.xl
                              : AppSpacing.md;
                          return ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              side,
                              AppSpacing.lg,
                              side,
                              AppSpacing.xxl,
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isUser = message.role == 'user';
                              final vocsById = {
                                for (final voc in vocVm.allVocs) voc.id: voc,
                              };
                              final referencedVocs = message.referencedVocIds
                                  .map((id) => vocsById[id])
                                  .whereType<VocEntity>()
                                  .toList();
                              return Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 1120),
                                  child: _ConversationMessage(
                                    isUser: isUser,
                                    content: isUser
                                        ? message.content
                                        : UserFacingText.fromAi(
                                            message.content,
                                          ),
                                    referencedVocs: referencedVocs,
                                    onCopy: () => _copyText(
                                      isUser
                                          ? message.content
                                          : UserFacingText.fromAi(
                                              message.content,
                                            ),
                                      isUser
                                          ? '메시지를 복사했습니다.'
                                          : 'AI 답변을 복사했습니다.',
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.visualColors.elevatedSurface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('copilot-message-field'),
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) {
                                if (!vm.isChatting) _send();
                              },
                              decoration: const InputDecoration(
                                hintText: '이 VOC 데이터에서 무엇을 확인할까요?',
                                prefixIcon: Icon(Icons.auto_awesome_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          IconButton.filledTonal(
                            onPressed:
                                _speechAvailable ? _toggleListening : null,
                            tooltip: _isListening ? '음성 입력 중지' : '음성 입력',
                            icon: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          IconButton.filled(
                            key: const Key('copilot-send'),
                            onPressed: vm.isChatting ? null : _send,
                            tooltip: '질문 보내기',
                            icon: vm.isChatting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConversationMessage extends StatelessWidget {
  const _ConversationMessage({
    required this.isUser,
    required this.content,
    required this.referencedVocs,
    required this.onCopy,
  });

  final bool isUser;
  final String content;
  final List<VocEntity> referencedVocs;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 820),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isUser
            ? colors.primaryContainer
            : context.visualColors.elevatedSurface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: isUser ? null : Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isUser ? '나' : 'VOC COPILOT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color:
                          isUser ? colors.onPrimaryContainer : colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: isUser ? 0 : .6,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: isUser ? '내 메시지 복사' : 'AI 답변 복사',
                onPressed: onCopy,
                icon: const Icon(Icons.content_copy_outlined, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(content, style: const TextStyle(height: 1.55)),
          if (!isUser && referencedVocs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '참조 VOC',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: referencedVocs
                  .map(
                    (voc) => ActionChip(
                      avatar: const Icon(Icons.open_in_new, size: 15),
                      label: Text(VocDisplayUtils.label(voc)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VocDetailScreen(vocId: voc.id),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: colors.onPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _CopilotConversationEmptyState extends StatelessWidget {
  final ValueChanged<VocCopilotQuickAction> onSelected;
  const _CopilotConversationEmptyState({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WorkspaceHero(
                key: Key('copilot-conversation-empty'),
                eyebrow: 'EVIDENCE WORKSPACE',
                title: '첫 분석 주제를 선택하세요.',
                description: '저장된 VOC를 탐색해 핵심 이슈와 대응 우선순위를 근거와 함께 정리합니다.',
                icon: Icons.hub_outlined,
                metrics: [
                  WorkspaceMetric(label: '분석 기준', value: 'VOC'),
                  WorkspaceMetric(
                    label: '응답 방식',
                    value: '근거 우선',
                    color: Color(0xFF55CDBE),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _CopilotLaunchpad(
                onSelected: onSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
