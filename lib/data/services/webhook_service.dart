import 'dart:convert';

import 'package:http/http.dart' as http;

class WebhookService {
  Future<Map<String, dynamic>> getJsonForMap({
    required String url,
    Map<String, String>? headers,
  }) async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        ...?headers,
      },
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Webhook 조회 실패: ${res.statusCode} ${res.body}');
    }

    if (res.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Webhook 응답 형식이 올바르지 않습니다.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> postJsonForMap({
    required String webhookUrl,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final res = await http.post(
      Uri.parse(webhookUrl),
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Webhook 전송 실패: ${res.statusCode} ${res.body}');
    }

    if (res.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Webhook 응답 형식이 올바르지 않습니다.');
    }
    return decoded;
  }

  Future<void> postJson({
    required String webhookUrl,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    final res = await http.post(
      Uri.parse(webhookUrl),
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Webhook 전송 실패: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> sendTeamsAlert({
    required String webhookUrl,
    required String title,
    required String message,
    Map<String, dynamic>? extra,
  }) async {
    final body = {
      '@type': 'MessageCard',
      '@context': 'https://schema.org/extensions',
      'summary': title,
      'themeColor': 'FF0000',
      'title': title,
      'text': message,
      if (extra != null)
        'sections': [
          {
            'facts': extra.entries
                .map((e) => {'name': e.key, 'value': '${e.value}'})
                .toList(),
          }
        ],
    };

    final res = await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Teams Webhook 실패: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> sendSlackMessage({
    required String webhookUrl,
    required String text,
    Map<String, dynamic>? fields,
  }) async {
    final body = {
      'text': text,
      if (fields != null)
        'attachments': [
          {
            'fields': fields.entries
                .map(
                  (e) => {
                    'title': e.key,
                    'value': '${e.value}',
                    'short': false,
                  },
                )
                .toList(),
          }
        ],
    };

    final res = await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Slack Webhook 실패: ${res.statusCode} ${res.body}');
    }
  }
}
