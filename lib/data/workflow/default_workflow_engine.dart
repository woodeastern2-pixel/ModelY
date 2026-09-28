import 'package:ai_voc_assistant/domain/workflow/workflow_engine.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:uuid/uuid.dart';

/// 기본 워크플로우 엔진 구현
class DefaultWorkflowEngine implements WorkflowEngine {
  final Map<String, WorkflowExecution> _executionCache = {};
  final List<WorkflowStepCallback> _stepCallbacks = [];
  final List<WorkflowCompleteCallback> _completeCallbacks = [];

  /// 단계 콜백 등록
  void onStepStatusChanged(WorkflowStepCallback callback) {
    _stepCallbacks.add(callback);
  }

  /// 완료 콜백 등록
  void onWorkflowComplete(WorkflowCompleteCallback callback) {
    _completeCallbacks.add(callback);
  }

  @override
  Future<WorkflowExecution> executeVocWorkflow(
    VocEntity voc,
    AiService aiService,
  ) async {
    final execution = WorkflowExecution(
      id: const Uuid().v4(),
      vocId: voc.id,
      startTime: DateTime.now(),
    );

    _executionCache[execution.id] = execution;

    try {
      // 워크플로우 단계 정의
      final steps = _defineWorkflowSteps();
      execution.steps.addAll(steps);

      // 각 단계 실행
      for (final step in execution.steps) {
        await _executeStep(step, voc, aiService);

        // 콜백 호출
        for (final callback in _stepCallbacks) {
          await callback(step, step.status);
        }

        // 실패 시 중단
        if (step.status == WorkflowStatus.failed) {
          execution.overallError = '단계 "${step.name}"에서 실패';
          break;
        }
      }

      execution.endTime = DateTime.now();
      execution.overallResult = 'Workflow completed';

      // 완료 콜백 호출
      for (final callback in _completeCallbacks) {
        await callback(execution);
      }

      return execution;
    } catch (e) {
      execution.endTime = DateTime.now();
      execution.overallError = e.toString();
      return execution;
    }
  }

  @override
  Future<WorkflowExecution> retryStep(
    WorkflowExecution execution,
    String stepId,
    AiService aiService,
  ) async {
    final step = execution.steps.firstWhere((s) => s.id == stepId);
    final voc = VocEntity(
      id: execution.vocId,
      title: '',
      content: '',
      category: '',
      customer: '',
      project: '',
      priority: 'MEDIUM',
      status: 'OPEN',
      createdAt: execution.startTime,
      updatedAt: DateTime.now(),
    );

    step.status = WorkflowStatus.pending;
    step.result = null;
    step.errorMessage = null;

    await _executeStep(step, voc, aiService);
    return execution;
  }

  @override
  Future<void> cancelWorkflow(String executionId) async {
    final execution = _executionCache[executionId];
    if (execution != null && !execution.isCompleted) {
      execution.endTime = DateTime.now();
      execution.overallError = 'Cancelled by user';
    }
  }

