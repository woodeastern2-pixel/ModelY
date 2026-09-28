import 'dart:convert';

import 'package:http/http.dart' as http;

class ConfluenceService {
  final String baseUrl;
  final String email;
  final String token;
  final String spaceKey;

  ConfluenceService({
    required this.baseUrl,
    required this.email,
    required this.token,
    required this.spaceKey,
  });

  Map<String, String> get _headers => {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$email:$token'))}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Future<String> createFaqPage({
    required String title,
    required String question,
    required String answer,
    String? category,
  }) async {
    final url = Uri.parse('$baseUrl/wiki/rest/api/content');
    final body = {
      'type': 'page',
      'title': title,
      'space': {'key': spaceKey},
      'body': {
        'storage': {
          'value': '''
<h2>질문</h2>
<p>${_escape(question)}</p>
<h2>답변</h2>
<p>${_escape(answer)}</p>
${category == null ? '' : '<p><strong>카테고리:</strong> ${_escape(category)}</p>'}
''',
          'representation': 'storage',
        }
      },
    };

    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Confluence 페이지 생성 실패: ${res.statusCode} ${res.body}');
    }

    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final id = map['id']?.toString() ?? '';
    return '$baseUrl/wiki/pages/viewpage.action?pageId=$id';
  }

  String _escape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
