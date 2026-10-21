import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh bundled choice survives connection confirmation and restart', () async {
    final repository = _MemorySettingsRepository({});
    final viewModel = SettingsViewModel(repository,
        bundledQwenInstalled: () => true);
    await viewModel.loadSettings();
    expect(viewModel.aiProvider, AppConstants.aiProviderBundledQwen);
    expect(repository.values[AppConstants.settingAiProvider],
        AppConstants.aiProviderBundledQwen);

    await viewModel.saveSetting('ai_connection_configured', 'true');
    expect(viewModel.aiProvider, AppConstants.aiProviderBundledQwen);
    viewModel.dispose();
    final restarted = SettingsViewModel(repository,
        bundledQwenInstalled: () => true);
    await restarted.loadSettings();
    expect(restarted.aiProvider, AppConstants.aiProviderBundledQwen);
    restarted.dispose();
  });

  test('a saved external provider is not replaced by the bundle', () async {
    final repository = _MemorySettingsRepository({
      AppConstants.settingAiProvider: AppConstants.aiProviderOllama,
      'ai_connection_configured': 'true',
    });
    final viewModel = SettingsViewModel(repository,
        bundledQwenInstalled: () => true);
    await viewModel.loadSettings();
    expect(viewModel.aiProvider, AppConstants.aiProviderOllama);
    viewModel.dispose();
  });

  test('custom legacy Ollama settings are preserved', () async {
    final repository = _MemorySettingsRepository({
      AppConstants.settingOllamaModel: 'user-custom-model',
    });
    final viewModel = SettingsViewModel(repository,
        bundledQwenInstalled: () => true);
    await viewModel.loadSettings();
    expect(viewModel.aiProvider, AppConstants.aiProviderOllama);
    expect(viewModel.ollamaModel, 'user-custom-model');
    viewModel.dispose();
  });

  test('missing bundle preserves the ordinary installation default', () async {
    final repository = _MemorySettingsRepository({});
    final viewModel = SettingsViewModel(repository,
        bundledQwenInstalled: () => false);
    await viewModel.loadSettings();
    expect(viewModel.aiProvider, AppConstants.aiProviderOllama);
    expect(repository.values.containsKey(AppConstants.settingAiProvider), isFalse);
    viewModel.dispose();
  });

  test('collaboration settings preserve existing JIRA values', () async {
    final repository = _MemorySettingsRepository({
      AppConstants.settingJiraUrl: 'https://jira.example.com',
      AppConstants.settingJiraProjectKey: 'VOC',
      AppConstants.settingJiraEmail: 'support@example.com',
      AppConstants.settingJiraToken: 'existing-token',
    });
    final viewModel = SettingsViewModel(repository);
    await viewModel.loadSettings();

    await viewModel.saveSettings({
      AppConstants.settingRedmineUrl: 'https://redmine.example.com',
      AppConstants.settingRedmineProject: 'voc-project',
      AppConstants.settingRedmineApiKey: 'redmine-key',
    });

    expect(viewModel.jiraUrl, 'https://jira.example.com');
    expect(viewModel.jiraProjectKey, 'VOC');
    expect(viewModel.jiraEmail, 'support@example.com');
    expect(viewModel.jiraToken, 'existing-token');
    expect(repository.values[AppConstants.settingJiraToken], 'existing-token');
  });

  test('legacy system theme safely falls back to light mode', () async {
    final repository = _MemorySettingsRepository({
      AppConstants.settingThemeMode: 'system',
    });
    final viewModel = SettingsViewModel(repository);
    await viewModel.loadSettings();

    expect(viewModel.themeModeString, 'light');
    expect(viewModel.themeMode, ThemeMode.light);
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  final Map<String, String> values;

  _MemorySettingsRepository(Map<String, String> initial)
      : values = Map<String, String>.from(initial);

  @override
  Future<Map<String, String>> getAllSettings() async => Map.of(values);

  @override
  Future<String?> getValue(String key) async => values[key];

  @override
  Future<void> setMultiple(Map<String, String> settings) async {
    values.addAll(settings);
  }

  @override
  Future<void> setValue(String key, String value) async {
    values[key] = value;
  }
}

