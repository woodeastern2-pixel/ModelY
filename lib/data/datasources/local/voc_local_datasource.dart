import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/voc_category_catalog.dart';
import '../../../domain/entities/voc_entity.dart';
import '../../../domain/entities/response_entity.dart';

class VocLocalDatasource {
  final DatabaseHelper _dbHelper;
  static final RegExp _tokenPattern = RegExp(r'[A-Za-z0-9가-힣]{2,}');
  static const Set<String> _keywordStopwords = {
    'the', 'and', 'for', 'with', 'this', 'that', 'from', 'are', 'was', 'were',
    '있습니다', '문의', '요청', '확인', '처리', '관련', '대한', '합니다', '입니다', '해주세요',
    '기능', '오류', '이슈', '사용', '고객', '서비스',
  };

  VocLocalDatasource(this._dbHelper);

  Future<List<VocEntity>> getAllVocs() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableVocs,
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToVoc).toList();
  }

  Future<VocEntity?> getVocById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableVocs,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _mapToVoc(maps.first);
  }

  Future<List<VocEntity>> getVocsByStatus(String status) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableVocs,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToVoc).toList();
  }

  Future<List<VocEntity>> getVocsByCategory(String category) async {
    final normalizedCategory = VocCategoryCatalog.normalize(category);
    final all = await getAllVocs();
    return all.where((voc) => voc.category == normalizedCategory).toList();
  }

  Future<List<VocEntity>> searchVocs(String query) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableVocs,
      where: 'title LIKE ? OR content LIKE ? OR customer LIKE ? OR project LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToVoc).toList();
  }

  Future<VocEntity> insertVoc(VocEntity voc) async {
    final db = await _dbHelper.database;
    await db.insert(AppConstants.tableVocs, _vocToMap(voc));
    return voc;
  }

  Future<VocEntity> updateVoc(VocEntity voc) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tableVocs,
      _vocToMap(voc),
      where: 'id = ?',
      whereArgs: [voc.id],
    );
    return voc;
  }

  Future<int> reassignAllVocCategories() async {
    final db = await _dbHelper.database;
    final rows = await db.query(AppConstants.tableVocs);
    var updatedCount = 0;

    for (final row in rows) {
      final normalized = VocCategoryCatalog.recategorize(
        currentCategory: row['category'] as String?,
        title: row['title'] as String?,
        content: row['content'] as String?,
        aiCategory: row['ai_category'] as String?,
        tags: row['tags'] as String?,
      );
      final current = (row['category'] as String? ?? '').trim();
      if (current == normalized) {
        continue;
      }

      await db.update(
        AppConstants.tableVocs,
        {
          'category': normalized,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      updatedCount++;
    }

    return updatedCount;
  }

  Future<void> deleteVoc(String id) async {
    final db = await _dbHelper.database;
    await db.delete(AppConstants.tableVocs, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getVocCountByStatus() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT status, COUNT(*) as count FROM ${AppConstants.tableVocs} GROUP BY status',
    );
    return {for (final row in result) row['status'] as String: row['count'] as int};
  }

  Future<Map<String, int>> getVocCountByCategory() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT category, COUNT(*) as count FROM ${AppConstants.tableVocs} GROUP BY category',
    );
    return VocCategoryCatalog.aggregateCounts({
      for (final row in result)
        (row['category'] as String? ?? VocCategoryCatalog.fallbackCategory):
            row['count'] as int,
    });
  }

  Future<List<Map<String, dynamic>>> getMonthlyStats() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', created_at) as month,
        COUNT(*) as total,
        SUM(CASE WHEN status = 'RESOLVED' THEN 1 ELSE 0 END) as resolved
      FROM ${AppConstants.tableVocs}
      WHERE created_at >= date('now', '-12 months')
      GROUP BY month
      ORDER BY month ASC
    ''');
  }

  Future<Map<String, dynamic>> getAdvancedMetrics() async {
    final db = await _dbHelper.database;

    final totalVocQ = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${AppConstants.tableVocs}',
    );
    final total = (totalVocQ.first['c'] as int?) ?? 0;

    final dupQ = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${AppConstants.tableVocs} WHERE duplicate_score >= 0.85',
    );
    final duplicateCount = (dupQ.first['c'] as int?) ?? 0;

    final aiRespQ = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${AppConstants.tableResponses} WHERE ai_generated = 1',
    );
    final totalRespQ = await db.rawQuery(
      'SELECT COUNT(*) as c FROM ${AppConstants.tableResponses}',
    );
    final aiResponses = (aiRespQ.first['c'] as int?) ?? 0;
    final totalResponses = (totalRespQ.first['c'] as int?) ?? 0;

    final avgProcessQ = await db.rawQuery('''
      SELECT AVG(
        (julianday(updated_at) - julianday(created_at)) * 24 * 60
      ) as avg_minutes
      FROM ${AppConstants.tableVocs}
      WHERE status = 'RESOLVED'
    ''');
    final avgMinutes = (avgProcessQ.first['avg_minutes'] as num?)?.toDouble() ?? 0.0;

    final monthlyDup = await db.rawQuery('''
      SELECT strftime('%Y-%m', created_at) as month,
             COUNT(*) as total,
             SUM(CASE WHEN duplicate_score >= 0.85 THEN 1 ELSE 0 END) as dup
      FROM ${AppConstants.tableVocs}
      WHERE created_at >= date('now', '-6 months')
      GROUP BY month
      ORDER BY month ASC
    ''');

    double duplicateReductionRate = 0.0;
    if (monthlyDup.length >= 2) {
      final first = monthlyDup.first;
      final last = monthlyDup.last;
      final firstRate = ((first['dup'] as int?) ?? 0) /
          ((((first['total'] as int?) ?? 0) == 0) ? 1 : (first['total'] as int));
      final lastRate = ((last['dup'] as int?) ?? 0) /
          ((((last['total'] as int?) ?? 0) == 0) ? 1 : (last['total'] as int));
      duplicateReductionRate = (firstRate - lastRate).clamp(-1.0, 1.0);
    }

    return {
      'duplicateCount': duplicateCount,
      'duplicateRate': total == 0 ? 0.0 : duplicateCount / total,
      'duplicateReductionRate': duplicateReductionRate,
      'aiUsageRate': totalResponses == 0 ? 0.0 : aiResponses / totalResponses,
      'avgProcessMinutes': avgMinutes,
      'totalResponses': totalResponses,
    };
  }

  Future<List<Map<String, dynamic>>> getTopAssigneeStats({int topN = 3}) async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT assignee,
             COUNT(*) as handled,
             AVG(COALESCE(assignee_score, 0)) as accuracy
      FROM ${AppConstants.tableVocs}
      WHERE assignee IS NOT NULL AND assignee != ''
      GROUP BY assignee
      ORDER BY handled DESC
      LIMIT ?
    ''', [topN]);
  }

  Future<Map<String, dynamic>> getExecutiveInsightMetrics() async {
    final db = await _dbHelper.database;
    final vocRows = await db.query(
      AppConstants.tableVocs,
      columns: ['id', 'title', 'content', 'customer', 'priority', 'status', 'created_at'],
    );
    final responseRows = await db.rawQuery('''
      SELECT voc_id, COUNT(*) as cnt
      FROM ${AppConstants.tableResponses}
      GROUP BY voc_id
    ''');

    final responseCountByVocId = <String, int>{
      for (final row in responseRows)
        (row['voc_id'] as String): (row['cnt'] as int? ?? 0),
    };

    var resolvedCount = 0;
    var reopenedCount = 0;
    for (final row in vocRows) {
      final status = row['status'] as String? ?? '';
      if (status == AppConstants.vocStatusResolved) {
        resolvedCount += 1;
        final vocId = row['id'] as String;
        if ((responseCountByVocId[vocId] ?? 0) >= 2) {
          reopenedCount += 1;
        }
      }
    }
    final reopenRate = resolvedCount == 0 ? 0.0 : reopenedCount / resolvedCount;

    final now = DateTime.now();
    final recentStart = now.subtract(const Duration(days: 30));
    final previousStart = now.subtract(const Duration(days: 60));

    final recentCounts = <String, int>{};
    final previousCounts = <String, int>{};
    final segmentStats = <String, _SegmentAccumulator>{};

    for (final row in vocRows) {
      final title = (row['title'] as String? ?? '').toLowerCase();
      final content = (row['content'] as String? ?? '').toLowerCase();
      final createdAtRaw = row['created_at'] as String?;
      final createdAt = createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw)?.toLocal();
      final mergedText = '$title $content';
      final tokens = _extractKeywords(mergedText);

      if (createdAt != null) {
        if (createdAt.isAfter(recentStart)) {
          for (final token in tokens) {
            recentCounts[token] = (recentCounts[token] ?? 0) + 1;
          }
        } else if (createdAt.isAfter(previousStart)) {
          for (final token in tokens) {
            previousCounts[token] = (previousCounts[token] ?? 0) + 1;
          }
        }
      }

      final segment = _normalizeCustomerSegment(row['customer'] as String?);
      final priority = row['priority'] as String? ?? '';
      final status = row['status'] as String? ?? '';
      final acc = segmentStats.putIfAbsent(segment, () => _SegmentAccumulator());
      acc.total += 1;
      if (priority == AppConstants.priorityHigh) {
        acc.highPriority += 1;
      }
      if (status != AppConstants.vocStatusResolved) {
        acc.unresolved += 1;
      }
    }

    String risingKeyword = '-';
    var risingDelta = 0;
    recentCounts.forEach((keyword, recent) {
      final previous = previousCounts[keyword] ?? 0;
      final delta = recent - previous;
      if (recent >= 2 && delta > risingDelta) {
        risingDelta = delta;
        risingKeyword = keyword;
      }
    });

    String topSegmentName = '-';
    var topSegmentScore = 0.0;
    var topSegmentVolume = 0;
    segmentStats.forEach((name, acc) {
      if (acc.total == 0) return;
      final highRate = acc.highPriority / acc.total;
      final unresolvedRate = acc.unresolved / acc.total;
      final score = (acc.total * 6) + (highRate * 45) + (unresolvedRate * 35);
      if (score > topSegmentScore) {
        topSegmentScore = score;
        topSegmentName = name;
        topSegmentVolume = acc.total;
      }
    });

    return {
      'reopenRate': reopenRate.clamp(0.0, 1.0),
      'reopenedCount': reopenedCount,
      'resolvedCount': resolvedCount,
      'risingKeyword': risingKeyword,
      'risingKeywordDelta': risingDelta,
      'topSegmentName': topSegmentName,
      'topSegmentScore': topSegmentScore.clamp(0.0, 100.0),
      'topSegmentVolume': topSegmentVolume,
    };
  }

  Set<String> _extractKeywords(String text) {
    final matches = _tokenPattern.allMatches(text);
    final tokens = <String>{};
    for (final m in matches) {
      final token = m.group(0)?.trim().toLowerCase() ?? '';
      if (token.length < 2) continue;
      if (_keywordStopwords.contains(token)) continue;
      tokens.add(token);
    }
    return tokens;
  }

  String _normalizeCustomerSegment(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '미분류';
    final split = value.split(RegExp(r'[\s\-_/()\[\]]+'));
    final first = split.isEmpty ? value : split.first;
    return first.isEmpty ? '미분류' : first;
  }

  // Responses
  Future<List<ResponseEntity>> getResponsesByVocId(String vocId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableResponses,
      where: 'voc_id = ?',
      whereArgs: [vocId],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToResponse).toList();
  }

  Future<ResponseEntity> insertResponse(ResponseEntity response) async {
    final db = await _dbHelper.database;
    await db.insert(AppConstants.tableResponses, _responseToMap(response));
    return response;
  }

  Future<ResponseEntity> updateResponse(ResponseEntity response) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tableResponses,
      _responseToMap(response),
      where: 'id = ?',
      whereArgs: [response.id],
    );
    return response;
  }

  Future<void> deleteResponse(String id) async {
    final db = await _dbHelper.database;
    await db.delete(AppConstants.tableResponses, where: 'id = ?', whereArgs: [id]);
  }

  // Mappers
  VocEntity _mapToVoc(Map<String, dynamic> map) {
    List<double>? embedding;
    final embJson = map['embedding'] as String?;
    if (embJson != null && embJson.isNotEmpty) {
      embedding = List<double>.from(jsonDecode(embJson));
    }
    return VocEntity(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      category: VocCategoryCatalog.normalize(
        map['category'] as String?,
        title: map['title'] as String?,
        content: map['content'] as String?,
        aiCategory: map['ai_category'] as String?,
        tags: map['tags'] as String?,
      ),
      tags: map['tags'] as String?,
      customer: map['customer'] as String,
      project: map['project'] as String,
      priority: map['priority'] as String,
      status: map['status'] as String,
      aiCategory: map['ai_category'] as String?,
      isBusinessRelated: (map['is_business_related'] as int) == 1,
      businessScore: (map['business_score'] as num?)?.toDouble(),
      categoryScore: (map['category_score'] as num?)?.toDouble(),
      urgency: map['urgency'] as String?,
      urgencyScore: (map['urgency_score'] as num?)?.toDouble(),
      businessType: map['business_type'] as String?,
      department: map['department'] as String?,
      departmentScore: (map['department_score'] as num?)?.toDouble(),
      assignee: map['assignee'] as String?,
      assigneeScore: (map['assignee_score'] as num?)?.toDouble(),
      duplicateOfVocId: map['duplicate_of_voc_id'] as String?,
      duplicateScore: (map['duplicate_score'] as num?)?.toDouble(),
      jiraRequired: (map['jira_required'] as int? ?? 0) == 1,
      jiraScore: (map['jira_score'] as num?)?.toDouble(),
      analysisReason: map['analysis_reason'] as String?,
      embedding: embedding,
      source: map['source'] as String?,
      sourceRef: map['source_ref'] as String?,
      processingMinutes: map['processing_minutes'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> _vocToMap(VocEntity voc) {
    final normalizedCategory = VocCategoryCatalog.normalize(
      voc.category,
      title: voc.title,
      content: voc.content,
      aiCategory: voc.aiCategory,
      tags: voc.tags,
    );
    return {
      'id': voc.id,
      'title': voc.title,
      'content': voc.content,
      'category': normalizedCategory,
      'tags': voc.tags,
      'customer': voc.customer,
      'project': voc.project,
      'priority': voc.priority,
      'status': voc.status,
      'ai_category': voc.aiCategory,
      'is_business_related': voc.isBusinessRelated ? 1 : 0,
      'business_score': voc.businessScore,
      'category_score': voc.categoryScore,
      'urgency': voc.urgency,
      'urgency_score': voc.urgencyScore,
      'business_type': voc.businessType,
      'department': voc.department,
      'department_score': voc.departmentScore,
      'assignee': voc.assignee,
      'assignee_score': voc.assigneeScore,
      'duplicate_of_voc_id': voc.duplicateOfVocId,
      'duplicate_score': voc.duplicateScore,
      'jira_required': voc.jiraRequired ? 1 : 0,
      'jira_score': voc.jiraScore,
      'analysis_reason': voc.analysisReason,
      'embedding': voc.embedding == null ? null : jsonEncode(voc.embedding),
      'source': voc.source,
      'source_ref': voc.sourceRef,
      'processing_minutes': voc.processingMinutes,
      'created_at': voc.createdAt.toIso8601String(),
      'updated_at': voc.updatedAt.toIso8601String(),
    };
  }

  ResponseEntity _mapToResponse(Map<String, dynamic> map) {
    List<String> refs = [];
    final refsJson = map['referenced_voc_ids'];
    if (refsJson != null && (refsJson as String).isNotEmpty) {
      refs = List<String>.from(jsonDecode(refsJson));
    }
    return ResponseEntity(
      id: map['id'] as String,
      vocId: map['voc_id'] as String,
      content: map['content'] as String,
      status: map['status'] as String,
      aiGenerated: (map['ai_generated'] as int) == 1,
      confidenceScore: map['confidence_score'] as double?,
      referencedVocIds: refs,
      approvedBy: map['approved_by'] as String?,
      approvedAt: map['approved_at'] != null
          ? DateTime.parse(map['approved_at'] as String)
          : null,
        adoptionCount: map['adoption_count'] as int? ?? 0,
        usageCount: map['usage_count'] as int? ?? 0,
        lastUsedAt: map['last_used_at'] != null
          ? DateTime.parse(map['last_used_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> _responseToMap(ResponseEntity r) {
    return {
      'id': r.id,
      'voc_id': r.vocId,
      'content': r.content,
      'status': r.status,
      'ai_generated': r.aiGenerated ? 1 : 0,
      'confidence_score': r.confidenceScore,
      'referenced_voc_ids': jsonEncode(r.referencedVocIds),
      'approved_by': r.approvedBy,
      'approved_at': r.approvedAt?.toIso8601String(),
      'adoption_count': r.adoptionCount,
      'usage_count': r.usageCount,
      'last_used_at': r.lastUsedAt?.toIso8601String(),
      'created_at': r.createdAt.toIso8601String(),
      'updated_at': r.updatedAt.toIso8601String(),
    };
  }
}

class _SegmentAccumulator {
  int total = 0;
  int highPriority = 0;
  int unresolved = 0;
}
