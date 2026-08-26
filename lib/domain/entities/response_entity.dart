class ResponseEntity {
  final String id;
  final String vocId;
  final String content;
  final String status;
  final bool aiGenerated;
  final double? confidenceScore;
  final List<String> referencedVocIds;
  final String? approvedBy;
  final DateTime? approvedAt;
  final int adoptionCount;
  final int usageCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ResponseEntity({
    required this.id,
    required this.vocId,
    required this.content,
    required this.status,
    this.aiGenerated = false,
    this.confidenceScore,
    this.referencedVocIds = const [],
    this.approvedBy,
    this.approvedAt,
    this.adoptionCount = 0,
    this.usageCount = 0,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => status == 'APPROVED';
  bool get isDraft => status == 'DRAFT';

  ResponseEntity copyWith({
    String? content,
    String? status,
    double? confidenceScore,
    List<String>? referencedVocIds,
    String? approvedBy,
    DateTime? approvedAt,
    int? adoptionCount,
    int? usageCount,
    DateTime? lastUsedAt,
    DateTime? updatedAt,
  }) {
    return ResponseEntity(
      id: id,
      vocId: vocId,
      content: content ?? this.content,
      status: status ?? this.status,
      aiGenerated: aiGenerated,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      referencedVocIds: referencedVocIds ?? this.referencedVocIds,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      adoptionCount: adoptionCount ?? this.adoptionCount,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
