import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/vector_utils.dart';
import '../../core/utils/voc_category_catalog.dart';
import '../../domain/entities/voc_entity.dart';
import '../../domain/repositories/voc_repository.dart';
import '../../presentation/viewmodels/settings_viewmodel.dart';
import '../datasources/local/voc_local_datasource.dart';
import '../repositories/voc_repository_impl.dart';
import 'webhook_service.dart';

class PeerVocPullResult {
  const PeerVocPullResult({
    required this.remoteTotal,
    required this.created,
    required this.updated,
    required this.failedApps,
    required this.successApps,
  });

  final int remoteTotal;
  final int created;
  final int updated;
  final int failedApps;
  final int successApps;
  int get applied => created + updated;
}

class PeerBootstrapResult {
  const PeerBootstrapResult({
    required this.vocRemoteTotal,
    required this.vocCreated,
    required this.vocUpdated,
    required this.manualRemoteTotal,
    required this.manualCreated,
    required this.manualSkipped,
    required this.failedApps,
    required this.successApps,
  });

  final int vocRemoteTotal;
  final int vocCreated;
  final int vocUpdated;
  final int manualRemoteTotal;
  final int manualCreated;
  final int manualSkipped;
  final int failedApps;
  final int successApps;
}

class PeerSyncService {
  PeerSyncService(this.settings)
      : _vocRepository = VocRepositoryImpl(VocLocalDatasource(DatabaseHelper.instance));

  final SettingsViewModel settings;
  final VocRepository _vocRepository;
  final WebhookService _webhook = WebhookService();
  final Uuid _uuid = const Uuid();

  Future<PeerVocPullResult> pullAllVocs() async {
    final targets = settings.vocForwardWebhookTargets;
    if (targets.isEmpty) throw StateError('가져올 대상 앱 URL이 없습니다.');

    var remoteTotal = 0;
    var created = 0;
    var updated = 0;
    var failedApps = 0;
    var successApps = 0;

    for (final target in targets) {
      try {
        final payload = await _webhook.getJsonForMap(
          url: _toExportEndpoint(target),
          headers: _authHeaders(),
        );
        successApps += 1;
        final sourceApp = _sourceApp(payload);
        final snapshot = payload['snapshot'] is Map
            ? Map<String, dynamic>.from(payload['snapshot'] as Map)
            : const <String, dynamic>{};
        final vocs = (snapshot['vocs'] as List?) ?? const [];
        remoteTotal += vocs.length;

        for (final item in vocs) {
          if (item is! Map) continue;
          final wasCreated = await _upsertRemoteVoc(
            sourceApp,
            Map<String, dynamic>.from(item),
            source: 'peer-pull',
          );
          if (wasCreated) {
            created += 1;
          } else {
            updated += 1;
          }
        }
      } catch (_) {
        failedApps += 1;
      }
    }

    return PeerVocPullResult(
      remoteTotal: remoteTotal,
      created: created,
      updated: updated,
      failedApps: failedApps,
      successApps: successApps,
    );
  }

