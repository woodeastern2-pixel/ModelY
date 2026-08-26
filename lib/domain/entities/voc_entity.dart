class VocEntity {
  final String id;
  final String title;
  final String content;
  final String category;
  final String? tags;
  final String customer;
  final String project;
  final String priority;
  final String status;
  final String? aiCategory;
  final bool isBusinessRelated;
  final double? businessScore;
  final double? categoryScore;
  final String? urgency;
  final double? urgencyScore;
  final String? businessType;
  final String? department;
  final double? departmentScore;
  final String? assignee;
  final double? assigneeScore;
  final String? duplicateOfVocId;
  final double? duplicateScore;
  final bool jiraRequired;
  final double? jiraScore;
  final String? analysisReason;
  final List<double>? embedding;
  final String? source;
  final String? sourceRef;
  final int? processingMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VocEntity({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.tags,
    required this.customer,
    required this.project,
    required this.priority,
    required this.status,
    this.aiCategory,
    this.isBusinessRelated = true,
    this.businessScore,
    this.categoryScore,
    this.urgency,
    this.urgencyScore,
    this.businessType,
    this.department,
    this.departmentScore,
    this.assignee,
    this.assigneeScore,
    this.duplicateOfVocId,
    this.duplicateScore,
    this.jiraRequired = false,
    this.jiraScore,
    this.analysisReason,
    this.embedding,
    this.source,
    this.sourceRef,
    this.processingMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  VocEntity copyWith({
    String? title,
    String? content,
    String? category,
    String? tags,
    String? customer,
    String? project,
    String? priority,
    String? status,
    String? aiCategory,
    bool? isBusinessRelated,
    double? businessScore,
    double? categoryScore,
    String? urgency,
    double? urgencyScore,
    String? businessType,
    String? department,
    double? departmentScore,
    String? assignee,
    double? assigneeScore,
    String? duplicateOfVocId,
    double? duplicateScore,
    bool? jiraRequired,
    double? jiraScore,
    String? analysisReason,
    List<double>? embedding,
    String? source,
    String? sourceRef,
    int? processingMinutes,
    DateTime? updatedAt,
  }) {
    return VocEntity(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      customer: customer ?? this.customer,
      project: project ?? this.project,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      aiCategory: aiCategory ?? this.aiCategory,
      isBusinessRelated: isBusinessRelated ?? this.isBusinessRelated,
      businessScore: businessScore ?? this.businessScore,
      categoryScore: categoryScore ?? this.categoryScore,
      urgency: urgency ?? this.urgency,
      urgencyScore: urgencyScore ?? this.urgencyScore,
      businessType: businessType ?? this.businessType,
      department: department ?? this.department,
      departmentScore: departmentScore ?? this.departmentScore,
      assignee: assignee ?? this.assignee,
      assigneeScore: assigneeScore ?? this.assigneeScore,
      duplicateOfVocId: duplicateOfVocId ?? this.duplicateOfVocId,
      duplicateScore: duplicateScore ?? this.duplicateScore,
      jiraRequired: jiraRequired ?? this.jiraRequired,
      jiraScore: jiraScore ?? this.jiraScore,
      analysisReason: analysisReason ?? this.analysisReason,
      embedding: embedding ?? this.embedding,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      processingMinutes: processingMinutes ?? this.processingMinutes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
