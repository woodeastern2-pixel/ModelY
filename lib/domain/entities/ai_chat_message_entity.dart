class AiChatMessageEntity {
  final String id;
  final String sessionId;
  final String category;
  final String role;
  final String content;
  final List<String> referencedVocIds;
  final double? confidence;
  final DateTime createdAt;

  const AiChatMessageEntity({
    required this.id,
    required this.sessionId,
    required this.category,
    required this.role,
    required this.content,
    required this.referencedVocIds,
    this.confidence,
    required this.createdAt,
  });
}