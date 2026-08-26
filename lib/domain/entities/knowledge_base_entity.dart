class KnowledgeBaseEntity {
  final String id;
  final String question;
  final String answer;
  final String category;
  final String? customer;
  final String? project;
  final String? vocId;
  final List<double>? embedding;
  final DateTime resolvedAt;
  final DateTime createdAt;

  const KnowledgeBaseEntity({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    this.customer,
    this.project,
    this.vocId,
    this.embedding,
    required this.resolvedAt,
    required this.createdAt,
  });
}

class SimilarVocResult {
  final KnowledgeBaseEntity knowledgeBase;
  final double similarityScore;
  final int? adoptionCount;
  final int? usageCount;
  final DateTime? lastUsedAt;

  const SimilarVocResult({
    required this.knowledgeBase,
    required this.similarityScore,
    this.adoptionCount,
    this.usageCount,
    this.lastUsedAt,
  });
}
