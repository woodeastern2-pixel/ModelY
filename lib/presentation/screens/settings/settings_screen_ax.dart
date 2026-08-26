import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../viewmodels/ai_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import 'data_management_screen.dart';

class SettingsScreenAx extends StatefulWidget {
  const SettingsScreenAx({super.key});

  @override
  State<SettingsScreenAx> createState() => _SettingsScreenAxState();
}

class _SettingsScreenAxState extends State<SettingsScreenAx> {
  int _section = 3;
  bool _aiUnlocked = false;

  static const _sections = [
    _SectionData('AI 설정', 'AI 연결과 모델', Icons.auto_awesome_outlined),
    _SectionData('업무 도구', 'JIRA와 협업 시스템', Icons.workspaces_outline),
    _SectionData('연동', '메일·동기화·알림', Icons.sync_alt_outlined),
    _SectionData('일반', '사용자·화면·업무 기준', Icons.tune_outlined),
  ];

  Future<bool> _requestAdminAccess() async {
    final controller = TextEditingController();
    var obscure = true;
    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('관리자 인증'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: '관리자 패스워드',
              suffixIcon: IconButton(
                onPressed: () => setDialogState(() => obscure = !obscure),
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              ),
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    final granted = value == AppConstants.defaultAdminPassword;
    if (!granted && value != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('관리자 패스워드가 올바르지 않습니다.')),
      );
    }
    return granted;
  }

  Future<void> _selectSection(int index) async {
    if (index == 0 && !_aiUnlocked) {
      final granted = await _requestAdminAccess();
      if (!mounted || !granted) return;
      setState(() {
        _aiUnlocked = true;
        _section = index;
      });
      return;
    }
    if (index != 0 && _aiUnlocked) {
      setState(() {
        _aiUnlocked = false;
        _section = index;
      });
      return;
    }
    setState(() => _section = index);
  }

  Widget _body() => IndexedStack(
        index: _section,
        children: const [
          _AiSettingsView(),
          _WorkToolsView(),
          _IntegrationView(),
          _GeneralView(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        if (desktop) {
          return _DesktopSettingsShell(
            section: _section,
            sections: _sections,
            onSelect: _selectSection,
            body: _body(),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('설정'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(54),
              child: _MobileSectionBar(
                section: _section,
                sections: _sections,
                onSelect: _selectSection,
              ),
            ),
          ),
          body: _body(),
        );
      },
    );
  }
}

