import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/domain/repositories/settings_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/settings_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
