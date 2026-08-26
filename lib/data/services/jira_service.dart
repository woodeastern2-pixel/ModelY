import 'dart:convert';
import 'package:http/http.dart' as http;

class JiraService {
  String baseUrl;
  String projectKey;
  String email;
  String token;

  JiraService({
    required this.baseUrl,
    required this.projectKey,
    required this.email,
    required this.token,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$email:$token'))}',
      };

  /// JIRA 이슈 생성
  Future<Map<String, dynamic>> createIssue({
    required String summary,
    required String description,
    String issueType = 'Task',
    String? priority,
  }) async {
    final url = Uri.parse('$baseUrl/rest/api/3/issue');
    final body = jsonEncode({
      'fields': {
        'project': {'key': projectKey},
        'summary': summary,
        'description': {
          'type': 'doc',
          'version': 1,
          'content': [
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': description}
              ]
            }
          ]
        },
        'issuetype': {'name': issueType},
        if (priority != null) 'priority': {'name': priority},
      }
    });

    final response = await http
        .post(url, headers: _headers, body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 201) {
      throw Exception('JIRA 이슈 생성 실패 (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// JIRA 이슈 조회
  Future<Map<String, dynamic>> getIssue(String issueKey) async {
    final url = Uri.parse('$baseUrl/rest/api/3/issue/$issueKey');
    final response = await http
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 404) {
      throw Exception('이슈를 찾을 수 없습니다: $issueKey');
    }
    if (response.statusCode != 200) {
      throw Exception('JIRA 조회 실패 (${response.statusCode})');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  /// 프로젝트 이슈 목록 검색
  Future<List<Map<String, dynamic>>> searchIssues(String jql, {int maxResults = 50}) async {
    final url = Uri.parse('$baseUrl/rest/api/3/search');
    final body = jsonEncode({
      'jql': jql,
      'maxResults': maxResults,
      'fields': ['summary', 'status', 'assignee', 'priority', 'description'],
    });

    final response = await http
        .post(url, headers: _headers, body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('JIRA 검색 실패 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return List<Map<String, dynamic>>.from(data['issues'] ?? []);
  }

  /// 이슈 상태 전환
  Future<void> transitionIssue(String issueKey, String transitionId) async {
    final url = Uri.parse('$baseUrl/rest/api/3/issue/$issueKey/transitions');
    final body = jsonEncode({'transition': {'id': transitionId}});

    final response = await http
        .post(url, headers: _headers, body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 204) {
      throw Exception('JIRA 상태 변경 실패 (${response.statusCode})');
    }
  }

  /// 사용 가능한 전환 목록 조회
  Future<List<Map<String, dynamic>>> getTransitions(String issueKey) async {
    final url = Uri.parse('$baseUrl/rest/api/3/issue/$issueKey/transitions');
    final response = await http
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['transitions'] ?? []);
  }

  /// 연결 테스트
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$baseUrl/rest/api/3/myself');
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 프로젝트 목록 조회
  Future<List<Map<String, dynamic>>> getProjects() async {
    final url = Uri.parse('$baseUrl/rest/api/3/project');
    final response = await http
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  }

  /// 이슈 맵에서 파싱된 주요 필드 추출
  static Map<String, String?> parseIssueFields(Map<String, dynamic> issue) {
    final fields = issue['fields'] as Map<String, dynamic>? ?? {};
    return {
      'key': issue['key'] as String?,
      'summary': fields['summary'] as String?,
      'status': (fields['status'] as Map?)?['name'] as String?,
      'assignee': (fields['assignee'] as Map?)?['displayName'] as String?,
      'priority': (fields['priority'] as Map?)?['name'] as String?,
    };
  }
}