  Future<PeerBootstrapResult> bootstrap() async {
    final targets = settings.vocForwardWebhookTargets;
    if (targets.isEmpty) throw StateError('초기 동기화 대상 앱이 없습니다.');

    final db = await DatabaseHelper.instance.database;
    final existingManualRows = await db.query(
      AppConstants.tableKnowledgeBase,
      columns: ['question', 'answer'],
      where: 'category = ? OR project = ?',
      whereArgs: const ['시스템매뉴얼', 'manual-upload'],
    );
    final manualKeys = <String>{
      for (final row in existingManualRows)
        _manualKey(row['question']?.toString() ?? '', row['answer']?.toString() ?? ''),
    };

    var vocRemoteTotal = 0;
    var vocCreated = 0;
    var vocUpdated = 0;
    var manualRemoteTotal = 0;
    var manualCreated = 0;
    var manualSkipped = 0;
    var successApps = 0;
    var failedApps = 0;

    for (final target in targets) {
      try {
        final payload = await _webhook.getJsonForMap(
          url: _toExportEndpoint(target),
          headers: _authHeaders(),
        );
        successApps += 1;
        final sourceApp = _sourceApp(payload);
        final snapshot = payload['snapshot'] is Map
            ? Map<String, dynamic>.from(payload['snapshot'] as Map)
            : const <String, dynamic>{};
        final vocs = (snapshot['vocs'] as List?) ?? const [];
        final manuals = (snapshot['manuals'] as List?) ?? const [];
        vocRemoteTotal += vocs.length;
        manualRemoteTotal += manuals.length;

        for (final item in vocs) {
          if (item is! Map) continue;
          final wasCreated = await _upsertRemoteVoc(
            sourceApp,
            Map<String, dynamic>.from(item),
            source: 'peer-bootstrap',
          );
          if (wasCreated) {
            vocCreated += 1;
          } else {
            vocUpdated += 1;
          }
        }

        for (final item in manuals) {
          if (item is! Map) continue;
          final row = Map<String, dynamic>.from(item);
          final question = row['question']?.toString().trim() ?? '';
          final answer = row['answer']?.toString().trim() ?? '';
          if (question.isEmpty || answer.isEmpty) {
            manualSkipped += 1;
            continue;
          }
          final key = _manualKey(question, answer);
          if (manualKeys.contains(key)) {
            manualSkipped += 1;
            continue;
          }
          final now = DateTime.now();
          await db.insert(
            AppConstants.tableKnowledgeBase,
            {
              'id': _uuid.v4(),
              'question': question,
              'answer': answer,
              'category': row['category']?.toString() ?? '시스템매뉴얼',
              'customer': row['customer']?.toString(),
              'project': row['project']?.toString() ?? 'manual-upload',
              'voc_id': row['voc_id']?.toString(),
              'embedding': row['embedding']?.toString() ??
                  jsonEncode(VectorUtils.simpleTextEmbedding('$question $answer')),
              'resolved_at': row['resolved_at']?.toString() ?? now.toIso8601String(),
              'created_at': row['created_at']?.toString() ?? now.toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          manualKeys.add(key);
          manualCreated += 1;
        }
      } catch (_) {
        failedApps += 1;
      }
    }

    return PeerBootstrapResult(
      vocRemoteTotal: vocRemoteTotal,
      vocCreated: vocCreated,
      vocUpdated: vocUpdated,
      manualRemoteTotal: manualRemoteTotal,
      manualCreated: manualCreated,
      manualSkipped: manualSkipped,
      failedApps: failedApps,
      successApps: successApps,
    );
  }

  Future<bool> _upsertRemoteVoc(
    String sourceApp,
    Map<String, dynamic> row, {
    required String source,
  }) async {
    final remoteId = row['id']?.toString().trim() ?? '';
    final title = row['title']?.toString().trim().isNotEmpty == true
        ? row['title'].toString().trim()
        : '제목없음';
    final content = row['content']?.toString().trim().isNotEmpty == true
        ? row['content'].toString().trim()
        : '내용 없음';
    final stableRef = '$sourceApp:${remoteId.isEmpty ? _fallbackRemoteKey(title, content) : remoteId}';
    final db = await DatabaseHelper.instance.database;
    final existingRows = await db.query(
      AppConstants.tableVocs,
      columns: ['id'],
      where: 'source_ref = ?',
      whereArgs: [stableRef],
      limit: 1,
    );

    final existing = existingRows.isEmpty
        ? null
        : await _vocRepository.getVocById(existingRows.first['id'].toString());
    final now = DateTime.now();
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? existing?.createdAt ?? now;
    final updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? now;
    final normalizedCategory = VocCategoryCatalog.normalize(
      row['category']?.toString(),
      title: title,
      content: content,
      aiCategory: row['ai_category']?.toString(),
      tags: row['tags']?.toString(),
    );

    if (existing != null) {
      final updated = existing.copyWith(
        title: title,
        content: content,
        category: normalizedCategory,
        tags: _optional(row['tags']) ?? existing.tags,
        customer: _required(row['customer'], existing.customer),
        project: _required(row['project'], existing.project),
        priority: _normalizePriority(row['priority']?.toString()),
        status: _normalizeStatus(row['status']?.toString()),
        aiCategory: _optional(row['ai_category']) ?? existing.aiCategory,
        isBusinessRelated: _boolValue(row['is_business_related']) ?? existing.isBusinessRelated,
        businessScore: _doubleValue(row['business_score']) ?? existing.businessScore,
        categoryScore: _doubleValue(row['category_score']) ?? existing.categoryScore,
        urgency: _optional(row['urgency']) ?? existing.urgency,
        urgencyScore: _doubleValue(row['urgency_score']) ?? existing.urgencyScore,
        businessType: _optional(row['business_type']) ?? existing.businessType,
        department: _optional(row['department']) ?? existing.department,
        departmentScore: _doubleValue(row['department_score']) ?? existing.departmentScore,
        assignee: _optional(row['assignee']) ?? existing.assignee,
        assigneeScore: _doubleValue(row['assignee_score']) ?? existing.assigneeScore,
        duplicateOfVocId: _optional(row['duplicate_of_voc_id']) ?? existing.duplicateOfVocId,
        duplicateScore: _doubleValue(row['duplicate_score']) ?? existing.duplicateScore,
        jiraRequired: _boolValue(row['jira_required']) ?? existing.jiraRequired,
        jiraScore: _doubleValue(row['jira_score']) ?? existing.jiraScore,
        analysisReason: _optional(row['analysis_reason']) ?? existing.analysisReason,
        source: source,
        sourceRef: stableRef,
        processingMinutes: _intValue(row['processing_minutes']) ?? existing.processingMinutes,
        updatedAt: updatedAt,
      );
      await _vocRepository.updateVoc(updated);
      return false;
    }

    await _vocRepository.createVoc(
      VocEntity(
        id: _uuid.v4(),
        title: title,
        content: content,
        category: normalizedCategory,
        tags: _optional(row['tags']),
        customer: _required(row['customer'], '미입력'),
        project: _required(row['project'], '미입력'),
        priority: _normalizePriority(row['priority']?.toString()),
        status: _normalizeStatus(row['status']?.toString()),
        aiCategory: _optional(row['ai_category']),
        isBusinessRelated: _boolValue(row['is_business_related']) ?? true,
        businessScore: _doubleValue(row['business_score']),
        categoryScore: _doubleValue(row['category_score']),
        urgency: _optional(row['urgency']),
        urgencyScore: _doubleValue(row['urgency_score']),
        businessType: _optional(row['business_type']),
        department: _optional(row['department']),
        departmentScore: _doubleValue(row['department_score']),
        assignee: _optional(row['assignee']),
        assigneeScore: _doubleValue(row['assignee_score']),
        duplicateOfVocId: _optional(row['duplicate_of_voc_id']),
        duplicateScore: _doubleValue(row['duplicate_score']),
        jiraRequired: _boolValue(row['jira_required']) ?? false,
        jiraScore: _doubleValue(row['jira_score']),
        analysisReason: _optional(row['analysis_reason']),
        source: source,
        sourceRef: stableRef,
        processingMinutes: _intValue(row['processing_minutes']),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
    );
    return true;
  }

  String _sourceApp(Map<String, dynamic> payload) {
    final value = payload['source_app']?.toString().trim() ?? '';
    return value.isEmpty ? 'unknown-app' : value;
  }

  Map<String, String> _authHeaders() {
    final token = settings.vocSyncBearerToken.trim();
    return token.isEmpty ? const {} : {'Authorization': 'Bearer $token'};
  }

  String _toExportEndpoint(String target) {
    var base = target.trim();
    if (base.endsWith('/webhook/voc')) {
      base = base.substring(0, base.length - '/webhook/voc'.length);
    } else if (base.endsWith('/voc')) {
      base = base.substring(0, base.length - '/voc'.length);
    } else if (base.endsWith('/webhook/sync/full')) {
      base = base.substring(0, base.length - '/webhook/sync/full'.length);
    }
    base = base.replaceAll(RegExp(r'/+$'), '');
    return '$base/webhook/sync/export';
  }

  String _normalizeStatus(String? raw) {
    final value = raw?.trim().toUpperCase() ?? '';
    return switch (value) {
      'IN_PROGRESS' => AppConstants.vocStatusInProgress,
      'RESOLVED' => AppConstants.vocStatusResolved,
      'REJECTED' => AppConstants.vocStatusRejected,
      _ => AppConstants.vocStatusOpen,
    };
  }

  String _normalizePriority(String? raw) {
    final value = raw?.trim().toUpperCase() ?? '';
    return switch (value) {
      'HIGH' => AppConstants.priorityHigh,
      'LOW' => AppConstants.priorityLow,
      _ => AppConstants.priorityMedium,
    };
  }

  String? _optional(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _required(dynamic value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double? _doubleValue(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
  int? _intValue(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '');
  bool? _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }

  String _fallbackRemoteKey(String title, String content) =>
      '${title.trim().toLowerCase()}|${content.trim().toLowerCase()}';

  String _manualKey(String question, String answer) =>
      '${question.trim().toLowerCase()}|${answer.trim().toLowerCase()}';
}
