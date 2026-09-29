import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/vector_utils.dart';
import '../../presentation/viewmodels/settings_viewmodel.dart';
import 'webhook_service.dart';
import 'voc_identity_store.dart';

class PeerVocPullResult {
  const PeerVocPullResult({
    required this.remoteTotal,
    required this.created,
    required this.updated,
    this.skipped = 0,
    this.merged = 0,
    required this.failedApps,
    required this.successApps,
  });

  final int remoteTotal;
  final int created;
  final int updated;
  final int skipped;
  final int merged;
  final int failedApps;
  final int successApps;
  int get applied => created + updated;
}

class PeerBootstrapResult {
  const PeerBootstrapResult({
    required this.vocRemoteTotal,
    required this.vocCreated,
    required this.vocUpdated,
    this.vocSkipped = 0,
    this.merged = 0,
    required this.manualRemoteTotal,
    required this.manualCreated,
    required this.manualSkipped,
    required this.failedApps,
    required this.successApps,
  });

  final int vocRemoteTotal;
  final int vocCreated;
  final int vocUpdated;
  final int vocSkipped;
  final int merged;
  final int manualRemoteTotal;
  final int manualCreated;
  final int manualSkipped;
  final int failedApps;
  final int successApps;
}

class PeerSyncService {
  PeerSyncService(this.settings);

  final SettingsViewModel settings;
  final WebhookService _webhook = WebhookService();
  final Uuid _uuid = const Uuid();

  Future<PeerVocPullResult> pullAllVocs() async {
    final targets = settings.vocForwardWebhookTargets;
    if (targets.isEmpty) throw StateError('가져올 대상 앱 URL이 없습니다.');

    final db = await DatabaseHelper.instance.database;
    final merged = await VocIdentityStore.reconcile(db);
    var skipped = 0;
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
          final result = await _upsertRemoteVoc(
            sourceApp,
            Map<String, dynamic>.from(item),
            source: 'peer-pull',
          );
          if (result.created) {
            created++;
          } else if (result.updated) {
            updated++;
          } else {
            skipped++;
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
      skipped: skipped,
      merged: merged,
      failedApps: failedApps,
      successApps: successApps,
    );
  }

  Future<PeerBootstrapResult> bootstrap() async {
    final targets = settings.vocForwardWebhookTargets;
    if (targets.isEmpty) throw StateError('초기 동기화 대상 앱이 없습니다.');

    final db = await DatabaseHelper.instance.database;
    final merged = await VocIdentityStore.reconcile(db);
    var vocSkipped = 0;
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
          final result = await _upsertRemoteVoc(
            sourceApp,
            Map<String, dynamic>.from(item),
            source: 'peer-bootstrap',
          );
          if (result.created) {
            vocCreated++;
          } else if (result.updated) {
            vocUpdated++;
          } else {
            vocSkipped++;
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
              'voc_id': row['voc_id'] == null ? null
                  : await VocIdentityStore.resolve(db, row['voc_id'].toString()),
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
      vocSkipped: vocSkipped,
      merged: merged,
      manualRemoteTotal: manualRemoteTotal,
      manualCreated: manualCreated,
      manualSkipped: manualSkipped,
      failedApps: failedApps,
      successApps: successApps,
    );
  }

  Future<VocSaveResult> _upsertRemoteVoc(
    String sourceApp,
    Map<String, dynamic> row, {
    required String source,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) => VocIdentityStore.save(txn,
      VocIdentityStore.remoteRow(row, sourceApp, source: source),
      peerApp: sourceApp));
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
    final trimmed = target.trim();
    if (trimmed.endsWith('/health')) {
      return '${trimmed.substring(0, trimmed.length - '/health'.length)}/webhook/sync/export';
    }
    if (trimmed.endsWith('/webhook/sync/export') ||
        trimmed.endsWith('/webhook/voc/export')) {
      return trimmed;
    }
    if (trimmed.endsWith('/webhook/voc')) {
      return '${trimmed.substring(0, trimmed.length - '/webhook/voc'.length)}/webhook/sync/export';
    }
    if (trimmed.endsWith('/webhook/sync/full')) {
      return '${trimmed.substring(0, trimmed.length - '/webhook/sync/full'.length)}/webhook/sync/export';
    }
    if (trimmed.endsWith('/webhook/sync')) {
      return '$trimmed/export';
    }
    if (trimmed.endsWith('/')) {
      return '${trimmed}webhook/sync/export';
    }
    return '$trimmed/webhook/sync/export';
  }

  String _manualKey(String question, String answer) =>
      '${question.trim().toLowerCase()}|${answer.trim().toLowerCase()}';
}
