import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/jira_service.dart';
import '../../domain/entities/jira_entity.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_constants.dart';
import 'settings_viewmodel.dart';

class JiraViewModel extends ChangeNotifier {
  final SettingsViewModel _settingsViewModel;
  final _uuid = const Uuid();

  JiraService? _jiraService;
  List<JiraLinkEntity> _vocLinks = [];
  List<JiraIssueEntity> _searchResults = [];
  bool _isLoading = false;
  bool _isTesting = false;
  bool _isConnected = false;
  String? _error;
  String? _successMessage;

  JiraViewModel(this._settingsViewModel) {
    _configureService();
    _settingsViewModel.addListener(_configureService);
  }

  bool get isLoading => _isLoading;
  bool get isTesting => _isTesting;
  bool get isConnected => _isConnected;
  String? get error => _error;
  String? get successMessage => _successMessage;
  List<JiraLinkEntity> get vocLinks => _vocLinks;
  List<JiraIssueEntity> get searchResults => _searchResults;
  bool get isConfigured => _settingsViewModel.isJiraConfigured;

  void _configureService() {
    if (_settingsViewModel.isJiraConfigured) {
      _jiraService = JiraService(
        baseUrl: _settingsViewModel.jiraUrl,
        projectKey: _settingsViewModel.jiraProjectKey,
        email: _settingsViewModel.jiraEmail,
        token: _settingsViewModel.jiraToken,
      );
    }
  }

  Future<void> testConnection() async {
    if (_jiraService == null) return;
    _isTesting = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      _isConnected = await _jiraService!.testConnection();
      _successMessage = _isConnected ? 'Jira 연결을 확인했습니다.' : null;
      if (!_isConnected) _error = 'Jira에 연결하지 못했습니다. 주소, 이메일, API 토큰을 확인해 주세요.';
    } catch (e) {
      _isConnected = false;
      _error = e.toString();
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }

  Future<JiraLinkEntity?> createIssueForVoc({
    required String vocId,
    required String summary,
    required String description,
    String priority = 'Medium',
  }) async {
    if (_jiraService == null) {
      _error = 'Jira 연결 정보가 없습니다.';
      notifyListeners();
      return null;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _jiraService!.createIssue(
        summary: summary,
        description: description,
        priority: priority,
      );

      final jiraKey = result['key'] as String;
      final link = JiraLinkEntity(
        id: _uuid.v4(),
        vocId: vocId,
        jiraKey: jiraKey,
        jiraSummary: summary,
        jiraStatus: 'To Do',
        jiraUrl: '${_settingsViewModel.jiraUrl}/browse/$jiraKey',
        createdAt: DateTime.now(),
      );

      await _saveJiraLink(link);
      _vocLinks.add(link);
      _successMessage = 'Jira 이슈를 만들었습니다: $jiraKey';
      notifyListeners();
      return link;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLinksForVoc(String vocId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      AppConstants.tableJiraLinks,
      where: 'voc_id = ?',
      whereArgs: [vocId],
    );
    _vocLinks = maps.map((m) => JiraLinkEntity(
          id: m['id'] as String,
          vocId: m['voc_id'] as String,
          jiraKey: m['jira_key'] as String,
          jiraSummary: m['jira_summary'] as String?,
          jiraStatus: m['jira_status'] as String?,
          jiraAssignee: m['jira_assignee'] as String?,
          jiraUrl: m['jira_url'] as String?,
          createdAt: DateTime.parse(m['created_at'] as String),
        )).toList();
    notifyListeners();
  }

  Future<JiraIssueEntity?> fetchIssue(String key) async {
    if (_jiraService == null) return null;
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _jiraService!.getIssue(key);
      final fields = JiraService.parseIssueFields(data);
      return JiraIssueEntity(
        key: fields['key'] ?? key,
        summary: fields['summary'] ?? '',
        status: fields['status'] ?? '',
        assignee: fields['assignee'],
        priority: fields['priority'],
        url: '${_settingsViewModel.jiraUrl}/browse/$key',
      );
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveJiraLink(JiraLinkEntity link) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(AppConstants.tableJiraLinks, {
      'id': link.id,
      'voc_id': link.vocId,
      'jira_key': link.jiraKey,
      'jira_summary': link.jiraSummary,
      'jira_status': link.jiraStatus,
      'jira_assignee': link.jiraAssignee,
      'jira_url': link.jiraUrl,
      'created_at': link.createdAt.toIso8601String(),
    });
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _settingsViewModel.removeListener(_configureService);
    super.dispose();
  }
}
