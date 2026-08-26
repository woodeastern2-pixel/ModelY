import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/privacy_masking_service.dart';

class ClaudeService {
  final String apiKey;
  final String baseUrl;
  String chatModel;
  final double temperature;
  final int maxTokens;

  ClaudeService({
    required this.apiKey,
    required this.baseUrl,
    required this.chatModel,
    this.temperature = 0.3,
    this.maxTokens = 2048,
  });

  Future<String> generate(String systemPrompt, String userPrompt) async {
    final url = Uri.parse('$baseUrl/messages');
    final body = jsonEncode({
      'model': chatModel,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': PrivacyMaskingService.mask(userPrompt),
        },
      ],
    });

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Claude 오류 (${response.statusCode}): ${response.body}');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = data['content'] as List? ?? [];
    final text = content
        .map(
          (part) => part is Map<String, dynamic>
              ? part['text'] as String? ?? ''
              : '',
        )
        .join()
        .trim();
    if (text.isEmpty) {
      throw Exception('Claude 응답 텍스트가 비어 있습니다.');
    }
    return text;
  }
}