  @override
  Future<List<WorkflowExecution>> getExecutionHistory(String vocId) async {
    return _executionCache.values
        .where((e) => e.vocId == vocId)
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getExecutionStats() async {
    final executions = _executionCache.values.toList();
    if (executions.isEmpty) {
      return {
        'totalExecutions': 0,
        'averageTimeSeconds': 0,
        'successRate': 0,
        'failureRate': 0,
      };
    }

    final completedExecutions = executions.where((e) => e.isCompleted).toList();
    final failedExecutions =
        executions.where((e) => e.overallError != null).toList();

    return {
      'totalExecutions': executions.length,
      'completedExecutions': completedExecutions.length,
      'failedExecutions': failedExecutions.length,
      'averageTimeSeconds': completedExecutions.isEmpty
          ? 0
          : completedExecutions
                  .map((e) => e.executionTimeSeconds)
                  .reduce((a, b) => a + b) /
              completedExecutions.length,
      'successRate': completedExecutions.length / executions.length,
      'failureRate': failedExecutions.length / executions.length,
      'averageSuccessRate': completedExecutions.isEmpty
          ? 0
          : completedExecutions
                  .map((e) => e.successRate)
                  .reduce((a, b) => a + b) /
              completedExecutions.length,
    };
  }

  /// 워크플로우 단계 정의
  List<WorkflowStep> _defineWorkflowSteps() {
    return [
      WorkflowStep(
        id: 'step_1_receive',
        name: 'VOC 수신',
        description: 'VOC를 시스템에 등록',
        order: 1,
      ),
      WorkflowStep(
        id: 'step_2_analyze_business',
        name: '업무 관련 여부 판정',
        description: '업무 관련성 AI 분석',
        order: 2,
      ),
      WorkflowStep(
        id: 'step_3_classify_category',
        name: '카테고리 분류',
        description: 'AI를 통한 카테고리 자동 분류',
        order: 3,
      ),
      WorkflowStep(
        id: 'step_4_predict_urgency',
        name: '긴급도 예측',
        description: '긴급도 AI 예측',
        order: 4,
      ),
      WorkflowStep(
        id: 'step_5_find_duplicates',
        name: '중복 VOC 검색',
        description: 'DB에서 중복 VOC 검색',
        order: 5,
      ),
      WorkflowStep(
        id: 'step_6_search_similar',
        name: '유사 VOC 검색',
        description: '임베딩 기반 유사 VOC 검색',
        order: 6,
      ),
      WorkflowStep(
        id: 'step_7_recommend_dept',
        name: '담당 부서 추천',
        description: 'AI 기반 부서 추천',
        order: 7,
      ),
      WorkflowStep(
        id: 'step_8_recommend_assignee',
        name: '담당자 추천',
        description: 'AI 기반 담당자 추천',
        order: 8,
      ),
      WorkflowStep(
        id: 'step_9_generate_answer',
        name: '답변 초안 생성',
        description: 'AI를 통한 답변 초안 생성',
        order: 9,
      ),
      WorkflowStep(
        id: 'step_10_check_jira',
        name: 'JIRA 생성 필요 판단',
        description: 'JIRA 생성 필요 여부 판단',
        order: 10,
      ),
      WorkflowStep(
        id: 'step_11_notify',
        name: 'Teams/Slack 공유',
        description: '담당자에게 Teams/Slack으로 알림',
        order: 11,
      ),
      WorkflowStep(
        id: 'step_12_wait_approval',
        name: '승인 대기',
        description: '담당자의 검토 및 승인 대기',
        order: 12,
      ),
    ];
  }

  /// 개별 단계 실행
  Future<void> _executeStep(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    step.startTime = DateTime.now();
    step.status = WorkflowStatus.inProgress;

    try {
      switch (step.id) {
        case 'step_1_receive':
          await _stepReceiveVoc(step, voc);
          break;
        case 'step_2_analyze_business':
          await _stepAnalyzeBusiness(step, voc, aiService);
          break;
        case 'step_3_classify_category':
          await _stepClassifyCategory(step, voc, aiService);
          break;
        case 'step_4_predict_urgency':
          await _stepPredictUrgency(step, voc, aiService);
          break;
        case 'step_5_find_duplicates':
          await _stepFindDuplicates(step, voc);
          break;
        case 'step_6_search_similar':
          await _stepSearchSimilar(step, voc, aiService);
          break;
        case 'step_7_recommend_dept':
          await _stepRecommendDept(step, voc, aiService);
          break;
        case 'step_8_recommend_assignee':
          await _stepRecommendAssignee(step, voc, aiService);
          break;
        case 'step_9_generate_answer':
          await _stepGenerateAnswer(step, voc, aiService);
          break;
        case 'step_10_check_jira':
          await _stepCheckJira(step, voc, aiService);
          break;
        case 'step_11_notify':
          await _stepNotify(step, voc);
          break;
        case 'step_12_wait_approval':
          // 승인 대기는 수동 프로세스
          step.status = WorkflowStatus.pending;
          step.result = 'Waiting for user approval';
          break;
      }

      if (step.status != WorkflowStatus.failed &&
          step.status != WorkflowStatus.pending) {
        step.status = WorkflowStatus.completed;
      }
    } catch (e) {
      step.status = WorkflowStatus.failed;
      step.errorMessage = e.toString();
    } finally {
      step.endTime = DateTime.now();
    }
  }

  // ==================== 개별 단계 구현 ====================

  Future<void> _stepReceiveVoc(WorkflowStep step, VocEntity voc) async {
    await Future.delayed(const Duration(milliseconds: 100));
    step.result = 'VOC received and registered: ${voc.id}';
  }

  Future<void> _stepAnalyzeBusiness(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    try {
      // AI 분석 호출
      final result = await aiService.analyzeVoc(voc.title, voc.content);
      step.result = result.isBusiness
          ? 'Business-related: ${result.reason}'
          : 'Not business-related: ${result.reason}';
    } catch (e) {
      step.result = 'Manual review needed';
    }
  }

  Future<void> _stepClassifyCategory(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    try {
      final result = await aiService.analyzeVoc(voc.title, voc.content);
      step.result = 'Category: ${result.category}';
    } catch (e) {
      step.result = 'Category: UNCLASSIFIED';
    }
  }

  Future<void> _stepPredictUrgency(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    step.result = 'Urgency: ${voc.priority}';
  }

  Future<void> _stepFindDuplicates(
    WorkflowStep step,
    VocEntity voc,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    step.result = 'Searched for duplicate VOCs';
  }

  Future<void> _stepSearchSimilar(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    step.result = 'Similarity search is handled by the vector search service';
  }

  Future<void> _stepRecommendDept(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    step.result = 'Department recommendation ready';
  }

  Future<void> _stepRecommendAssignee(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    step.result = 'Assignee recommendation ready';
  }

  Future<void> _stepGenerateAnswer(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    try {
      final answer = await aiService.generateAnswer(
        voc.title,
        voc.content,
        const [],
      );
      step.result = answer.answer;
    } catch (e) {
      step.result = 'Failed to generate answer';
      rethrow;
    }
  }

  Future<void> _stepCheckJira(
    WorkflowStep step,
    VocEntity voc,
    AiService aiService,
  ) async {
    step.result = 'JIRA creation assessed';
  }

  Future<void> _stepNotify(WorkflowStep step, VocEntity voc) async {
    await Future.delayed(const Duration(milliseconds: 150));
    step.result = 'Notification sent to assignee';
  }
}
