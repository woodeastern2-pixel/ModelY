import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/utils/privacy_masking_service.dart';

class OpenAiService {
  final String apiKey;
  String chatModel;
  final double temperature;
  final int maxTokens;
  static const String _embeddingModel = 'text-embedding-3-small';
  static const String _baseUrl = 'https://api.openai.com/v1';

  OpenAiService({
    required this.apiKey,
    required this.chatModel,
    this.temperature = 0.3,
    this.maxTokens = 2048,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  /// 채팅 완성. 외부 전송 직전에 사용자 입력의 명확한 개인정보를 마스킹한다.
  Future<String> generate(String systemPrompt, String userPrompt) async {
    final url = Uri.parse('$_baseUrl/chat/completions');
    final safeUserPrompt = PrivacyMaskingService.mask(userPrompt);
    final body = jsonEncode({
      'model': chatModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': safeUserPrompt},
      ],
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await http
        .post(url, headers: _headers, body: body)
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('OpenAI 오류 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'] as String;
  }

  /// 텍스트 임베딩 생성. 외부 임베딩 요청에도 동일한 마스킹을 적용한다.
  Future<List<double>> embed(String text) async {
    final url = Uri.parse('$_baseUrl/embeddings');
    final body = jsonEncode({
      'model': _embeddingModel,
      'input': PrivacyMaskingService.mask(text),
    });

    final response = await http
        .post(url, headers: _headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('OpenAI 임베딩 오류: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return List<double>.from(data['data'][0]['embedding']);
  }

  /// API Key 유효성 검증
  Future<bool> isValidApiKey() async {
    try {
      final url = Uri.parse('$_baseUrl/models');
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
