import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/settings_viewmodel.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('관리자 설정'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '통계'),
              Tab(text: '설정'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _StatsTab(),
            _ConfigAdminTab(),
          ],
        ),
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주요 지표',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const _Stat('총 VOC', '2,345'),
                const _Stat('응답률', '87.5%'),
                const _Stat('AI 정확도', '94.2%'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfigAdminTab extends StatelessWidget {
  const _ConfigAdminTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsViewModel>(
      builder: (context, vm, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 설정',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(height: 16),
                    _ConfigRow('AI Provider', vm.aiProvider),
                    _ConfigRow('Ollama URL', vm.ollamaUrl),
                    _ConfigRow('Ollama Model', vm.ollamaModel),
                    _ConfigRow('OpenAI Model', vm.openAiModel),
                    _ConfigRow('Gemini Model', vm.geminiModel),
                    _ConfigRow(
                      'JIRA URL',
                      vm.jiraUrl.isEmpty ? '(미설정)' : vm.jiraUrl,
                    ),
                    _ConfigRow(
                      'JIRA Project',
                      vm.jiraProjectKey.isEmpty
                          ? '(미설정)'
                          : vm.jiraProjectKey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfigRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
