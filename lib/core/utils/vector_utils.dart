import 'dart:math';

class VectorUtils {
  VectorUtils._();

  /// 두 벡터의 코사인 유사도 계산 (FAISS 대체 구현)
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// 텍스트 기반 TF-IDF 유사 간이 임베딩 (API 없을 때 폴백)
  static List<double> simpleTextEmbedding(String text, {int dim = 128}) {
    final tokens = _tokenize(text);
    final vector = List<double>.filled(dim, 0.0);

    for (final token in tokens) {
      final hash = token.hashCode.abs() % dim;
      vector[hash] += 1.0;
    }

    // 정규화
    final norm = sqrt(vector.fold(0.0, (sum, v) => sum + v * v));
    if (norm > 0) {
      for (int i = 0; i < dim; i++) {
        vector[i] /= norm;
      }
    }
    return vector;
  }

  static List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1)
        .toList();
  }
}
