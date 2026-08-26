/// Agent 실행 로그 엔티티
/// 각 워크플로우 실행 단계를 추적하고 기록

class AgentLog {
  final String? id;
  final String vocId;
  final String workflowId;
  final int stepIndex;
  final String stepName;
  final String stepId;
  final String status; // pending, inProgress, completed, failed, skipped
  final DateTime startTime;
  final DateTime? endTime;
  final String? resultJson; // JSON 결과 저장
  final String? errorMessage;
  final int? durationMs;
  final DateTime createdAt;

  AgentLog({
    this.id,
    required this.vocId,
    required this.workflowId,
    required this.stepIndex,
    required this.stepName,
    required this.stepId,
    required this.status,
    required this.startTime,
    this.endTime,
    this.resultJson,
    this.errorMessage,
    this.durationMs,
    required this.createdAt,
  });

  /// Map으로 변환 (DB 저장용)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'voc_id': vocId,
      'workflow_id': workflowId,
      'step_index': stepIndex,
      'step_name': stepName,
      'step_id': stepId,
      'status': status,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'result_json': resultJson,
      'error_message': errorMessage,
      'duration_ms': durationMs,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Map에서 변환 (DB 로드용)
  factory AgentLog.fromMap(Map<String, dynamic> map) {
    return AgentLog(
      id: map['id'] as String?,
      vocId: map['voc_id'] as String,
      workflowId: map['workflow_id'] as String,
      stepIndex: map['step_index'] as int,
      stepName: map['step_name'] as String,
      stepId: map['step_id'] as String,
      status: map['status'] as String,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null
          ? DateTime.parse(map['end_time'] as String)
          : null,
      resultJson: map['result_json'] as String?,
      errorMessage: map['error_message'] as String?,
      durationMs: map['duration_ms'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// 복사본 생성
  AgentLog copyWith({
    String? id,
    String? vocId,
    String? workflowId,
    int? stepIndex,
    String? stepName,
    String? stepId,
    String? status,
    DateTime? startTime,
    DateTime? endTime,
    String? resultJson,
    String? errorMessage,
    int? durationMs,
    DateTime? createdAt,
  }) {
    return AgentLog(
      id: id ?? this.id,
      vocId: vocId ?? this.vocId,
      workflowId: workflowId ?? this.workflowId,
      stepIndex: stepIndex ?? this.stepIndex,
      stepName: stepName ?? this.stepName,
      stepId: stepId ?? this.stepId,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      resultJson: resultJson ?? this.resultJson,
      errorMessage: errorMessage ?? this.errorMessage,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Agent 실행 통계
class AgentLogStats {
  final int totalWorkflows;
  final int completedWorkflows;
  final int failedWorkflows;
  final double averageExecutionTimeSeconds;
  final double successRate;
  final Map<String, int> stepSuccessCount; // stepName -> count
  final Map<String, int> stepFailureCount; // stepName -> count

  AgentLogStats({
    required this.totalWorkflows,
    required this.completedWorkflows,
    required this.failedWorkflows,
    required this.averageExecutionTimeSeconds,
    required this.successRate,
    required this.stepSuccessCount,
    required this.stepFailureCount,
  });

  /// 특정 단계의 성공률
  double getStepSuccessRate(String stepName) {
    final success = stepSuccessCount[stepName] ?? 0;
    final failure = stepFailureCount[stepName] ?? 0;
    final total = success + failure;
    if (total == 0) return 0;
    return success / total;
  }
}
