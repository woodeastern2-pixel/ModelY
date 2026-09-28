import 'package:sqflite/sqflite.dart';
import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/core/database/database_helper.dart';
import 'package:ai_voc_assistant/domain/entities/agent_log_entity.dart';
import 'package:uuid/uuid.dart';

/// Agent 실행 로그 데이터소스
class AgentLogLocalDataSource {
  final DatabaseHelper _dbHelper;

  AgentLogLocalDataSource(this._dbHelper);

  /// 로그 저장
  Future<AgentLog> saveLog({
    required String vocId,
    required String workflowId,
    required int stepIndex,
    required String stepName,
    required String stepId,
    required String status,
    required DateTime startTime,
    DateTime? endTime,
    String? resultJson,
    String? errorMessage,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final durationMs = endTime != null 
        ? endTime.difference(startTime).inMilliseconds
        : null;

    final log = AgentLog(
      id: const Uuid().v4(),
      vocId: vocId,
      workflowId: workflowId,
      stepIndex: stepIndex,
      stepName: stepName,
      stepId: stepId,
      status: status,
      startTime: startTime,
      endTime: endTime,
      resultJson: resultJson,
      errorMessage: errorMessage,
      durationMs: durationMs,
      createdAt: now,
    );

    await db.insert(
      AppConstants.tableAgentLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return log;
  }

  /// 특정 VOC의 모든 로그 조회
  Future<List<AgentLog>> getLogsByVocId(String vocId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableAgentLogs,
      where: 'voc_id = ?',
      whereArgs: [vocId],
      orderBy: 'step_index ASC',
    );

    return maps.map((map) => AgentLog.fromMap(map)).toList();
  }

  /// 특정 워크플로우의 모든 로그 조회
  Future<List<AgentLog>> getLogsByWorkflowId(String workflowId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableAgentLogs,
      where: 'workflow_id = ?',
      whereArgs: [workflowId],
      orderBy: 'step_index ASC',
    );

    return maps.map((map) => AgentLog.fromMap(map)).toList();
  }

  /// 최근 N개의 로그 조회 (전체)
  Future<List<AgentLog>> getRecentLogs({int limit = 50}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableAgentLogs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((map) => AgentLog.fromMap(map)).toList();
  }

  /// 특정 단계별 실행 통계
  Future<AgentLogStats> getExecutionStats() async {
    final db = await _dbHelper.database;
    
    // 전체 워크플로우 수 (workflow_id 별 unique)
    final workflowResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT workflow_id) as count FROM ${AppConstants.tableAgentLogs}'
    );
    final totalWorkflows = (workflowResult.first['count'] as int?) ?? 0;

    // 완료된 워크플로우 수
    final completedResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT workflow_id) as count '
      'FROM ${AppConstants.tableAgentLogs} '
      'WHERE status = ?',
      ['completed']
    );
    final completedWorkflows = (completedResult.first['count'] as int?) ?? 0;

    // 실패한 워크플로우 수
    final failedResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT workflow_id) as count '
      'FROM ${AppConstants.tableAgentLogs} '
      'WHERE status = ?',
      ['failed']
    );
    final failedWorkflows = (failedResult.first['count'] as int?) ?? 0;

    // 평균 실행 시간
    final avgTimeResult = await db.rawQuery(
      'SELECT AVG(duration_ms) as avg_ms FROM ${AppConstants.tableAgentLogs} WHERE duration_ms IS NOT NULL'
    );
    final avgTimeMs = ((avgTimeResult.first['avg_ms'] as num?) ?? 0).toDouble();
    final avgTimeSeconds = avgTimeMs / 1000;

    // 단계별 성공/실패 카운트
    final stepResult = await db.rawQuery(
      'SELECT step_name, status, COUNT(*) as count '
      'FROM ${AppConstants.tableAgentLogs} '
      'GROUP BY step_name, status'
    );

    final stepSuccessCount = <String, int>{};
    final stepFailureCount = <String, int>{};

    for (final row in stepResult) {
      final stepName = row['step_name'] as String;
      final status = row['status'] as String;
      final count = (row['count'] as int?) ?? 0;

      if (status == 'completed') {
        stepSuccessCount[stepName] = (stepSuccessCount[stepName] ?? 0) + count;
      } else if (status == 'failed') {
        stepFailureCount[stepName] = (stepFailureCount[stepName] ?? 0) + count;
      }
    }

    final successRate = totalWorkflows == 0 
        ? 0.0 
        : completedWorkflows / totalWorkflows;

    return AgentLogStats(
      totalWorkflows: totalWorkflows,
      completedWorkflows: completedWorkflows,
      failedWorkflows: failedWorkflows,
      averageExecutionTimeSeconds: avgTimeSeconds,
      successRate: successRate,
      stepSuccessCount: stepSuccessCount,
      stepFailureCount: stepFailureCount,
    );
  }

  /// 로그 삭제 (VOC 삭제 시)
  Future<int> deleteLogsByVocId(String vocId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.tableAgentLogs,
      where: 'voc_id = ?',
      whereArgs: [vocId],
    );
  }

  /// 로그 업데이트 (완료/에러 처리)
  Future<void> updateLog(AgentLog log) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tableAgentLogs,
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  /// 오래된 로그 정리 (N일 이상 전)
  Future<int> deleteOldLogs({int daysOld = 30}) async {
    final db = await _dbHelper.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    
    return await db.delete(
      AppConstants.tableAgentLogs,
      where: 'created_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }
}
