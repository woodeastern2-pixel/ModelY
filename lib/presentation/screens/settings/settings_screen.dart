import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../viewmodels/ai_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/integration_viewmodel.dart';
import '../../viewmodels/knowledge_base_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/voc_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late int _lastAllowedTabIndex;
  bool _aiTabUnlocked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 3);
    _lastAllowedTabIndex = _tabController.index;
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index != 0 && _aiTabUnlocked) {
      _aiTabUnlocked = false;
    }
    _lastAllowedTabIndex = _tabController.index;
  }

  Future<void> _handleTabTap(int index) async {
    if (index != 0) {
      if (_aiTabUnlocked) {
        setState(() => _aiTabUnlocked = false);
      }
      _lastAllowedTabIndex = index;
      return;
    }
    if (_aiTabUnlocked) {
      _lastAllowedTabIndex = index;
      return;
    }

    final restoreIndex = _lastAllowedTabIndex;
    _tabController.animateTo(restoreIndex);
    final granted = await _requestAdminAccess();
    if (!mounted || !granted) return;

    setState(() => _aiTabUnlocked = true);
    _tabController.animateTo(0);
    _lastAllowedTabIndex = 0;
  }

  Future<bool> _requestAdminAccess() async {
    final controller = TextEditingController();
    var obscureText = true;

    final granted = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('관리자 인증'),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: '관리자 패스워드',
                  hintText: '패스워드를 입력하세요',
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(
                      () => obscureText = !obscureText,
                    ),
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  Navigator.pop(dialogContext, controller.text.trim());
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (granted is String) {
      final ok = granted == AppConstants.defaultAdminPassword;
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('관리자 패스워드가 올바르지 않습니다.')),
        );
      }
      return ok;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            _handleTabTap(index);
          },
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'AI 설정'),
            Tab(text: '업무 협업툴 설정'),
            Tab(text: '연동'),
            Tab(text: '일반'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          _AiSettingsTab(),
          _CollaborationToolsSettingsTab(),
          _IntegrationSettingsTab(),
          _GeneralSettingsTab(),
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ProviderCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AiSettingsTab extends StatefulWidget {
  const _AiSettingsTab();

  @override
  State<_AiSettingsTab> createState() => _AiSettingsTabState();
}

class _AiSettingsTabState extends State<_AiSettingsTab> {
  final _temperatureController = TextEditingController();
  final _maxTokensController = TextEditingController();
  final _ollamaUrlController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  final _openAiKeyController = TextEditingController();
  final _openAiModelController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  final _geminiModelController = TextEditingController();
  final _claudeKeyController = TextEditingController();
  final _claudeModelController = TextEditingController();
  final _claudeBaseUrlController = TextEditingController();
  final _faissEndpointController = TextEditingController();
  String _provider = AppConstants.aiProviderOllama;
  bool _obscureKey = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettings());
  }

  void _loadSettings() {
    final vm = context.read<SettingsViewModel>();
    _provider = vm.aiProvider;
    _temperatureController.text = vm.aiTemperature.toString();
    _maxTokensController.text = vm.aiMaxTokens.toString();
    _ollamaUrlController.text = vm.ollamaUrl;
    _ollamaModelController.text = vm.ollamaModel;
    _openAiKeyController.text = vm.openAiKey;
    _openAiModelController.text = vm.openAiModel;
    _geminiKeyController.text = vm.geminiKey;
    _geminiModelController.text = vm.geminiModel;
    _claudeKeyController.text = vm.claudeKey;
    _claudeModelController.text = vm.claudeModel;
    _claudeBaseUrlController.text = vm.claudeBaseUrl;
    _faissEndpointController.text = vm.faissEndpoint;
    setState(() {});
  }

  Map<String, String> _currentSettings() {
    return {
      AppConstants.settingAiProvider: _provider,
      AppConstants.settingAiTemperature: _temperatureController.text.trim(),
      AppConstants.settingAiMaxTokens: _maxTokensController.text.trim(),
      AppConstants.settingOllamaUrl: _ollamaUrlController.text.trim(),
      AppConstants.settingOllamaModel: _ollamaModelController.text.trim(),
      AppConstants.settingOpenAiKey: _openAiKeyController.text.trim(),
      AppConstants.settingOpenAiModel: _openAiModelController.text.trim(),
      AppConstants.settingGeminiKey: _geminiKeyController.text.trim(),
      AppConstants.settingGeminiModel: _geminiModelController.text.trim(),
      AppConstants.settingClaudeKey: _claudeKeyController.text.trim(),
      AppConstants.settingClaudeModel: _claudeModelController.text.trim(),
      AppConstants.settingClaudeBaseUrl: _claudeBaseUrlController.text.trim(),
      AppConstants.settingFaissEndpoint: _faissEndpointController.text.trim(),
    };
  }

  Future<void> _save() async {
    await context.read<SettingsViewModel>().saveSettings(_currentSettings());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 설정이 저장되었습니다')),
      );
    }
  }

  Future<void> _testConnection() async {
    final settingsVm = context.read<SettingsViewModel>();
    final aiVm = context.read<AiViewModel>();
    setState(() => _isTesting = true);
    try {
      await settingsVm.saveSettings(_currentSettings());
      final reply = await aiVm.testConnection();
      if (!mounted) return;
      final normalized = reply.replaceAll(RegExp(r'\s+'), ' ').trim();
      final preview = normalized.length > 120
          ? '${normalized.substring(0, 120)}...'
          : normalized;
      final message = 'AI 통신 테스트 성공\n\n$preview';
      _showTestResultDialog(
        title: 'AI 통신 테스트 성공',
        message: message,
        isError: false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = 'AI 통신 테스트 실패\n\n$e';
      _showTestResultDialog(
        title: 'AI 통신 테스트 실패',
        message: message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  Future<void> _copyTestMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('테스트 메시지를 복사했습니다.')),
    );
  }

  void _showTestResultDialog({
    required String title,
    required String message,
    required bool isError,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: SelectableText(message),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _copyTestMessage(message),
              icon: const Icon(Icons.copy),
              label: const Text('복사'),
            ),
            FilledButton(
              style: isError
                  ? FilledButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _maxTokensController.dispose();
    _ollamaUrlController.dispose();
    _ollamaModelController.dispose();
    _openAiKeyController.dispose();
    _openAiModelController.dispose();
    _geminiKeyController.dispose();
    _geminiModelController.dispose();
    _claudeKeyController.dispose();
    _claudeModelController.dispose();
    _claudeBaseUrlController.dispose();
    _faissEndpointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProviderCard(
            title: 'AI 제공자',
            children: [
              TextField(
                controller: _temperatureController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Temperature',
                  hintText: '0.3',
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxTokensController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Tokens',
                  hintText: '2048',
                  prefixIcon: Icon(Icons.confirmation_num_outlined),
                ),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                title: const Text('Ollama (로컬)'),
                subtitle: const Text('서버 없이 로컬에서 실행'),
                value: AppConstants.aiProviderOllama,
                groupValue: _provider,
                onChanged: (v) => setState(() => _provider = v!),
                dense: true,
              ),
              RadioListTile<String>(
                title: const Text('OpenAI API'),
                subtitle: const Text('GPT 모델 사용 (API Key 필요)'),
                value: AppConstants.aiProviderOpenAi,
                groupValue: _provider,
                onChanged: (v) => setState(() => _provider = v!),
                dense: true,
              ),
              RadioListTile<String>(
                title: const Text('Google Gemini API'),
                subtitle: const Text('Gemini 모델 사용 (API Key 필요)'),
                value: AppConstants.aiProviderGemini,
                groupValue: _provider,
                onChanged: (v) => setState(() => _provider = v!),
                dense: true,
              ),
              RadioListTile<String>(
                title: const Text('Anthropic Claude API'),
                subtitle: const Text('Claude 모델 사용 (API Key / Base URL 필요)'),
                value: AppConstants.aiProviderClaude,
                groupValue: _provider,
                onChanged: (v) => setState(() => _provider = v!),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_provider == AppConstants.aiProviderOllama)
            _ProviderCard(
              title: 'Ollama 설정',
              children: [
                TextField(
                  controller: _ollamaUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Ollama URL',
                    hintText: 'http://localhost:11434',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ollamaModelController,
                  decoration: const InputDecoration(
                    labelText: '모델명',
                    hintText: 'llama3.2',
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                  ),
                ),
              ],
            ),
          if (_provider == AppConstants.aiProviderOpenAi)
            _ProviderCard(
              title: 'OpenAI 설정',
              children: [
                TextField(
                  controller: _openAiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-...',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _openAiModelController,
                  decoration: const InputDecoration(
                    labelText: '모델',
                    hintText: 'gpt-4o-mini',
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                  ),
                ),
              ],
            ),
          if (_provider == AppConstants.aiProviderGemini)
            _ProviderCard(
              title: 'Gemini 설정',
              children: [
                TextField(
                  controller: _geminiKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'AIza...',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _geminiModelController,
                  decoration: const InputDecoration(
                    labelText: '모델',
                    hintText: 'gemini-1.5-flash',
                    prefixIcon: Icon(Icons.auto_awesome_outlined),
                  ),
                ),
              ],
            ),
          if (_provider == AppConstants.aiProviderClaude)
            _ProviderCard(
              title: 'Claude 설정',
              children: [
                TextField(
                  controller: _claudeBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://api.anthropic.com/v1',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claudeKeyController,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'sk-ant-...',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claudeModelController,
                  decoration: const InputDecoration(
                    labelText: '모델',
                    hintText: 'claude-3-5-sonnet-latest',
                    prefixIcon: Icon(Icons.smart_toy_outlined),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _ProviderCard(
            title: 'FAISS 브릿지 (선택)',
            children: [
              const Text(
                '비워두면 앱 내부 코사인 검색을 사용합니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _faissEndpointController,
                decoration: const InputDecoration(
                  labelText: 'FAISS Endpoint',
                  hintText: 'http://127.0.0.1:8787',
                  prefixIcon: Icon(Icons.hub_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('AI 설정 저장'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_outlined),
                  label: Text(_isTesting ? '테스트 중...' : 'AI 통신 테스트'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CollaborationToolsSettingsTab extends StatefulWidget {
  const _CollaborationToolsSettingsTab();

  @override
  State<_CollaborationToolsSettingsTab> createState() =>
      _CollaborationToolsSettingsTabState();
}

class _CollaborationToolsSettingsTabState
    extends State<_CollaborationToolsSettingsTab> {
  final _jiraUrlController = TextEditingController();
  final _jiraProjectKeyController = TextEditingController();
  final _jiraTokenController = TextEditingController();
  final _jiraEmailController = TextEditingController();

  final _redmineUrlController = TextEditingController();
  final _redmineProjectController = TextEditingController();
  final _redmineApiKeyController = TextEditingController();

  final _confluenceUrlController = TextEditingController();
  final _confluenceSpaceController = TextEditingController();
  final _confluenceEmailController = TextEditingController();
  final _confluenceTokenController = TextEditingController();

  final _notionWorkspaceController = TextEditingController();
  final _notionDatabaseIdController = TextEditingController();
  final _notionApiKeyController = TextEditingController();

  final _githubRepoController = TextEditingController();
  final _githubTokenController = TextEditingController();

  final _asanaWorkspaceController = TextEditingController();
  final _asanaProjectController = TextEditingController();
  final _asanaTokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SettingsViewModel>();
      _jiraUrlController.text = vm.jiraUrl;
      _jiraProjectKeyController.text = vm.jiraProjectKey;
      _jiraTokenController.text = vm.jiraToken;
      _jiraEmailController.text = vm.jiraEmail;

      _redmineUrlController.text = vm.redmineUrl;
      _redmineProjectController.text = vm.redmineProject;
      _redmineApiKeyController.text = vm.redmineApiKey;

      _confluenceUrlController.text = vm.confluenceUrl;
      _confluenceSpaceController.text = vm.confluenceSpace;
      _confluenceEmailController.text = vm.confluenceEmail;
      _confluenceTokenController.text = vm.confluenceToken;

      _notionWorkspaceController.text = vm.notionWorkspace;
      _notionDatabaseIdController.text = vm.notionDatabaseId;
      _notionApiKeyController.text = vm.notionApiKey;

      _githubRepoController.text = vm.githubRepo;
      _githubTokenController.text = vm.githubToken;

      _asanaWorkspaceController.text = vm.asanaWorkspace;
      _asanaProjectController.text = vm.asanaProject;
      _asanaTokenController.text = vm.asanaToken;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _jiraUrlController.dispose();
    _jiraProjectKeyController.dispose();
    _jiraTokenController.dispose();
    _jiraEmailController.dispose();
    _redmineUrlController.dispose();
    _redmineProjectController.dispose();
    _redmineApiKeyController.dispose();
    _confluenceUrlController.dispose();
    _confluenceSpaceController.dispose();
    _confluenceEmailController.dispose();
    _confluenceTokenController.dispose();
    _notionWorkspaceController.dispose();
    _notionDatabaseIdController.dispose();
    _notionApiKeyController.dispose();
    _githubRepoController.dispose();
    _githubTokenController.dispose();
    _asanaWorkspaceController.dispose();
    _asanaProjectController.dispose();
    _asanaTokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<SettingsViewModel>().saveSettings({
      AppConstants.settingJiraUrl: _jiraUrlController.text.trim(),
      AppConstants.settingJiraProjectKey: _jiraProjectKeyController.text.trim(),
      AppConstants.settingJiraToken: _jiraTokenController.text.trim(),
      AppConstants.settingJiraEmail: _jiraEmailController.text.trim(),
      AppConstants.settingRedmineUrl: _redmineUrlController.text.trim(),
      AppConstants.settingRedmineProject: _redmineProjectController.text.trim(),
      AppConstants.settingRedmineApiKey: _redmineApiKeyController.text.trim(),
      AppConstants.settingConfluenceUrl: _confluenceUrlController.text.trim(),
      AppConstants.settingConfluenceSpace:
          _confluenceSpaceController.text.trim(),
      AppConstants.settingConfluenceEmail:
          _confluenceEmailController.text.trim(),
      AppConstants.settingConfluenceToken:
          _confluenceTokenController.text.trim(),
      AppConstants.settingNotionWorkspace:
          _notionWorkspaceController.text.trim(),
      AppConstants.settingNotionDatabaseId:
          _notionDatabaseIdController.text.trim(),
      AppConstants.settingNotionApiKey: _notionApiKeyController.text.trim(),
      AppConstants.settingGithubRepo: _githubRepoController.text.trim(),
      AppConstants.settingGithubToken: _githubTokenController.text.trim(),
      AppConstants.settingAsanaWorkspace: _asanaWorkspaceController.text.trim(),
      AppConstants.settingAsanaProject: _asanaProjectController.text.trim(),
      AppConstants.settingAsanaToken: _asanaTokenController.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업무 협업툴 설정이 저장되었습니다')),
      );
    }
  }

  Widget _spacer() => const SizedBox(height: 10);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ProviderCard(
            title: 'JIRA 연동',
            children: [
              TextField(
                controller: _jiraUrlController,
                decoration: const InputDecoration(
                  labelText: 'JIRA URL',
                  hintText: 'https://your-domain.atlassian.net',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _jiraProjectKeyController,
                decoration: const InputDecoration(
                  labelText: 'Project Key',
                  hintText: 'VOC',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _jiraEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _jiraTokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProviderCard(
            title: 'Redmine 설정 (API 연동 미지원)',
            children: [
              TextField(
                controller: _redmineUrlController,
                decoration: const InputDecoration(
                  labelText: 'Redmine URL',
                  hintText: 'https://redmine.company.com',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _redmineProjectController,
                decoration: const InputDecoration(
                  labelText: 'Project Identifier',
                  hintText: 'voc-project',
                  prefixIcon: Icon(Icons.folder_open_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _redmineApiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProviderCard(
            title: 'Confluence 연동',
            children: [
              TextField(
                controller: _confluenceUrlController,
                decoration: const InputDecoration(
                  labelText: 'Confluence URL',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _confluenceSpaceController,
                decoration: const InputDecoration(
                  labelText: 'Confluence Space',
                  prefixIcon: Icon(Icons.space_bar_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _confluenceEmailController,
                decoration: const InputDecoration(
                  labelText: 'Confluence Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _confluenceTokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confluence Token',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProviderCard(
            title: 'Notion 설정 (API 연동 미지원)',
            children: [
              TextField(
                controller: _notionWorkspaceController,
                decoration: const InputDecoration(
                  labelText: 'Workspace',
                  prefixIcon: Icon(Icons.workspaces_outline),
                ),
              ),
              _spacer(),
              TextField(
                controller: _notionDatabaseIdController,
                decoration: const InputDecoration(
                  labelText: 'Database ID',
                  prefixIcon: Icon(Icons.table_chart_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _notionApiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Integration Token',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProviderCard(
            title: 'GitHub Issues 설정 (API 연동 미지원)',
            children: [
              TextField(
                controller: _githubRepoController,
                decoration: const InputDecoration(
                  labelText: 'Repository',
                  hintText: 'owner/repo',
                  prefixIcon: Icon(Icons.code_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _githubTokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProviderCard(
            title: 'Asana 설정 (API 연동 미지원)',
            children: [
              TextField(
                controller: _asanaWorkspaceController,
                decoration: const InputDecoration(
                  labelText: 'Workspace',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _asanaProjectController,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  prefixIcon: Icon(Icons.folder_special_outlined),
                ),
              ),
              _spacer(),
              TextField(
                controller: _asanaTokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Personal Access Token',
                  prefixIcon: Icon(Icons.vpn_key_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('업무 협업툴 설정 저장'),
          ),
        ],
      ),
    );
  }
}

class _IntegrationSettingsTab extends StatefulWidget {
  const _IntegrationSettingsTab();

  @override
  State<_IntegrationSettingsTab> createState() =>
      _IntegrationSettingsTabState();
}

class _IntegrationSettingsTabState extends State<_IntegrationSettingsTab> {
  final _outlookTokenController = TextEditingController();
  final _outlookMailboxController = TextEditingController();
  final _outlookFolderController = TextEditingController();
  final _appInstanceNameController = TextEditingController();
  final _vocForwardTargetsController = TextEditingController();
  final _vocSyncTokenController = TextEditingController();
  final _teamsWebhookController = TextEditingController();
  final _slackWebhookController = TextEditingController();
  final _urgencyThresholdController = TextEditingController();
  bool _vocAutoForwardEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SettingsViewModel>();
      _outlookTokenController.text = vm.outlookAccessToken;
      _outlookMailboxController.text = vm.outlookMailbox;
      _outlookFolderController.text = vm.outlookFolder;
      _appInstanceNameController.text = vm.appInstanceName;
      _vocForwardTargetsController.text =
          vm.vocForwardWebhookTargets.join('\n');
      _vocSyncTokenController.text = vm.vocSyncBearerToken;
      _vocAutoForwardEnabled = vm.vocAutoForwardEnabled;
      _teamsWebhookController.text = vm.teamsWebhook;
      _slackWebhookController.text = vm.slackWebhook;
      _urgencyThresholdController.text = vm.urgencyWebhookThreshold;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _outlookTokenController.dispose();
    _outlookMailboxController.dispose();
    _outlookFolderController.dispose();
    _appInstanceNameController.dispose();
    _vocForwardTargetsController.dispose();
    _vocSyncTokenController.dispose();
    _teamsWebhookController.dispose();
    _slackWebhookController.dispose();
    _urgencyThresholdController.dispose();
    super.dispose();
  }

  Future<void> _saveIntegrationSettings() async {
    final forwardTargets = _vocForwardTargetsController.text
        .split(RegExp(r'[\n,]'))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    await context.read<SettingsViewModel>().saveSettings({
      AppConstants.settingOutlookAccessToken:
          _outlookTokenController.text.trim(),
      AppConstants.settingOutlookMailbox: _outlookMailboxController.text.trim(),
      AppConstants.settingOutlookFolder: _outlookFolderController.text.trim(),
      AppConstants.settingAppInstanceName:
          _appInstanceNameController.text.trim(),
      AppConstants.settingVocAutoForwardEnabled:
          _vocAutoForwardEnabled ? 'true' : 'false',
      AppConstants.settingVocForwardWebhookTargets: forwardTargets.join('\n'),
      AppConstants.settingVocSyncBearerToken:
          _vocSyncTokenController.text.trim(),
      AppConstants.settingTeamsWebhook: _teamsWebhookController.text.trim(),
      AppConstants.settingSlackWebhook: _slackWebhookController.text.trim(),
      AppConstants.settingUrgencyWebhookThreshold:
          _urgencyThresholdController.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연동 설정이 저장되었습니다')),
      );
    }
  }

  Future<void> _importVoc() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.single;
    String? path = file.path;
    if (path == null && file.bytes != null) {
      final tempDir = await getTemporaryDirectory();
      final fileName = file.name.isEmpty
          ? 'import_${DateTime.now().millisecondsSinceEpoch}.xlsx'
          : file.name;
      path = p.join(tempDir.path, fileName);
      await File(path).writeAsBytes(file.bytes!);
    }

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('가져오기 실패: 파일 경로를 확인할 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final strategy = await _showDuplicateStrategyDialog();
    if (strategy == null || !mounted) return;
    final vm = context.read<IntegrationViewModel>();
    final imported =
        await vm.importVocFromFile(path, duplicateStrategy: strategy);
    if (!mounted) return;

    if (imported > 0) {
      context.read<VocViewModel>().loadVocs();
      context.read<DashboardViewModel>().loadDashboard();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('VOC 가져오기 완료: $imported건 반영')),
      );
    } else if (vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.error!),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가져오기 결과: 반영된 VOC가 없습니다.')),
      );
    }

    if (vm.lastImportInvalidRows.isNotEmpty) {
      await _showInvalidRowsDialog(vm.lastImportInvalidRows);
    }
  }

  Future<void> _downloadVocTemplate() async {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    context.read<IntegrationViewModel>().clearMessages();

    try {
      final vm = context.read<IntegrationViewModel>();
      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path, 'VOC_Import_Template_$date.xlsx');
        final out = await vm.exportVocTemplate(tempPath);

        if (out == null) {
          throw Exception(vm.error ?? '템플릿 생성 실패');
        }

        final bytes = await File(out).readAsBytes();
        final saved = await FilePicker.platform.saveFile(
          dialogTitle: 'VOC 템플릿 저장',
          fileName: 'VOC_Import_Template_$date.xlsx',
          bytes: bytes,
          allowedExtensions: const ['xlsx'],
          type: FileType.custom,
        );

        if (!mounted) return;

        if (saved != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('템플릿 저장 완료'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        final docsDir = await getApplicationDocumentsDirectory();
        final fallbackPath =
            p.join(docsDir.path, 'VOC_Import_Template_$date.xlsx');
        await File(out).copy(fallbackPath);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('템플릿 저장 완료(앱 문서 폴더): $fallbackPath'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      String? path = await FilePicker.platform.saveFile(
        dialogTitle: 'VOC 템플릿 저장',
        fileName: 'VOC_Import_Template_$date.xlsx',
        allowedExtensions: const ['xlsx'],
        type: FileType.custom,
      );

      if (path == null) return;

      final parent = Directory(p.dirname(path));
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      final out = await vm.exportVocTemplate(path);
      if (!mounted) return;

      if (out != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('템플릿 저장 완료: $out'),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (vm.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('템플릿 저장 실패: ${vm.error}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('템플릿 저장 오류: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showInvalidRowsDialog(List<String> rows) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가져오기 제외 행 미리보기'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('필수값(VOC 제목/VOC 내용) 누락으로 제외된 행입니다.'),
                const SizedBox(height: 10),
                ...rows.map((row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('- $row'),
                    )),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showDuplicateStrategyDialog() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('중복 VOC 처리 방식'),
        content: const Text('동일한 제목/내용 VOC가 이미 있으면 어떻게 처리할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'append'),
            child: const Text('추가'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'overwrite'),
            child: const Text('덮어쓰기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('건너뛰기'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportVoc() async {
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    context.read<IntegrationViewModel>().clearMessages();

    try {
      final vm = context.read<IntegrationViewModel>();
      if (Platform.isAndroid || Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path, 'VOC_Backup_$date.xlsx');
        final out = await vm.exportVocToExcel(tempPath);

        if (out == null) {
          throw Exception(vm.error ?? 'VOC 백업 생성 실패');
        }

        final bytes = await File(out).readAsBytes();
        final saved = await FilePicker.platform.saveFile(
          dialogTitle: 'VOC 백업 저장',
          fileName: 'VOC_Backup_$date.xlsx',
          bytes: bytes,
          allowedExtensions: const ['xlsx'],
          type: FileType.custom,
        );

        if (!mounted) return;

        if (saved != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('VOC 백업 완료'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        final docsDir = await getApplicationDocumentsDirectory();
        final fallbackPath = p.join(docsDir.path, 'VOC_Backup_$date.xlsx');
        await File(out).copy(fallbackPath);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VOC 백업 완료(앱 문서 폴더): $fallbackPath'),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'VOC 내보내기',
        fileName: 'VOC_Backup_$date.xlsx',
        allowedExtensions: const ['xlsx'],
        type: FileType.custom,
      );
      if (path == null) return;

      final parent = Directory(p.dirname(path));
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      final out = await vm.exportVocToExcel(path);
      if (!mounted) return;

      if (out != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('VOC 백업 완료: $out'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final vm = context.read<IntegrationViewModel>();
        if (vm.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('VOC 백업 실패: ${vm.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('VOC 백업 오류: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<bool> _confirmFullReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('VOC 전체 초기화 확인'),
        content:
            const Text('SQLite 데이터, Vector DB, AI Cache를 모두 삭제합니다. 계속할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IntegrationViewModel>(
      builder: (context, vm, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProviderCard(
                title: '협업도구 연동 설정',
                children: [
                  TextField(
                    controller: _outlookTokenController,
                    decoration: const InputDecoration(
                      labelText: 'Outlook Access Token',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _outlookMailboxController,
                    decoration: const InputDecoration(
                      labelText: 'Outlook Mailbox',
                      hintText: 'user@company.com',
                      prefixIcon: Icon(Icons.account_circle_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _outlookFolderController,
                    decoration: const InputDecoration(
                      labelText: 'Outlook Folder',
                      hintText: 'Inbox',
                      prefixIcon: Icon(Icons.folder_open_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _appInstanceNameController,
                    decoration: const InputDecoration(
                      labelText: '앱 인스턴스 이름',
                      hintText: '예: 2번앱(본사), 지점앱-3',
                      prefixIcon: Icon(Icons.devices_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    value: _vocAutoForwardEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('VOC 등록 시 다른 앱으로 자동 포워딩'),
                    subtitle: const Text('아래 수신 URL 목록으로 동일 VOC를 전송합니다.'),
                    onChanged: (value) {
                      setState(() => _vocAutoForwardEnabled = value);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _vocForwardTargetsController,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'VOC 동기화 수신 URL 목록',
                      hintText:
                          'https://app1.example.com/webhook/voc\nhttps://app3.example.com/webhook/voc',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.sync_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _vocSyncTokenController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'VOC 동기화 Bearer 토큰',
                      hintText: '수신기와 동일한 토큰',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _teamsWebhookController,
                    decoration: const InputDecoration(
                      labelText: 'Teams Webhook URL',
                      prefixIcon: Icon(Icons.notifications_active_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _slackWebhookController,
                    decoration: const InputDecoration(
                      labelText: 'Slack Webhook URL',
                      prefixIcon: Icon(Icons.forum_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urgencyThresholdController,
                    decoration: const InputDecoration(
                      labelText: '긴급 알림 임계치',
                      hintText: 'High',
                      prefixIcon: Icon(Icons.priority_high_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: vm.isLoading ? null : _saveIntegrationSettings,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('연동 설정 저장'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () => vm.collectOutlookAndCreateVoc(top: 20),
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('Outlook 메일로 VOC 수집'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProviderCard(
                title: '데이터 관리',
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: vm.inAppReceiverRunning
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: vm.inAppReceiverRunning
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vm.inAppReceiverRunning
                              ? '수신기 상태: 실행 중 (8788)'
                              : '수신기 상태: 중지/실패',
                          style: TextStyle(
                            color: vm.inAppReceiverRunning
                                ? Colors.green.shade800
                                : Colors.orange.shade900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (vm.inAppReceiverLastError != null) ...[
                          const SizedBox(height: 4),
                          SelectableText(
                            vm.inAppReceiverLastError!,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () async {
                            vm.clearMessages();
                            await vm.forwardFullVocAndManualToPeerApps();
                            if (!mounted) return;
                            final msg = vm.error ?? vm.success;
                            if (msg == null) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor:
                                    vm.error == null ? null : Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                    icon: const Icon(Icons.sync_outlined),
                    label: const Text('전체 VOC/매뉴얼 공유 전송'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () async {
                            final vocVm = context.read<VocViewModel>();
                            final dashboardVm =
                                context.read<DashboardViewModel>();
                            vm.clearMessages();
                            final imported = await vm.pullVocFromPeerApps();
                            if (!mounted) return;

                            if (imported > 0) {
                              await vocVm.loadVocs();
                              await dashboardVm.loadDashboard();
                            }

                            final msg = vm.error ?? vm.success;
                            if (msg == null) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor:
                                    vm.error == null ? null : Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: const Text('상대 앱 VOC 당겨오기 (중복 제거)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading || vm.isBootstrapping
                        ? null
                        : () async {
                            final vocVm = context.read<VocViewModel>();
                            final kbVm = context.read<KnowledgeBaseViewModel>();
                            final dashboardVm =
                                context.read<DashboardViewModel>();
                            vm.clearMessages();
                            final imported = await vm.bootstrapFromPeerApps();
                            if (!mounted) return;

                            if (imported > 0) {
                              await vocVm.loadVocs();
                              await kbVm.loadEntries();
                              await dashboardVm.loadDashboard();
                            }

                            final msg =
                                vm.error ?? vm.bootstrapStatus ?? vm.success;
                            if (msg == null) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor:
                                    vm.error == null ? null : Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                    icon: vm.isBootstrapping
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.handshake_outlined),
                    label: Text(
                      vm.isBootstrapping ? '초기 핸드셰이크 진행 중...' : '초기 핸드셰이크 실행',
                    ),
                  ),
                  if (vm.isSyncingFull) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: vm.syncTotalTargets == 0
                          ? null
                          : vm.syncCompletedTargets / vm.syncTotalTargets,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '진행 ${vm.syncCompletedTargets}/${vm.syncTotalTargets}'
                      '${vm.syncCurrentTarget == null ? '' : ' · ${vm.syncCurrentTarget}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading || vm.syncRetryQueueCount == 0
                        ? null
                        : () async {
                            vm.clearMessages();
                            await vm.retryPendingSyncQueue();
                            if (!mounted) return;
                            final msg = vm.error ?? vm.success;
                            if (msg == null) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor:
                                    vm.error == null ? null : Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          },
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text('실패 동기화 재시도 (${vm.syncRetryQueueCount})'),
                  ),
                  if (vm.syncRuntimeLogs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '동기화 실행 로그',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final text = vm.syncRuntimeLogs.join('\n');
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('실행 로그를 복사했습니다.')),
                            );
                          },
                          child: const Text('복사'),
                        ),
                        TextButton(
                          onPressed: vm.clearSyncRuntimeLogs,
                          child: const Text('지우기'),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          vm.syncRuntimeLogs.join('\n'),
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),
                  ],
                  if (vm.recentInboundEvents.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '수신 동기화 이력',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final text = vm.recentInboundEvents.map((event) {
                              final time = DateFormat('MM-dd HH:mm:ss')
                                  .format(event.createdAt.toLocal());
                              final source =
                                  event.sourceApp?.trim().isNotEmpty == true
                                      ? event.sourceApp!.trim()
                                      : 'unknown';
                              final vocs = event.counts['vocs'] ?? 0;
                              final manuals = event.counts['manuals'] ?? 0;
                              return '[$time] ${event.eventType} from $source (VOC $vocs / 매뉴얼 $manuals)';
                            }).join('\n');
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('수신 이력을 복사했습니다.')),
                            );
                          },
                          child: const Text('복사'),
                        ),
                        TextButton(
                          onPressed: vm.clearInboundSyncEvents,
                          child: const Text('지우기'),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.lightBlue.shade100),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: vm.recentInboundEvents.map((event) {
                            final time = DateFormat('MM-dd HH:mm:ss')
                                .format(event.createdAt.toLocal());
                            final source =
                                event.sourceApp?.trim().isNotEmpty == true
                                    ? event.sourceApp!.trim()
                                    : 'unknown';
                            final vocs = event.counts['vocs'] ?? 0;
                            final manuals = event.counts['manuals'] ?? 0;
                            final status = event.status ?? 'unknown';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SelectableText(
                                '[$time] ${event.eventType} / $status\n'
                                'source: $source\n'
                                'VOC $vocs건, 매뉴얼 $manuals건\n'
                                '${event.message ?? ''}',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () {
                            vm.clearMessages();
                            _downloadVocTemplate();
                          },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('VOC 템플릿 다운로드'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () {
                            vm.clearMessages();
                            _importVoc();
                          },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('VOC 가져오기'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () {
                            vm.clearMessages();
                            _exportVoc();
                          },
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('VOC 내보내기'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () {
                            vm.clearMessages();
                            vm.rebuildVectorDb();
                          },
                    icon: const Icon(Icons.schema_outlined),
                    label: const Text('Vector DB 재생성'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () {
                            vm.clearMessages();
                            vm.clearAiCache();
                          },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('AI 캐시 초기화'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () async {
                            final confirmed = await _confirmFullReset();
                            if (!confirmed || !mounted) return;
                            context
                                .read<IntegrationViewModel>()
                                .clearMessages();
                            await vm.clearAllVocData();
                          },
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('VOC 전체 초기화'),
                  ),
                ],
              ),
              if (vm.lastSyncErrorDetails != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              '동기화 실패 상세',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: vm.lastSyncErrorDetails!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('실패 상세를 복사했습니다.')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('복사'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        vm.lastSyncErrorDetails!,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
              if (vm.error != null) ...[
                const SizedBox(height: 12),
                Text(vm.error!, style: const TextStyle(color: Colors.red)),
              ],
              if (vm.success != null) ...[
                const SizedBox(height: 12),
                Text(vm.success!, style: const TextStyle(color: Colors.green)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GeneralSettingsTab extends StatefulWidget {
  const _GeneralSettingsTab();

  @override
  State<_GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends State<_GeneralSettingsTab> {
  final _userNameController = TextEditingController();
  final _projectCodesController = TextEditingController();
  final _businessTypeOptionsController = TextEditingController();
  final _projectNameOptionsController = TextEditingController();
  final _textScaleOptions = const [
    0.9,
    1.0,
    1.1,
    1.2,
    1.3,
    1.4,
    1.5,
    1.6,
    1.7,
    1.8
  ];
  double _textScaleFactor = 1.0;
  bool _aiAutoAnswerOnRegister = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SettingsViewModel>();
      _userNameController.text = vm.userName;
      _projectCodesController.text = vm.projectCodes.join(', ');
      _businessTypeOptionsController.text = vm.businessTypeOptions.join(', ');
      _projectNameOptionsController.text = vm.projectNameOptions.join(', ');
      _textScaleFactor = vm.textScaleFactor;
      _aiAutoAnswerOnRegister = vm.aiAutoAnswerOnVocRegister;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _projectCodesController.dispose();
    _businessTypeOptionsController.dispose();
    _projectNameOptionsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final projectCodes = _projectCodesController.text
        .split(',')
        .map((value) => value.trim().toUpperCase())
        .where((value) => value.isNotEmpty)
        .toList();
    final businessTypeOptions = _businessTypeOptionsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final projectNameOptions = _projectNameOptionsController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    await context.read<SettingsViewModel>().saveSettings({
      AppConstants.settingUserName: _userNameController.text.trim(),
      AppConstants.settingCustomCategories: '',
      AppConstants.settingProjectCodes: projectCodes.join(', '),
      AppConstants.settingBusinessTypeOptions: businessTypeOptions.join(', '),
      AppConstants.settingProjectNameOptions: projectNameOptions.join(', '),
      AppConstants.settingTextScale: _textScaleFactor.toStringAsFixed(1),
      AppConstants.settingAiAutoAnswerOnVocRegister:
          _aiAutoAnswerOnRegister ? 'true' : 'false',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일반 설정이 저장되었습니다')),
      );
    }
  }

  Future<void> _reassignAllCategories() async {
    final totalCount = context.read<VocViewModel>().allVocs.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('카테고리 일괄 지정'),
        content: const Text(
          '기존 VOC 전체를 스캔해서 허용된 15개 카테고리로 다시 지정합니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('재지정 실행'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final updatedCount =
        await context.read<VocViewModel>().reassignAllVocCategories();
    await context.read<DashboardViewModel>().loadDashboard();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '재지정 완료: 변경 $updatedCount건, 유지 ${totalCount - updatedCount}건',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final vocVm = context.watch<VocViewModel>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _ProviderCard(
        title: '일반 설정',
        children: [
          TextField(
            controller: _userNameController,
            decoration: const InputDecoration(
              labelText: '담당자 이름',
              hintText: '홍길동',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'VOC 카테고리 체계',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            child: Text(AppConstants.defaultCategories.join(', ')),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                vocVm.isBulkRecategorizing ? null : _reassignAllCategories,
            icon: vocVm.isBulkRecategorizing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(
              vocVm.isBulkRecategorizing ? '카테고리 재지정 중...' : '카테고리 일괄 지정',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '고정 카테고리 15개만 사용하며, 기존 VOC는 이 버튼으로 다시 분류합니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _projectCodesController,
            decoration: const InputDecoration(
              labelText: '프로젝트 코드 목록',
              hintText: 'GVBSO, ABCD, MOBILE',
              prefixIcon: Icon(Icons.tag_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _businessTypeOptionsController,
            decoration: const InputDecoration(
              labelText: '업무 구분 옵션 목록',
              hintText: '메일, 유저, 미팅, 메신저, Aipage',
              prefixIcon: Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _projectNameOptionsController,
            decoration: const InputDecoration(
              labelText: '프로젝트명 옵션 목록',
              hintText: 'BW서비스운영',
              prefixIcon: Icon(Icons.folder_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<double>(
            value: _textScaleOptions.contains(_textScaleFactor)
                ? _textScaleFactor
                : 1.0,
            decoration: const InputDecoration(
              labelText: '글씨 크기',
              prefixIcon: Icon(Icons.text_fields),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            items: _textScaleOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('${value.toStringAsFixed(1)}x'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _textScaleFactor = value);
              context.read<SettingsViewModel>().saveSetting(
                  AppConstants.settingTextScale, value.toStringAsFixed(1));
            },
          ),
          const SizedBox(height: 12),
          // 테마 모드 선택
          DropdownButtonFormField<String>(
            value: vm.themeModeString,
            decoration: const InputDecoration(
              labelText: '테마',
              prefixIcon: Icon(Icons.palette_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'light', child: Text('🌞 라이트 모드')),
              DropdownMenuItem(value: 'dark', child: Text('🌙 다크 모드')),
            ],
            onChanged: (value) {
              if (value != null) {
                context
                    .read<SettingsViewModel>()
                    .saveSetting(AppConstants.settingThemeMode, value);
              }
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: _aiAutoAnswerOnRegister,
            title: const Text('VOC 등록 후 AI 답변 자동 생성'),
            subtitle: const Text('끄면 수동 모드로 동작하며, 등록 후 생성 여부를 선택합니다.'),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() => _aiAutoAnswerOnRegister = value);
              context.read<SettingsViewModel>().saveSetting(
                    AppConstants.settingAiAutoAnswerOnVocRegister,
                    value ? 'true' : 'false',
                  );
            },
          ),
          const SizedBox(height: 12),
          Text('현재 카테고리: ${vm.allCategories.join(', ')}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('일반 설정 저장'),
          ),
        ],
      ),
    );
  }
}
