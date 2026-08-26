import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../viewmodels/ai_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';
import '../../../core/utils/user_facing_text.dart';
import '../../../core/utils/voc_display_utils.dart';
import '../../../domain/entities/voc_entity.dart';
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
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AiChatListScreen();
  }
}

class _AiChatListScreen extends StatefulWidget {
  const _AiChatListScreen();

  @override
  State<_AiChatListScreen> createState() => _AiChatListScreenState();
}

class _AiChatListScreenState extends State<_AiChatListScreen> {
  bool _isLoading = true;
  List<AiChatSessionSummary> _sessions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
  }

  Future<void> _loadSessions() async {
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

  Future<void> _createNewSession() async {
    final sessionId = await context.read<AiViewModel>().createChatSession();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AiChatConversationScreen(
          sessionId: sessionId,
          title: '새 채팅',
        ),
      ),
    );
    if (!mounted) return;
    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOC Copilot'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewSession,
        tooltip: '새 채팅',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _ChatSessionEmptyState(onStart: _createNewSession)
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.separated(
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.chat_bubble_outline)),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          session.preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text('${session.messageCount}'),
                        onTap: () => _openSession(session),
                      );
                    },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('VOC Copilot으로 업무 분석을 시작하세요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '저장된 VOC와 해결 지식을 바탕으로 핵심 이슈와 답변 방향을 찾습니다.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
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

class _AiChatConversationScreen extends StatefulWidget {
  final String sessionId;
  final String title;

  const _AiChatConversationScreen({
    required this.sessionId,
    required this.title,
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AiViewModel>().startChatSession(widget.sessionId);
      await _initSpeech();
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
        if (messages.isNotEmpty) {
          _scrollToBottom();
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: Column(
            children: [
              if (vm.chatError != null)
                Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.errorContainer,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          vm.chatError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: '오류 복사',
                        onPressed: () =>
                            _copyText(vm.chatError!, '오류 메시지를 복사했습니다.'),
                        icon: const Icon(Icons.copy_all_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: messages.isEmpty
                    ? _CopilotConversationEmptyState(
                        onSelected: _sendQuickAction)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isUser = message.role == 'user';
                          final vocsById = {
                            for (final voc in vocVm.allVocs)
                              voc.id: voc,
                          };
                          final referencedVocs = message.referencedVocIds
                              .map((id) => vocsById[id])
                              .whereType<VocEntity>()
                              .toList();
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 720),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceVariant,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: isUser
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isUser ? '사용자' : 'AI',
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 6),
                                  SelectableText(
                                    isUser
                                        ? message.content
                                        : UserFacingText.fromAi(message.content),
                                    style: const TextStyle(height: 1.5),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: IconButton(
                                      tooltip: isUser ? '내 메시지 복사' : 'AI 답변 복사',
                                      onPressed: () => _copyText(
                                        isUser
                                            ? message.content
                                            : UserFacingText.fromAi(
                                                message.content),
                                        isUser
                                            ? '메시지를 복사했습니다.'
                                            : 'AI 답변을 복사했습니다.',
                                      ),
                                      icon: const Icon(Icons.content_copy,
                                          size: 16),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  if (!isUser &&
                                      referencedVocs.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: referencedVocs
                                          .map((voc) => ActionChip(
                                                avatar: const Icon(
                                                  Icons.open_in_new,
                                                  size: 15,
                                                ),
                                                label: Text(
                                                  VocDisplayUtils.label(voc),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        VocDetailScreen(
                                                      vocId: voc.id,
                                                    ),
                                                  ),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) {
                            if (!vm.isChatting) {
                              _send();
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: '지원 관련 질문을 입력하세요',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _speechAvailable ? _toggleListening : null,
                        tooltip: _isListening ? '음성 입력 중지' : '음성 입력',
                        icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: vm.isChatting ? null : _send,
                        child: vm.isChatting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
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

class _CopilotConversationEmptyState extends StatelessWidget {
  final ValueChanged<VocCopilotQuickAction> onSelected;
  const _CopilotConversationEmptyState({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Icon(Icons.auto_awesome,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('무엇을 분석할까요?',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '업무 Quick Action을 선택하거나 직접 질문하세요. 답변은 기존 AI 설정과 저장된 VOC를 사용합니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: vocCopilotQuickActions
                    .map(
                      (action) => ActionChip(
                        avatar: Icon(action.icon, size: 18),
                        label: Text(action.label),
                        onPressed: () => onSelected(action),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
