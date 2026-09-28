class JiraLinkEntity {
  final String id;
  final String vocId;
  final String jiraKey;
  final String? jiraSummary;
  final String? jiraStatus;
  final String? jiraAssignee;
  final String? jiraUrl;
  final DateTime createdAt;

  const JiraLinkEntity({
    required this.id,
    required this.vocId,
    required this.jiraKey,
    this.jiraSummary,
    this.jiraStatus,
    this.jiraAssignee,
    this.jiraUrl,
    required this.createdAt,
  });
}

class JiraIssueEntity {
  final String key;
  final String summary;
  final String status;
  final String? assignee;
  final String? priority;
  final String? description;
  final String? url;

  const JiraIssueEntity({
    required this.key,
    required this.summary,
    required this.status,
    this.assignee,
    this.priority,
    this.description,
    this.url,
  });
}
