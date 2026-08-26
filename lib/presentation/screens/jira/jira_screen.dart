import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/jira_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';

class JiraScreen extends StatelessWidget {
  const JiraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tabLabelColor = isDark
        ? const Color(0xFFE8F0FF)
        : const Color(0xFF163A6B);
    final tabUnselectedColor = isDark
        ? const Color(0xFF9EACC2)
        : const Color(0xFF5E6B7C);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('업무 협업툴'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Material(
              color: theme.colorScheme.surface,
              child: TabBar(
                isScrollable: true,
                labelColor: tabLabelColor,
                unselectedLabelColor: tabUnselectedColor,
                indicatorColor: const Color(0xFFF59E0B),
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'JIRA'),
                  Tab(text: 'Redmine'),
                  Tab(text: 'Confluence'),
                  Tab(text: 'Notion'),
                  Tab(text: 'GitHub'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            Consumer<JiraViewModel>(
              builder: (context, vm, _) {
                if (!vm.isConfigured) {
                  return _NotConfigured();
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ConnectionStatus(vm: vm),
                      const SizedBox(height: 16),
                      _TestConnectionCard(vm: vm),
                    ],
                  ),
                );
              },
            ),
            Consumer<SettingsViewModel>(
              builder: (context, settings, _) {
                return _ToolPlaceholder(
                  title: 'Redmine 설정',
                  configured: settings.isRedmineConfigured,
                  description:
                      '연동 정보 저장과 상태 표시만 지원합니다. 실제 이슈 동기화 API는 아직 지원하지 않습니다.',
                  rows: [
                    _ToolInfoRow('URL', settings.redmineUrl),
                    _ToolInfoRow('Project', settings.redmineProject),
                  ],
                );
              },
            ),
            Consumer<SettingsViewModel>(
              builder: (context, settings, _) {
                return _ToolPlaceholder(
                  title: 'Confluence 연동',
                  configured: settings.isConfluenceConfigured,
                  description:
                      '승인된 VOC 답변을 FAQ 페이지로 게시할 때 사용하는 Space 인증 정보입니다.',
                  rows: [
                    _ToolInfoRow('URL', settings.confluenceUrl),
                    _ToolInfoRow('Space', settings.confluenceSpace),
                  ],
                );
              },
            ),
            Consumer<SettingsViewModel>(
              builder: (context, settings, _) {
                return _ToolPlaceholder(
                  title: 'Notion 설정',
                  configured: settings.isNotionConfigured,
                  description:
                      '연동 정보 저장과 상태 표시만 지원합니다. 실제 데이터베이스 동기화 API는 아직 지원하지 않습니다.',
                  rows: [
                    _ToolInfoRow('Workspace', settings.notionWorkspace),
                    _ToolInfoRow('Database', settings.notionDatabaseId),
                  ],
                );
              },
            ),
            Consumer<SettingsViewModel>(
              builder: (context, settings, _) {
                return _ToolPlaceholder(
                  title: 'GitHub Issues 설정',
                  configured: settings.isGithubConfigured,
                  description:
                      '연동 정보 저장과 상태 표시만 지원합니다. 실제 Issues 동기화 API는 아직 지원하지 않습니다.',
                  rows: [
                    _ToolInfoRow('Repository', settings.githubRepo),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 64,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          const Text('JIRA가 설정되지 않았습니다',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('설정 화면의 업무 협업툴 설정에서 JIRA URL, 프로젝트 키, 토큰을 입력해 주세요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  final JiraViewModel vm;
  const _ConnectionStatus({required this.vm});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JIRA 설정', style: Theme.of(context).textTheme.titleSmall),
            const Divider(height: 16),
            _InfoRow('서버 URL', settings.jiraUrl),
            _InfoRow('프로젝트', settings.jiraProjectKey),
            _InfoRow('이메일', settings.jiraEmail),
            Row(
              children: [
                const Icon(Icons.circle, size: 10,
                    color: Colors.green),
                const SizedBox(width: 8),
                Text(vm.isConnected ? '연결됨' : '연결 안 됨',
                    style: TextStyle(
                        color: vm.isConnected ? Colors.green : Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolInfoRow {
  final String label;
  final String value;

  const _ToolInfoRow(this.label, this.value);
}

class _ToolPlaceholder extends StatelessWidget {
  final String title;
  final bool configured;
  final String description;
  final List<_ToolInfoRow> rows;

  const _ToolPlaceholder({
    required this.title,
    required this.configured,
    required this.description,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    configured ? Icons.check_circle : Icons.info_outline,
                    size: 14,
                    color: configured ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    configured ? '설정 정보 입력됨' : '설정 정보 미입력',
                    style: TextStyle(
                      color: configured ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          row.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          row.value.isEmpty ? '-' : row.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _TestConnectionCard extends StatelessWidget {
  final JiraViewModel vm;
  const _TestConnectionCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('연결 테스트', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (vm.error != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(vm.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            if (vm.successMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(vm.successMessage!,
                    style: const TextStyle(
                        color: Colors.green, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: vm.isTesting ? null : vm.testConnection,
              icon: vm.isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(vm.isTesting ? '연결 중...' : 'JIRA 연결 테스트'),
            ),
          ],
        ),
      ),
    );
  }
}
