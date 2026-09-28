/// AI Agent 워크플로우 실행 엔진
/// 
/// 단계:
/// 1. VOC 수신 (Receive)
/// 2. 업무 관련 여부 판정 (Analyze Business)
/// 3. 카테고리 분류 (Classify Category)
/// 4. 긴급도 예측 (Predict Urgency)
/// 5. 중복 VOC 검색 (Find Duplicates)
/// 6. 유사 VOC 검색 (Search Similar)
/// 7. 담당 부서 추천 (Recommend Department)
/// 8. 담당자 추천 (Recommend Assignee)
/// 9. 답변 초안 생성 (Generate Answer)
/// 10. JIRA 생성 필요 판단 (Check JIRA Need)
/// 11. Teams/Slack 알림 (Notify Teams/Slack)
/// 12. 승인 대기 (Wait Approval)

import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/data/services/ai_service.dart';

enum WorkflowStatus {
  pending,    // 대기 중
  inProgress, // 진행 중
  completed,  // 완료
  failed,     // 실패
  skipped,    // 건너뜀
}

/// 개별 워크플로우 단계
class WorkflowStep {
  final String id;
  final String name;
  final String description;
  final int order;
  
  WorkflowStatus status;
  DateTime? startTime;
  DateTime? endTime;
  String? result;
  String? errorMessage;

  WorkflowStep({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
    this.status = WorkflowStatus.pending,
    this.startTime,
    this.endTime,
    this.result,
    this.errorMessage,
  });

  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'order': order,
    'status': status.toString(),
    'startTime': startTime?.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'result': result,
    'errorMessage': errorMessage,
    'durationMs': duration?.inMilliseconds,
  };
}

/// 워크플로우 실행 기록
class WorkflowExecution {
  final String id;
  final String vocId;
  final DateTime startTime;
  DateTime? endTime;
  
  final List<WorkflowStep> steps = [];
  String? overallResult;
  String? overallError;

  WorkflowExecution({
    required this.id,
    required this.vocId,
    required this.startTime,
    this.endTime,
  });

  /// 현재 실행 중인 단계
  WorkflowStep? get currentStep {
    try {
      return steps.firstWhere((s) => s.status == WorkflowStatus.inProgress);
    } catch (e) {
      return null;
    }
  }

  /// 모든 단계 완료 여부
  bool get isCompleted {
    return endTime != null && steps.every((s) => 
      s.status == WorkflowStatus.completed || 
      s.status == WorkflowStatus.skipped ||
      s.status == WorkflowStatus.failed);
  }

  /// 실행 시간 (초)
  double get executionTimeSeconds {
    if (endTime == null) return 0;
    return endTime!.difference(startTime).inMilliseconds / 1000;
  }

  /// 단계별 성공률
  double get successRate {
    if (steps.isEmpty) return 0;
    final completed = steps.where((s) => s.status == WorkflowStatus.completed).length;
    return completed / steps.length;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vocId': vocId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'overallResult': overallResult,
    'overallError': overallError,
    'steps': steps.map((s) => s.toJson()).toList(),
    'executionTimeSeconds': executionTimeSeconds,
    'successRate': successRate,
  };
}

/// AI Agent 워크플로우 엔진
abstract class WorkflowEngine {
  /// 새 VOC에 대해 전체 워크플로우 실행
  Future<WorkflowExecution> executeVocWorkflow(
    VocEntity voc,
    AiService aiService,
  );

  /// 특정 단계만 재실행
  Future<WorkflowExecution> retryStep(
    WorkflowExecution execution,
    String stepId,
    AiService aiService,
  );

  /// 실행 중단
  Future<void> cancelWorkflow(String executionId);

  /// 실행 이력 조회
  Future<List<WorkflowExecution>> getExecutionHistory(String vocId);

  /// 실행 통계
  Future<Map<String, dynamic>> getExecutionStats();
}

/// 워크플로우 콜백 리스너
typedef WorkflowStepCallback = Future<void> Function(
  WorkflowStep step,
  WorkflowStatus status,
);

typedef WorkflowCompleteCallback = Future<void> Function(
  WorkflowExecution execution,
);
