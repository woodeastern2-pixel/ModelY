import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  String baseUrl;
  String model;
  final double temperature;
  final int maxTokens;

  OllamaService({
    required this.baseUrl,
    required this.model,
    this.temperature = 0.3,
    this.maxTokens = 2048,
  });

  /// 텍스트 생성 (채팅 완성)
  Future<String> generate(String systemPrompt, String userPrompt) async {
    final url = Uri.parse('$baseUrl/api/chat');
    final body = jsonEncode({
      'model': model,
      'stream': false,
      'options': {
        'temperature': temperature,
        'num_predict': maxTokens,
      },
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    });

    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('Ollama 오류 (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['message']['content'] as String;
  }

  /// 텍스트 임베딩 생성
  Future<List<double>> embed(String text) async {
    final url = Uri.parse('$baseUrl/api/embed');
    final body = jsonEncode({'model': model, 'input': text});

    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('Ollama 임베딩 오류: ${response.body}');
    }

    final data = jsonDecode(response.body);
    // Ollama /api/embed 응답: {"embeddings": [[...]]}
    final embeddings = data['embeddings'] as List;
    return List<double>.from(embeddings.first);
  }

  /// Ollama 서버 상태 확인
  Future<bool> isAvailable() async {
    try {
      final url = Uri.parse('$baseUrl/api/tags');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 사용 가능한 모델 목록 조회
  Future<List<String>> getAvailableModels() async {
    final url = Uri.parse('$baseUrl/api/tags');
    final response = await http
        .get(url)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    final models = data['models'] as List? ?? [];
    return models.map((m) => m['name'] as String).toList();
  }
}
