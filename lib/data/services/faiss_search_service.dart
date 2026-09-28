import 'dart:convert';
import 'package:http/http.dart' as http;

class FaissSearchService {
  String endpoint;

  FaissSearchService({required this.endpoint});

  bool get isEnabled => endpoint.trim().isNotEmpty;

  Future<void> upsert({
    required String id,
    required List<double> vector,
    required Map<String, dynamic> payload,
  }) async {
    final url = Uri.parse('$endpoint/upsert');
    final body = jsonEncode({
      'id': id,
      'vector': vector,
      'payload': payload,
    });
    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('FAISS upsert 실패: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> search({
    required List<double> queryVector,
    int topK = 5,
  }) async {
    final url = Uri.parse('$endpoint/search');
    final body = jsonEncode({'vector': queryVector, 'top_k': topK});
    final response = await http
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('FAISS 검색 실패: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['results'] as List? ?? [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<bool> health() async {
    try {
      final response = await http
          .get(Uri.parse('$endpoint/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