class _SectionData {
  const _SectionData(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class _DesktopSettingsShell extends StatelessWidget {
  const _DesktopSettingsShell({
    required this.section,
    required this.sections,
    required this.onSelect,
    required this.body,
  });

  final int section;
  final List<_SectionData> sections;
  final ValueChanged<int> onSelect;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surface,
      child: Row(
        children: [
          SizedBox(
            width: 270,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                border: Border(right: BorderSide(color: cs.outlineVariant)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '설정',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '필요한 항목만 선택해 관리하세요.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 22),
                    for (var i = 0; i < sections.length; i++) ...[
                      _DesktopSectionTile(
                        data: sections[i],
                        selected: section == i,
                        onTap: () => onSelect(i),
                      ),
                      const SizedBox(height: 6),
                    ],
                    const Spacer(),
                    _InfoNote(
                      icon: Icons.shield_outlined,
                      text: 'AI 설정은 관리자 인증 후 변경할 수 있습니다.',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(30, 22, 30, 18),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      bottom: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(sections[section].icon, color: cs.primary),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sections[section].title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            sections[section].subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSectionTile extends StatelessWidget {
  const _DesktopSectionTile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _SectionData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    return Material(
      color: selected ? cs.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(data.icon, color: fg, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.chevron_right, color: fg, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileSectionBar extends StatelessWidget {
  const _MobileSectionBar({
    required this.section,
    required this.sections,
    required this.onSelect,
  });

  final int section;
  final List<_SectionData> sections;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: SizedBox(
        height: 54,
        child: Row(
          children: List.generate(sections.length, (i) {
            final selected = section == i;
            return Expanded(
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? cs.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    sections[i].title.replaceAll(' 설정', ''),
                    style: TextStyle(
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            desktop ? 30 : 16,
            desktop ? 24 : 16,
            desktop ? 30 : 16,
            42,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (children.isNotEmpty) const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.on, {this.onText = '연결됨', this.offText = '미설정'});
  final bool on;
  final String onText;
  final String offText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = on ? const Color(0xFFE8F7EE) : cs.surfaceContainerHigh;
    final fg = on ? const Color(0xFF177A42) : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        on ? onText : offText,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _AiSettingsView extends StatefulWidget {
  const _AiSettingsView();

  @override
  State<_AiSettingsView> createState() => _AiSettingsViewState();
}

class _AiSettingsViewState extends State<_AiSettingsView> {
  bool _loaded = false;
  bool _advanced = false;
  bool _obscure = true;
  bool _testing = false;
  String _provider = AppConstants.aiProviderOllama;

  final _ollamaUrl = TextEditingController();
  final _ollamaModel = TextEditingController();
  final _openAiKey = TextEditingController();
  final _openAiModel = TextEditingController();
  final _geminiKey = TextEditingController();
  final _geminiModel = TextEditingController();
  final _claudeKey = TextEditingController();
  final _claudeModel = TextEditingController();
  final _claudeBase = TextEditingController();
  final _faiss = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final vm = context.read<SettingsViewModel>();
    _provider = vm.aiProvider;
    _ollamaUrl.text = vm.ollamaUrl;
    _ollamaModel.text = vm.ollamaModel;
    _openAiKey.text = vm.openAiKey;
    _openAiModel.text = vm.openAiModel;
    _geminiKey.text = vm.geminiKey;
    _geminiModel.text = vm.geminiModel;
    _claudeKey.text = vm.claudeKey;
    _claudeModel.text = vm.claudeModel;
    _claudeBase.text = vm.claudeBaseUrl;
    _faiss.text = vm.faissEndpoint;
    _loaded = true;
  }

  @override
  void dispose() {
    for (final controller in [
      _ollamaUrl,
      _ollamaModel,
      _openAiKey,
      _openAiModel,
      _geminiKey,
      _geminiModel,
      _claudeKey,
      _claudeModel,
      _claudeBase,
      _faiss,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> _values() => {
        AppConstants.settingAiProvider: _provider,
        AppConstants.settingOllamaUrl: _ollamaUrl.text.trim(),
        AppConstants.settingOllamaModel: _ollamaModel.text.trim(),
        AppConstants.settingOpenAiKey: _openAiKey.text.trim(),
        AppConstants.settingOpenAiModel: _openAiModel.text.trim(),
        AppConstants.settingGeminiKey: _geminiKey.text.trim(),
        AppConstants.settingGeminiModel: _geminiModel.text.trim(),
        AppConstants.settingClaudeKey: _claudeKey.text.trim(),
        AppConstants.settingClaudeModel: _claudeModel.text.trim(),
        AppConstants.settingClaudeBaseUrl: _claudeBase.text.trim(),
        AppConstants.settingFaissEndpoint: _faiss.text.trim(),
      };

  String get _title => switch (_provider) {
        AppConstants.aiProviderOpenAi => 'OpenAI',
        AppConstants.aiProviderGemini => 'Google Gemini',
        AppConstants.aiProviderClaude => 'Anthropic Claude',
        _ => '사내 · 로컬 AI',
      };

  Widget _secret(TextEditingController controller, String label) => TextField(
        controller: controller,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.key_outlined),
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          ),
        ),
      );

  Widget _fields() {
    switch (_provider) {
      case AppConstants.aiProviderOpenAi:
        return Column(
          children: [
            _secret(_openAiKey, 'API Key'),
            if (_advanced) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _openAiModel,
                decoration: const InputDecoration(labelText: '모델'),
              ),
            ],
          ],
        );
      case AppConstants.aiProviderGemini:
        return Column(
          children: [
            _secret(_geminiKey, 'API Key'),
            if (_advanced) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _geminiModel,
                decoration: const InputDecoration(labelText: '모델'),
              ),
            ],
          ],
        );
      case AppConstants.aiProviderClaude:
        return Column(
          children: [
            _secret(_claudeKey, 'API Key'),
            if (_advanced) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _claudeModel,
                decoration: const InputDecoration(labelText: '모델'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _claudeBase,
                decoration: const InputDecoration(labelText: 'API 주소'),
              ),
            ],
          ],
        );
      default:
        return Column(
          children: [
            TextField(
              controller: _ollamaUrl,
              decoration: const InputDecoration(
                labelText: 'AI 서버 주소',
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            if (_advanced) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _ollamaModel,
                decoration: const InputDecoration(labelText: '모델'),
              ),
            ],
          ],
        );
    }
  }

  Future<void> _save() async {
    await context.read<SettingsViewModel>().saveSettings(_values());
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI 설정을 저장했습니다.')));
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await context.read<SettingsViewModel>().saveSettings(_values());
      final reply = await context.read<AiViewModel>().testConnection();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI 연결 확인 완료'),
          content: SelectableText(reply),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI 연결에 실패했습니다: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      children: [
        Text(
          'VOC 분석과 답변 생성에 사용할 AI 연결 방식을 설정합니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 860;
            final selector = _Panel(
              title: 'AI 제공자',
              subtitle: '조직 환경과 보안 정책에 맞는 방식을 선택하세요.',
              icon: Icons.hub_outlined,
              children: [
                _ProviderRow(
                  title: '사내 · 로컬 AI',
                  subtitle: 'Ollama 또는 내부 AI 서버',
                  icon: Icons.lan_outlined,
                  selected: _provider == AppConstants.aiProviderOllama,
                  onTap: () =>
                      setState(() => _provider = AppConstants.aiProviderOllama),
                ),
                _ProviderRow(
                  title: 'OpenAI',
                  subtitle: 'OpenAI API',
                  icon: Icons.cloud_outlined,
                  selected: _provider == AppConstants.aiProviderOpenAi,
                  onTap: () =>
                      setState(() => _provider = AppConstants.aiProviderOpenAi),
                ),
                _ProviderRow(
                  title: 'Google Gemini',
                  subtitle: 'Google Gemini API',
                  icon: Icons.auto_awesome_outlined,
                  selected: _provider == AppConstants.aiProviderGemini,
                  onTap: () =>
                      setState(() => _provider = AppConstants.aiProviderGemini),
                ),
                _ProviderRow(
                  title: 'Anthropic Claude',
                  subtitle: 'Anthropic Claude API',
                  icon: Icons.psychology_outlined,
                  selected: _provider == AppConstants.aiProviderClaude,
                  onTap: () =>
                      setState(() => _provider = AppConstants.aiProviderClaude),
                ),
              ],
            );
            final details = _Panel(
              title: '$_title 연결 정보',
              subtitle: '일반 사용에 필요한 정보만 우선 표시합니다.',
              icon: Icons.settings_input_component_outlined,
              children: [
                _fields(),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _advanced = !_advanced),
                    icon: Icon(
                        _advanced ? Icons.expand_less : Icons.expand_more),
                    label: Text(
                        _advanced ? '고급 설정 닫기' : '고급 설정 보기'),
                  ),
                ),
                if (_advanced)
                  TextField(
                    controller: _faiss,
                    decoration: const InputDecoration(
                      labelText: '외부 벡터 검색 서버 (선택)',
                      hintText: '비워두면 앱 내부 검색을 사용합니다.',
                    ),
                  ),
              ],
            );
            if (!desktop) {
              return Column(
                children: [
                  selector,
                  const SizedBox(height: 14),
                  details,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: selector),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: details),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: const Icon(Icons.wifi_tethering_outlined),
              label: Text(_testing ? '확인 중...' : '연결 테스트'),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('AI 연결 정보 저장'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected ? cs.primaryContainer : cs.surfaceContainerLow;
    final fg = selected ? cs.onPrimaryContainer : cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Icon(icon, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: selected
                                  ? cs.onPrimaryContainer
                                  : cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? cs.onPrimaryContainer : cs.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolField {
  const _ToolField(this.key, this.label, this.value, {this.secret = false});
  final String key;
  final String label;
  final String value;
  final bool secret;
}

class _ToolData {
  const _ToolData(
    this.name,
    this.description,
    this.icon,
    this.configured,
    this.fields,
  );
  final String name;
  final String description;
  final IconData icon;
  final bool configured;
  final List<_ToolField> fields;
}

class _ToolListRow extends StatelessWidget {
  const _ToolListRow(this.data);
  final _ToolData data;

  Future<void> _edit(BuildContext context) async {
    final controllers = {
      for (final field in data.fields)
        field.key: TextEditingController(text: field.value),
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${data.name} 설정'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: data.fields
                  .map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: controllers[field.key],
                        obscureText: field.secret,
                        decoration: InputDecoration(labelText: field.label),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (saved == true && context.mounted) {
      await context.read<SettingsViewModel>().saveSettings({
        for (final field in data.fields)
          field.key: controllers[field.key]!.text.trim(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${data.name} 설정을 저장했습니다.')),
        );
      }
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _edit(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(data.icon, color: cs.primary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    data.description,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _StatusBadge(data.configured),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _WorkToolsView extends StatelessWidget {
  const _WorkToolsView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final tools = [
      _ToolData(
        'JIRA',
        '이슈 등록 및 상태 연계',
        Icons.task_alt_outlined,
        vm.isJiraConfigured,
        [
          _ToolField(AppConstants.settingJiraUrl, 'JIRA 주소', vm.jiraUrl),
          _ToolField(
              AppConstants.settingJiraProjectKey, '프로젝트 Key', vm.jiraProjectKey),
          _ToolField(AppConstants.settingJiraEmail, '계정 이메일', vm.jiraEmail),
          _ToolField(AppConstants.settingJiraToken, 'API Token', vm.jiraToken,
              secret: true),
        ],
      ),
      _ToolData(
        'Confluence',
        '문서 및 지식베이스 연계',
        Icons.menu_book_outlined,
        vm.isConfluenceConfigured,
        [
          _ToolField(
              AppConstants.settingConfluenceUrl, 'Confluence 주소', vm.confluenceUrl),
          _ToolField(
              AppConstants.settingConfluenceSpace, 'Space Key', vm.confluenceSpace),
          _ToolField(
              AppConstants.settingConfluenceEmail, '계정 이메일', vm.confluenceEmail),
          _ToolField(
            AppConstants.settingConfluenceToken,
            'API Token',
            vm.confluenceToken,
            secret: true,
          ),
        ],
      ),
      _ToolData(
        'Redmine',
        '설정 정보 관리 · API 동기화 미지원',
        Icons.assignment_outlined,
        vm.isRedmineConfigured,
        [
          _ToolField(AppConstants.settingRedmineUrl, 'Redmine 주소', vm.redmineUrl),
          _ToolField(AppConstants.settingRedmineProject, '프로젝트', vm.redmineProject),
          _ToolField(
              AppConstants.settingRedmineApiKey, 'API Key', vm.redmineApiKey,
              secret: true),
        ],
      ),
      _ToolData(
        'Notion',
        '설정 정보 관리 · API 동기화 미지원',
        Icons.description_outlined,
        vm.isNotionConfigured,
        [
          _ToolField(
              AppConstants.settingNotionWorkspace, 'Workspace', vm.notionWorkspace),
          _ToolField(
              AppConstants.settingNotionDatabaseId, 'Database ID', vm.notionDatabaseId),
          _ToolField(AppConstants.settingNotionApiKey, 'API Key', vm.notionApiKey,
              secret: true),
        ],
      ),
      _ToolData(
        'GitHub Issues',
        '설정 정보 관리 · API 동기화 미지원',
        Icons.code_outlined,
        vm.isGithubConfigured,
        [
          _ToolField(AppConstants.settingGithubRepo, 'Repository', vm.githubRepo),
          _ToolField(AppConstants.settingGithubToken, 'Token', vm.githubToken,
              secret: true),
        ],
      ),
      _ToolData(
        'Asana',
        '설정 정보 관리 · API 동기화 미지원',
        Icons.view_kanban_outlined,
        vm.isAsanaConfigured,
        [
          _ToolField(
              AppConstants.settingAsanaWorkspace, 'Workspace', vm.asanaWorkspace),
          _ToolField(AppConstants.settingAsanaProject, 'Project', vm.asanaProject),
          _ToolField(AppConstants.settingAsanaToken, 'Token', vm.asanaToken,
              secret: true),
        ],
      ),
    ];

    return _SettingsPage(
      children: [
        Text(
          '업무에 사용하는 도구의 연결 상태를 확인하고 필요한 항목만 수정합니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _Panel(
          title: '업무 도구 연결',
          subtitle: '항목을 선택하면 상세 연결 정보를 수정할 수 있습니다.',
          icon: Icons.workspaces_outline,
          children: [
            for (var i = 0; i < tools.length; i++) ...[
              _ToolListRow(tools[i]),
              if (i != tools.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ],
    );
  }
}

class _IntegrationView extends StatelessWidget {
  const _IntegrationView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final desktop = MediaQuery.sizeOf(context).width >= 980;

    return _SettingsPage(
      children: [
        Text(
          '메일 수집, VOC 동기화와 알림 연결을 목적별로 관리합니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _Panel(
          title: '메일 연동',
          icon: Icons.mail_outline,
          children: [
            _ToolListRow(
              _ToolData(
                'Outlook 메일',
                vm.isOutlookConfigured
                    ? '${vm.outlookFolder} 폴더에서 VOC 수집'
                    : 'Outlook 메일에서 VOC를 수집합니다.',
                Icons.mail_outline,
                vm.isOutlookConfigured,
                [
                  _ToolField(AppConstants.settingOutlookAccessToken, 'Access Token',
                      vm.outlookAccessToken,
                      secret: true),
                  _ToolField(
                      AppConstants.settingOutlookMailbox, 'Mailbox', vm.outlookMailbox),
                  _ToolField(
                      AppConstants.settingOutlookFolder, 'Folder', vm.outlookFolder),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'VOC 동기화',
          subtitle: '다른 AI VOC Assistant와 VOC를 주고받습니다.',
          icon: Icons.sync_outlined,
          trailing: _StatusBadge(
            vm.vocForwardWebhookTargets.isNotEmpty,
            onText: '${vm.vocForwardWebhookTargets.length}개 등록',
          ),
          children: [
            if (desktop)
              const _VocSyncEditor(embedded: true)
            else
              _NavigationRow(
                icon: Icons.link_outlined,
                title: '수신 URL 목록',
                subtitle: vm.vocForwardWebhookTargets.isEmpty
                    ? '등록된 수신 URL이 없습니다.'
                    : '${vm.vocForwardWebhookTargets.length}개 URL 등록됨',
                badge: vm.vocForwardWebhookTargets.isEmpty
                    ? null
                    : '${vm.vocForwardWebhookTargets.length}개',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _VocSyncSettingsPage(),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('VOC 자동 전달'),
              subtitle: const Text('VOC 등록 시 활성화된 수신 URL로 자동 공유합니다.'),
              value: vm.vocAutoForwardEnabled,
              onChanged: (value) => context.read<SettingsViewModel>().saveSetting(
                    AppConstants.settingVocAutoForwardEnabled,
                    value.toString(),
                  ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Panel(
          title: '알림 연동',
          icon: Icons.notifications_none_outlined,
          children: [
            _ToolListRow(
              _ToolData(
                'Teams 알림',
                '긴급 VOC 알림 전송',
                Icons.notifications_active_outlined,
                vm.isTeamsConfigured,
                [
                  _ToolField(
                      AppConstants.settingTeamsWebhook, 'Teams Webhook URL', vm.teamsWebhook),
                  _ToolField(AppConstants.settingUrgencyWebhookThreshold, '알림 기준',
                      vm.urgencyWebhookThreshold),
                ],
              ),
            ),
            const Divider(height: 1),
            _ToolListRow(
              _ToolData(
                'Slack 알림',
                '긴급 VOC 알림 전송',
                Icons.chat_outlined,
                vm.isSlackConfigured,
                [
                  _ToolField(
                      AppConstants.settingSlackWebhook, 'Slack Webhook URL', vm.slackWebhook),
                  _ToolField(AppConstants.settingUrgencyWebhookThreshold, '알림 기준',
                      vm.urgencyWebhookThreshold),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Panel(
          title: '데이터 관리',
          subtitle: '백업, 가져오기, 전체 동기화와 초기화 작업을 관리합니다.',
          icon: Icons.storage_outlined,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DataManagementScreen(),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('데이터 관리 열기'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _VocSyncSettingsPage extends StatelessWidget {
  const _VocSyncSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VOC 동기화 설정')),
      body: const _VocSyncEditor(embedded: false),
    );
  }
}

class _VocSyncEditor extends StatefulWidget {
  const _VocSyncEditor({required this.embedded});
  final bool embedded;

  @override
  State<_VocSyncEditor> createState() => _VocSyncEditorState();
}

class _VocSyncEditorState extends State<_VocSyncEditor> {
  bool _loaded = false;
  late TextEditingController _instance;
  late TextEditingController _token;
  late List<String> _urls;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final vm = context.read<SettingsViewModel>();
    _instance = TextEditingController(text: vm.appInstanceName);
    _token = TextEditingController(text: vm.vocSyncBearerToken);
    _urls = List<String>.from(vm.vocForwardWebhookTargets);
    _loaded = true;
  }

  @override
  void dispose() {
    if (_loaded) {
      _instance.dispose();
      _token.dispose();
    }
    super.dispose();
  }

  Future<String?> _askUrl({String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? '수신 URL 추가' : '수신 URL 수정'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '수신 URL',
              hintText: 'https://example.com/webhook/voc',
              prefixIcon: Icon(Icons.link_outlined),
            ),
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('http 또는 https 형식의 URL을 입력해주세요.')),
        );
      }
      return null;
    }
    return value.trim();
  }

  Future<void> _add() async {
    final value = await _askUrl();
    if (value == null || !mounted) return;
    if (_urls.contains(value)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이미 등록된 URL입니다.')));
      return;
    }
    setState(() => _urls.add(value));
  }

  Future<void> _edit(int index) async {
    final value = await _askUrl(initial: _urls[index]);
    if (value == null || !mounted) return;
    if (_urls.asMap().entries.any((entry) =>
        entry.key != index && entry.value == value)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이미 등록된 URL입니다.')));
      return;
    }
    setState(() => _urls[index] = value);
  }

  void _remove(int index) => setState(() => _urls.removeAt(index));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<SettingsViewModel>().saveSettings({
        AppConstants.settingAppInstanceName: _instance.text.trim(),
        AppConstants.settingVocSyncBearerToken: _token.text.trim(),
        AppConstants.settingVocForwardWebhookTargets: _urls.join('\n'),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VOC 동기화 설정을 저장했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _content(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final list = _urls.isEmpty
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.link_off_outlined,
                    color: cs.onSurfaceVariant, size: 30),
                const SizedBox(height: 8),
                const Text('등록된 수신 URL이 없습니다.',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'URL을 추가하면 여러 시스템으로 VOC를 동기화할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          )
        : Column(
            children: [
              for (var i = 0; i < _urls.length; i++) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          _urls[i],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        tooltip: '수정',
                        onPressed: () => _edit(i),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () => _remove(i),
                        icon: Icon(Icons.delete_outline,
                            color: cs.error),
                      ),
                    ],
                  ),
                ),
                if (i != _urls.length - 1) const SizedBox(height: 8),
              ],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded) ...[
          Text(
            '여러 시스템의 수신 URL을 각각 추가하고 관리할 수 있습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
        ],
        TextField(
          controller: _instance,
          decoration: const InputDecoration(
            labelText: '앱 인스턴스 이름',
            prefixIcon: Icon(Icons.devices_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'VOC 동기화 Bearer 토큰',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                '수신 URL 목록',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _add,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('URL 추가'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        list,
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? '저장 중...' : '동기화 설정 저장'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _content(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _content(context),
    );
  }
}

class _GeneralView extends StatefulWidget {
  const _GeneralView();

  @override
  State<_GeneralView> createState() => _GeneralViewState();
}

class _GeneralViewState extends State<_GeneralView> {
  bool _loaded = false;
  late TextEditingController _name;
  late TextEditingController _codes;
  late TextEditingController _business;
  late TextEditingController _projects;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final vm = context.read<SettingsViewModel>();
    _name = TextEditingController(text: vm.userName);
    _codes = TextEditingController(text: vm.projectCodes.join(', '));
    _business =
        TextEditingController(text: vm.businessTypeOptions.join(', '));
    _projects =
        TextEditingController(text: vm.projectNameOptions.join(', '));
    _loaded = true;
  }

  @override
  void dispose() {
    if (_loaded) {
      for (final controller in [_name, _codes, _business, _projects]) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<SettingsViewModel>().saveSettings({
      AppConstants.settingUserName: _name.text.trim(),
      AppConstants.settingProjectCodes: _codes.text.trim(),
      AppConstants.settingBusinessTypeOptions: _business.text.trim(),
      AppConstants.settingProjectNameOptions: _projects.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('일반 설정을 저장했습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    return _SettingsPage(
      children: [
        Text(
          '사용자 정보, 화면 표시, VOC 업무 기준과 자동화 옵션을 관리합니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 860;
            final left = Column(
              children: [
                _Panel(
                  title: '사용자',
                  icon: Icons.person_outline,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: '담당자 이름',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: '화면 설정',
                  icon: Icons.palette_outlined,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: vm.themeModeString,
                      decoration: const InputDecoration(labelText: '테마'),
                      items: const [
                        DropdownMenuItem(
                            value: 'light', child: Text('라이트 모드')),
                        DropdownMenuItem(
                            value: 'dark', child: Text('다크 모드')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          context.read<SettingsViewModel>().saveSetting(
                                AppConstants.settingThemeMode,
                                value,
                              );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: vm.textScaleFactor.toString(),
                      decoration: const InputDecoration(labelText: '글씨 크기'),
                      items: const [
                        DropdownMenuItem(value: '0.9', child: Text('작게')),
                        DropdownMenuItem(value: '1.0', child: Text('기본')),
                        DropdownMenuItem(value: '1.1', child: Text('크게')),
                        DropdownMenuItem(value: '1.2', child: Text('매우 크게')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          context.read<SettingsViewModel>().saveSetting(
                                AppConstants.settingTextScale,
                                value,
                              );
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
            final right = Column(
              children: [
                _Panel(
                  title: 'VOC 업무 기준',
                  subtitle: '기본 카테고리 ${vm.allCategories.length}개 사용 중',
                  icon: Icons.category_outlined,
                  children: [
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('카테고리 ${vm.allCategories.length}개 보기'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: vm.allCategories
                                .map((value) => Chip(label: Text(value)))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _codes,
                      decoration: const InputDecoration(
                        labelText: '프로젝트 코드 목록',
                        hintText: '쉼표로 구분',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _business,
                      decoration: const InputDecoration(
                        labelText: '업무 구분 목록',
                        hintText: '쉼표로 구분',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _projects,
                      decoration: const InputDecoration(
                        labelText: '프로젝트명 목록',
                        hintText: '쉼표로 구분',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Panel(
                  title: 'AI 업무 자동화',
                  subtitle: 'VOC 등록 직후 AI 답변 초안을 자동 생성합니다.',
                  icon: Icons.smart_toy_outlined,
                  trailing: Switch(
                    value: vm.aiAutoAnswerOnVocRegister,
                    onChanged: (value) =>
                        context.read<SettingsViewModel>().saveSetting(
                              AppConstants.settingAiAutoAnswerOnVocRegister,
                              value.toString(),
                            ),
                  ),
                  children: [
                    Text(
                      '끄더라도 VOC 등록은 정상 동작하며 상세 화면에서 AI 분석과 답변 생성을 직접 실행할 수 있습니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            );
            if (!desktop) {
              return Column(
                children: [
                  left,
                  const SizedBox(height: 14),
                  right,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                Expanded(child: right),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('일반 설정 저장'),
          ),
        ),
      ],
    );
  }
}
