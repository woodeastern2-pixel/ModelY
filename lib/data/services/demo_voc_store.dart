import 'package:sqflite/sqflite.dart';
import '../../domain/entities/voc_entity.dart';
import 'sample_voc_generator.dart';
import 'voc_identity_store.dart';

class DemoImportResult {
  const DemoImportResult(this.added, this.skipped);
  final int added;
  final int skipped;
}

/// A single transaction, no AI calls, external sync, or knowledge-base writes.
class DemoVocStore {
  DemoVocStore(this.db);
  final Database db;

  /// Upgrade only generator-owned rows. Keep IDs, dates, edits and answers.
  Future<int> removeVisibleMarkers() => db.transaction((txn) async {
    final rows = await txn.query('vocs', where: 'source = ?', whereArgs: ['demo']);
    await VocIdentityStore.ensureSchema(txn);
    var changed = 0;
    for (final row in rows) {
      final id = row['id'] as String;
      if (!id.startsWith('${SampleVocGenerator.batchId}-') &&
          !RegExp(r'^demo-voc-00[1-8]$').hasMatch(id)) continue;
      final updates = <String, Object?>{};
      void clean(String key, String value) {
        if (row[key] != null && value != row[key]) updates[key] = value;
      }
      clean('title', (row['title'] as String? ?? '')
          .replaceFirst(RegExp(r'^\[시연\]\s*'), ''));
      clean('content', (row['content'] as String? ?? '').replaceAll(
          '\n\n[시연용 가상 문의 — 실제 고객 접수가 아닙니다.]', ''));
      clean('customer', (row['customer'] as String? ?? '')
          .replaceFirst(RegExp(r'^시연\s+'), ''));
      clean('assignee', (row['assignee'] as String? ?? '')
          .replaceFirst(RegExp(r'^시연\s+(?=담당자)'), ''));
      clean('tags', (row['tags'] as String? ?? '').split(',')
          .where((tag) => tag.trim() != '시연').join(','));
      if (updates.isEmpty) continue;
      await txn.update('vocs', updates, where: 'id = ?', whereArgs: [id]);
      await VocIdentityStore.index(txn, {...row, ...updates});
      changed++;
    }
    return changed;
  });

  Future<DemoImportResult> insert(List<VocEntity> samples) async {
    if (samples.any((v) => !SampleVocGenerator.isSample(v)) ||
        samples.map((v) => v.id).toSet().length != samples.length) {
      throw ArgumentError('시연 데이터의 식별자가 올바르지 않습니다.');
    }
    return db.transaction((txn) async {
      await VocIdentityStore.ensureSchema(txn);
      var added = 0;
      for (final voc in samples) {
        final canonical = await VocIdentityStore.resolve(txn, voc.id);
        final existing = await txn.query('vocs',
            columns: ['id'], where: 'id = ?', whereArgs: [canonical], limit: 1);
        if (existing.isNotEmpty) continue;
        final row = <String, dynamic>{
          'id': voc.id, 'title': voc.title, 'content': voc.content,
          'category': voc.category, 'tags': voc.tags,
          'customer': voc.customer, 'project': voc.project,
          'priority': voc.priority, 'status': voc.status,
          'is_business_related': 1, 'jira_required': 0,
          'business_type': voc.businessType, 'department': voc.department,
          'assignee': voc.assignee, 'urgency': voc.urgency,
          'source': 'demo', 'source_ref': voc.sourceRef,
          'processing_minutes': voc.processingMinutes,
          'analysis_reason': voc.analysisReason,
          'created_at': voc.createdAt.toIso8601String(),
          'updated_at': voc.updatedAt.toIso8601String(),
        };
        await txn.insert('vocs', row);
        await VocIdentityStore.index(txn, row);
        added++;
      }
      return DemoImportResult(added, samples.length - added);
    });
  }

  /// Remove only this generator's rows and their owned activity records.
  /// User-authored knowledge remains; its link to a removed sample is cleared.
  Future<int> clear() => db.transaction((txn) async {
    final rows = await txn.query('vocs', columns: ['id'],
        where: 'source = ?', whereArgs: ['demo']);
    final ids = rows.map((r) => r['id'] as String).where((id) =>
        id.startsWith('${SampleVocGenerator.batchId}-') ||
        RegExp(r'^demo-voc-00[1-8]$').hasMatch(id)).toList();
    final tables = (await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"))
        .map((r) => r['name'] as String).toSet();
    for (final id in ids) {
      for (final table in const [
        'responses', 'jira_links', 'agent_logs', 'ai_accuracy_metrics',
        'ai_feedback', 'voc_identity_index', 'voc_identity_aliases',
      ]) {
        if (tables.contains(table)) {
          await txn.delete(table, where: 'voc_id = ?', whereArgs: [id]);
        }
      }
      if (tables.contains('knowledge_base')) {
        await txn.update('knowledge_base', {'voc_id': null},
            where: 'voc_id = ?', whereArgs: [id]);
      }
      if (tables.contains('voc_merge_archive')) {
        await txn.delete('voc_merge_archive',
            where: 'canonical_id = ? OR original_id = ?', whereArgs: [id, id]);
      }
      await txn.update('vocs', {'duplicate_of_voc_id': null},
          where: 'duplicate_of_voc_id = ?', whereArgs: [id]);
      await txn.delete('vocs', where: 'id = ? AND source = ?',
          whereArgs: [id, 'demo']);
    }
    return ids.length;
  });
}
