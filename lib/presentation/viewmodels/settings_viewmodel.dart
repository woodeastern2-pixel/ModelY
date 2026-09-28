import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsViewModel extends ChangeNotifier {
  final SettingsRepository _repository;

  Map<String, String> _settings = {};
  bool _isLoading = false;
  String? _error;

  SettingsViewModel(this._repository) {
    loadSettings();
  }

  Map<String, String> get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get aiProvider =>
      _settings[AppConstants.settingAiProvider] ??
      AppConstants.aiProviderOllama;
  double get aiTemperature =>
      double.tryParse(
        _settings[AppConstants.settingAiTemperature] ??
            AppConstants.defaultAiTemperature,
      ) ??
      0.3;
  int get aiMaxTokens =>
      int.tryParse(
        _settings[AppConstants.settingAiMaxTokens] ??
            AppConstants.defaultAiMaxTokens,
      ) ??
      2048;
  String get ollamaUrl =>
      _settings[AppConstants.settingOllamaUrl] ?? AppConstants.defaultOllamaUrl;
  String get ollamaModel =>
      _settings[AppConstants.settingOllamaModel] ??
      AppConstants.defaultOllamaModel;
  String get openAiKey => _settings[AppConstants.settingOpenAiKey] ?? '';
  String get openAiModel =>
      _settings[AppConstants.settingOpenAiModel] ??
      AppConstants.defaultOpenAiModel;
  String get geminiKey => _settings[AppConstants.settingGeminiKey] ?? '';
  String get geminiModel =>
      _settings[AppConstants.settingGeminiModel] ??
      AppConstants.defaultGeminiModel;
  String get claudeKey => _settings[AppConstants.settingClaudeKey] ?? '';
  String get claudeModel =>
      _settings[AppConstants.settingClaudeModel] ??
      AppConstants.defaultClaudeModel;
  String get claudeBaseUrl =>
      _settings[AppConstants.settingClaudeBaseUrl] ??
      AppConstants.defaultClaudeBaseUrl;
  String get faissEndpoint =>
      _settings[AppConstants.settingFaissEndpoint] ?? '';
  String get jiraUrl => _settings[AppConstants.settingJiraUrl] ?? '';
  String get jiraProjectKey =>
      _settings[AppConstants.settingJiraProjectKey] ?? '';
  String get jiraToken => _settings[AppConstants.settingJiraToken] ?? '';
  String get jiraEmail => _settings[AppConstants.settingJiraEmail] ?? '';
  String get outlookAccessToken =>
      _settings[AppConstants.settingOutlookAccessToken] ?? '';
  String get outlookMailbox =>
      _settings[AppConstants.settingOutlookMailbox] ?? '';
  String get outlookFolder =>
      _settings[AppConstants.settingOutlookFolder] ?? 'Inbox';
  String get teamsWebhook => _settings[AppConstants.settingTeamsWebhook] ?? '';
  String get slackWebhook => _settings[AppConstants.settingSlackWebhook] ?? '';
  String get confluenceUrl =>
      _settings[AppConstants.settingConfluenceUrl] ?? '';
  String get confluenceSpace =>
      _settings[AppConstants.settingConfluenceSpace] ?? '';
  String get confluenceEmail =>
      _settings[AppConstants.settingConfluenceEmail] ?? '';
  String get confluenceToken =>
      _settings[AppConstants.settingConfluenceToken] ?? '';
  String get redmineUrl => _settings[AppConstants.settingRedmineUrl] ?? '';
  String get redmineProject =>
      _settings[AppConstants.settingRedmineProject] ?? '';
  String get redmineApiKey =>
      _settings[AppConstants.settingRedmineApiKey] ?? '';
  String get notionWorkspace =>
      _settings[AppConstants.settingNotionWorkspace] ?? '';
  String get notionDatabaseId =>
      _settings[AppConstants.settingNotionDatabaseId] ?? '';
  String get notionApiKey => _settings[AppConstants.settingNotionApiKey] ?? '';
  String get githubRepo => _settings[AppConstants.settingGithubRepo] ?? '';
  String get githubToken => _settings[AppConstants.settingGithubToken] ?? '';
  String get asanaWorkspace =>
      _settings[AppConstants.settingAsanaWorkspace] ?? '';
  String get asanaProject => _settings[AppConstants.settingAsanaProject] ?? '';
  String get asanaToken => _settings[AppConstants.settingAsanaToken] ?? '';
  String get urgencyWebhookThreshold =>
      _settings[AppConstants.settingUrgencyWebhookThreshold] ??
      AppConstants.defaultUrgencyWebhookThreshold;
  bool get aiAutoAnswerOnVocRegister =>
      (_settings[AppConstants.settingAiAutoAnswerOnVocRegister] ??
              AppConstants.defaultAiAutoAnswerOnVocRegister)
          .toLowerCase() ==
      'true';
  String get appInstanceName =>
      _settings[AppConstants.settingAppInstanceName] ??
      AppConstants.defaultAppInstanceName;
  bool get vocAutoForwardEnabled =>
      (_settings[AppConstants.settingVocAutoForwardEnabled] ??
              AppConstants.defaultVocAutoForwardEnabled)
          .toLowerCase() ==
      'true';
  List<String> get vocForwardWebhookTargets {
    final raw = _settings[AppConstants.settingVocForwardWebhookTargets] ?? '';
    if (raw.trim().isEmpty) return [];
    return raw
        .split(RegExp(r'[\n,]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  String get vocSyncBearerToken =>
      _settings[AppConstants.settingVocSyncBearerToken] ?? '';
  String get vocSyncRetryQueueRaw =>
      _settings[AppConstants.settingVocSyncRetryQueue] ?? '';
  String get userName => _settings[AppConstants.settingUserName] ?? '담당자';
  double get textScaleFactor =>
      double.tryParse(
        _settings[AppConstants.settingTextScale] ??
            AppConstants.defaultTextScale,
      ) ??
      1.0;
  List<String> get customCategories {
    final raw = _settings[AppConstants.settingCustomCategories] ?? '';
    if (raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> get businessTypeOptions {
    final raw = _settings[AppConstants.settingBusinessTypeOptions] ?? '';
    if (raw.trim().isEmpty) {
      return [...AppConstants.defaultBusinessTypeOptions];
    }
    final options = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return options.isEmpty
        ? [...AppConstants.defaultBusinessTypeOptions]
        : options;
  }

  List<String> get projectNameOptions {
    final raw = _settings[AppConstants.settingProjectNameOptions] ?? '';
    if (raw.trim().isEmpty) {
      return [...AppConstants.defaultProjectNameOptions];
    }
    final options = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    return options.isEmpty
        ? [...AppConstants.defaultProjectNameOptions]
        : options;
  }

  List<String> get projectCodes {
    final raw = _settings[AppConstants.settingProjectCodes] ?? '';
    if (raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> get allCategories => [
        ...AppConstants.defaultCategories,
      ];

  bool get isJiraConfigured =>
      jiraUrl.isNotEmpty && jiraProjectKey.isNotEmpty && jiraToken.isNotEmpty;
  bool get isOutlookConfigured => outlookAccessToken.isNotEmpty;
  bool get isTeamsConfigured => teamsWebhook.isNotEmpty;
  bool get isSlackConfigured => slackWebhook.isNotEmpty;
  bool get isConfluenceConfigured =>
      confluenceUrl.isNotEmpty &&
      confluenceSpace.isNotEmpty &&
      confluenceEmail.isNotEmpty &&
      confluenceToken.isNotEmpty;
  bool get isRedmineConfigured =>
      redmineUrl.isNotEmpty &&
      redmineProject.isNotEmpty &&
      redmineApiKey.isNotEmpty;
  bool get isNotionConfigured =>
      notionWorkspace.isNotEmpty &&
      notionDatabaseId.isNotEmpty &&
      notionApiKey.isNotEmpty;
  bool get isGithubConfigured =>
      githubRepo.isNotEmpty && githubToken.isNotEmpty;
  bool get isAsanaConfigured =>
      asanaWorkspace.isNotEmpty &&
      asanaProject.isNotEmpty &&
      asanaToken.isNotEmpty;

  /// 테마 모드 설정. 이전 버전의 system 값은 light로 호환 처리한다.
  String get themeModeString =>
      _settings[AppConstants.settingThemeMode] == 'dark' ? 'dark' : 'light';

  /// ThemeMode로 변환된 테마 모드
  ThemeMode get themeMode {
    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();
    try {
      _settings = await _repository.getAllSettings();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSetting(String key, String value) async {
    await _repository.setValue(key, value);
    _settings[key] = value;
    notifyListeners();
  }

  Future<void> saveSettings(Map<String, String> newSettings) async {
    await _repository.setMultiple(newSettings);
    _settings.addAll(newSettings);
    notifyListeners();
  }

  Future<void> addCustomCategory(String category) async {
    final c = category.trim();
    if (c.isEmpty) return;
    final next = [...customCategories];
    if (!next.contains(c) && !AppConstants.defaultCategories.contains(c)) {
      next.add(c);
      await saveSetting(AppConstants.settingCustomCategories, next.join(','));
    }
  }

  Future<void> removeCustomCategory(String category) async {
    final next = [...customCategories]..remove(category);
    await saveSetting(AppConstants.settingCustomCategories, next.join(','));
  }
}
