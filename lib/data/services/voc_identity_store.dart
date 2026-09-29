import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

class VocSaveResult {
  const VocSaveResult(this.row, {this.created = false, this.updated = false});
  final Map<String, dynamic> row;
  final bool created;
  final bool updated;
  String get id => row['id'] as String;
}

/// All identity decisions and writes run inside the caller's transaction.
class VocIdentityStore {
  static String normalize(Object? value) =>
      (value?.toString() ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

  static String fingerprint(Map<String, dynamic> row) => sha256
      .convert(utf8.encode(jsonEncode([
        normalize(row['title']),
        normalize(row['content']),
        normalize(row['customer']).isEmpty ? '미입력' : normalize(row['customer']),
        normalize(row['project']).isEmpty ? '미입력' : normalize(row['project']),
      ])))
      .toString();

  static bool _peer(Map<String, dynamic> row) =>
      normalize(row['source']).startsWith('peer-');

  static DateTime? _time(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toUtc();

  static Set<String> keys(Map<String, dynamic> row) {
    final result = <String>{'id:${row['id']}'};
    final ref = normalize(row['source_ref']);
    // Excel source_ref can be a filename shared by hundreds of distinct rows.
    if (_peer(row) && ref.isNotEmpty) {
      result.add('peer:$ref');
    }
    return result;
  }

  static Map<String, dynamic> remoteRow(Map<String, dynamic> input,
      String app, {String source = 'peer-sync'}) {
    final now = DateTime.now().toIso8601String();
    final row = <String, dynamic>{};
    for (final name in const [
      'id', 'title', 'content', 'category', 'tags', 'customer', 'project',
      'priority', 'status', 'ai_category', 'urgency', 'business_type',
      'department', 'assignee', 'duplicate_of_voc_id', 'analysis_reason',
      'source_ref', 'created_at', 'updated_at',
    ]) {
      if (input[name] != null) row[name] = input[name].toString();
    }
    for (final name in const ['business_score', 'category_score',
      'urgency_score', 'department_score', 'assignee_score',
      'duplicate_score', 'jira_score']) {
      if (input[name] != null) row[name] = num.tryParse('${input[name]}');
    }
    for (final name in const ['is_business_related', 'jira_required']) {
      if (input[name] != null) {
        row[name] = input[name] == true || input[name].toString() == '1' ? 1 : 0;
      }
    }
    if (input['processing_minutes'] != null) {
      row['processing_minutes'] = int.tryParse('${input['processing_minutes']}');
    }
    if (input['embedding'] != null) {
      row['embedding'] = input['embedding'] is List
          ? jsonEncode(input['embedding']) : input['embedding'].toString();
    }
    for (final pair in const {
      'title': '제목없음', 'content': '내용 없음', 'customer': '미입력',
      'project': '미입력', 'category': '기타', 'priority': 'MEDIUM', 'status': 'OPEN',
    }.entries) {
      if (normalize(row[pair.key]).isEmpty) row[pair.key] = pair.value;
    }
    if (normalize(row['id']).isEmpty) {
      row['id'] = 'peer-${sha256.convert(utf8.encode('$app:${fingerprint(row)}'))}';
    }
    if (!normalize(input['source']).startsWith('peer-') ||
        normalize(row['source_ref']).isEmpty) {
      row['source_ref'] = '$app:${row['id']}';
    }
    row['source'] = source;
    row['created_at'] = _time(row['created_at'])?.toIso8601String() ?? now;
    row['updated_at'] = _time(row['updated_at'])?.toIso8601String() ?? row['created_at'];
    return row;
  }

  static Future<void> ensureSchema(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS voc_identity_aliases '
        '(identity_key TEXT PRIMARY KEY, voc_id TEXT NOT NULL)');
    await db.execute('CREATE INDEX IF NOT EXISTS voc_alias_target '
        'ON voc_identity_aliases(voc_id)');
    await db.execute('CREATE TABLE IF NOT EXISTS voc_identity_index '
        '(voc_id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL)');
    await db.execute('CREATE INDEX IF NOT EXISTS voc_fingerprint '
        'ON voc_identity_index(fingerprint)');
    await db.execute('CREATE TABLE IF NOT EXISTS voc_merge_archive '
        '(original_id TEXT PRIMARY KEY, canonical_id TEXT NOT NULL, '
        'original_json TEXT NOT NULL, merged_at TEXT NOT NULL)');

    // An in-flight task may still hold an old id after background repair.
    // Redirect late child writes at the database boundary as well.
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    for (final table in tables) {
      final name = table['name'] as String;
      if (name.startsWith('voc_identity_') ||
          !RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name)) continue;
      final columns = (await db.rawQuery('PRAGMA table_info("$name")'))
          .map((c) => c['name']).toSet();
      for (final column in ['voc_id', 'imported_voc_id', 'duplicate_of_voc_id']) {
        if (!columns.contains(column)) continue;
        for (final event in ['INSERT', 'UPDATE OF $column']) {
          final suffix = event == 'INSERT' ? 'insert' : 'update';
          await db.execute('''
            CREATE TRIGGER IF NOT EXISTS "voc_redirect_${name}_${column}_$suffix"
            AFTER $event ON "$name"
            WHEN EXISTS (
              SELECT 1 FROM voc_identity_aliases a
              JOIN vocs v ON v.id = a.voc_id
              WHERE a.identity_key = 'id:' || NEW."$column"
                AND a.voc_id != NEW."$column"
            )
            BEGIN
              UPDATE "$name" SET "$column" = (
                SELECT voc_id FROM voc_identity_aliases
                WHERE identity_key = 'id:' || NEW."$column"
              ) WHERE rowid = NEW.rowid;
            END
          ''');
        }
      }
    }
  }

  static Future<String> resolve(DatabaseExecutor db, String id) async {
    final rows = await db.rawQuery(
      'SELECT a.voc_id FROM voc_identity_aliases a '
      'JOIN ${AppConstants.tableVocs} v ON v.id = a.voc_id '
      'WHERE a.identity_key = ?', ['id:$id']);
    return rows.isEmpty ? id : rows.first['voc_id'] as String;
  }

  static Future<void> index(DatabaseExecutor db, Map<String, dynamic> row,
      {Iterable<String> aliases = const []}) async {
    final id = row['id'] as String;
    await db.insert('voc_identity_index',
        {'voc_id': id, 'fingerprint': fingerprint(row)},
        conflictAlgorithm: ConflictAlgorithm.replace);
    for (final key in {...keys(row), ...aliases}) {
      await db.insert('voc_identity_aliases',
          {'identity_key': key, 'voc_id': id},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static bool _sameOccurrence(Map<String, dynamic> a, Map<String, dynamic> b) {
    final at = _time(a['created_at']);
    final bt = _time(b['created_at']);
    if (at == null || bt == null) return false;
    if (at == bt) return true;
    // A manual double submission is a short retry, not a recurring incident.
    final manualA = normalize(a['source']).isEmpty;
    final manualB = normalize(b['source']).isEmpty;
    return manualA && manualB &&
        at.difference(bt).inMilliseconds.abs() <= 2000;
  }

  static Future<VocSaveResult> save(DatabaseExecutor db,
      Map<String, dynamic> incoming, {String? peerApp}) async {
    final row = Map<String, dynamic>.from(incoming);
    final id = normalize(row['id']);
    if (id.isEmpty) throw ArgumentError('VOC id is required');
    row['id'] = id;
    final aliases = keys(row);
    if (peerApp != null) aliases.add('peer:$peerApp:$id');
    Map<String, dynamic>? existing;
    for (final key in aliases) {
      final rows = await db.rawQuery(
          'SELECT v.* FROM ${AppConstants.tableVocs} v '
          'JOIN voc_identity_aliases a ON a.voc_id = v.id '
          'WHERE a.identity_key = ?', [key]);
      if (rows.isNotEmpty) { existing = rows.first; break; }
    }
    if (existing == null) {
      final rows = await db.query(AppConstants.tableVocs,
          where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isNotEmpty) existing = rows.first;
    }
    // Old clients generated a new id and embedded the previous id in source_ref.
    if (existing == null && _peer(row)) {
      final ref = normalize(row['source_ref']);
      final split = ref.lastIndexOf(':');
      if (split >= 0) {
        final origin = await resolve(db, ref.substring(split + 1));
        final rows = await db.query(AppConstants.tableVocs,
            where: 'id = ?', whereArgs: [origin], limit: 1);
        if (rows.isNotEmpty && fingerprint(rows.first) == fingerprint(row)) {
          existing = rows.first;
        }
      }
    }
    if (existing == null) {
      final rows = await db.rawQuery(
          'SELECT v.* FROM ${AppConstants.tableVocs} v '
          'JOIN voc_identity_index i ON i.voc_id = v.id '
          'WHERE i.fingerprint = ?', [fingerprint(row)]);
      for (final candidate in rows) {
        if (_sameOccurrence(candidate, row)) { existing = candidate; break; }
      }
    }
    if (existing == null) {
      await db.insert(AppConstants.tableVocs, row);
      await index(db, row, aliases: aliases);
      return VocSaveResult(row, created: true);
    }

    final merged = Map<String, dynamic>.from(existing);
    final oldTime = _time(existing['updated_at']);
    final newTime = _time(row['updated_at']);
    // Import must not overwrite a newer local resolution with a stale snapshot.
    if (peerApp != null && newTime != null &&
        (oldTime == null || newTime.isAfter(oldTime))) {
      for (final entry in row.entries) {
        if (const {'id', 'created_at', 'source', 'source_ref'}.contains(entry.key)) {
          continue;
        }
        if (entry.value != null) merged[entry.key] = entry.value;
      }
    }
    final changed = merged.entries.any((e) => existing![e.key] != e.value);
    if (changed) {
      await db.update(AppConstants.tableVocs, merged,
          where: 'id = ?', whereArgs: [existing['id']]);
    }
    await index(db, merged, aliases: aliases);
    return VocSaveResult(merged, updated: changed);
  }

  /// Repairs legacy duplicates; the original parent rows are archived and every
  /// child row is retained. Re-running this transaction is idempotent.
  static Future<int> reconcile(Database db) => db.transaction((txn) async {
    await ensureSchema(txn);
    final rows = await txn.query(AppConstants.tableVocs,
        orderBy: 'created_at ASC, id ASC');
    final byId = <String, Map<String, dynamic>>{
      for (final row in rows) row['id'] as String: row,
    };
    final indexed = {for (final row in await txn.query('voc_identity_index'))
      row['voc_id'] as String: row['fingerprint']};
    final storedAliases = <String, String>{};
    final aliasOwners = <String, String>{};
    for (final a in await txn.query('voc_identity_aliases')) {
      final owner = a['voc_id'] as String;
      if (byId.containsKey(owner)) {
        aliasOwners[a['identity_key'] as String] = owner;
        storedAliases[a['identity_key'] as String] = owner;
      }
    }
    final bodies = <String, List<String>>{};
    final redirects = <String, String>{};
    String root(String id) {
      while (redirects.containsKey(id)) { id = redirects[id]!; }
      return id;
    }
    var count = 0;
    for (final row in rows) {
      final id = row['id'] as String;
      if (redirects.containsKey(id)) continue;
      String? canonical;
      for (final key in keys(row)) {
        final owner = aliasOwners[key];
        if (owner != null && root(owner) != id) { canonical = root(owner); break; }
      }
      if (canonical == null && _peer(row)) {
        final ref = normalize(row['source_ref']);
        final split = ref.lastIndexOf(':');
        final candidate = split < 0 ? '' : root(ref.substring(split + 1));
        if (candidate != id && byId.containsKey(candidate) &&
            fingerprint(byId[candidate]!) == fingerprint(row)) {
          canonical = candidate;
        }
      }
      final fp = fingerprint(row);
      if (canonical == null) {
        for (final candidate in bodies[fp] ?? <String>[]) {
          final owner = root(candidate);
          if (owner != id && _sameOccurrence(byId[owner]!, row)) {
            canonical = owner; break;
          }
        }
      }
      if (canonical != null) {
        await _merge(txn, byId[canonical]!, row);
        redirects[id] = canonical;
        byId[canonical] = (await txn.query(AppConstants.tableVocs,
            where: 'id = ?', whereArgs: [canonical])).single;
        count++;
      } else {
        bodies.putIfAbsent(fp, () => []).add(id);
      }
      for (final key in keys(row)) { aliasOwners[key] = canonical ?? id; }
    }
    for (final row in await txn.query(AppConstants.tableVocs)) {
      if (indexed[row['id']] != fingerprint(row) ||
          keys(row).any((key) => storedAliases[key] != row['id'])) {
        await index(txn, row);
      }
    }
    return count;
  });

  static Future<void> _merge(DatabaseExecutor db,
      Map<String, dynamic> keeper, Map<String, dynamic> duplicate) async {
    final target = keeper['id'] as String;
    final oldId = duplicate['id'] as String;
    await db.insert('voc_merge_archive', {
      'original_id': target, 'canonical_id': target,
      'original_json': jsonEncode(keeper),
      'merged_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('voc_merge_archive', {
      'original_id': oldId, 'canonical_id': target,
      'original_json': jsonEncode(duplicate),
      'merged_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final merged = Map<String, dynamic>.from(keeper);
    final duplicateNewer = (_time(duplicate['updated_at']) ?? DateTime(0))
        .isAfter(_time(keeper['updated_at']) ?? DateTime(0));
    for (final entry in duplicate.entries) {
      if (const {'id', 'created_at', 'source', 'source_ref'}.contains(entry.key)) continue;
      if (entry.value != null && (duplicateNewer ||
          merged[entry.key] == null || merged[entry.key] == '')) {
        merged[entry.key] = entry.value;
      }
    }
    // Preserve terminal handling state when legacy timestamps are identical.
    if (_time(duplicate['updated_at']) == _time(keeper['updated_at']) &&
        duplicate['status'] == 'RESOLVED') merged['status'] = 'RESOLVED';
    await db.update(AppConstants.tableVocs, merged,
        where: 'id = ?', whereArgs: [target]);
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    for (final table in tables) {
      final name = table['name'] as String;
      if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name)) continue;
      final columns = (await db.rawQuery('PRAGMA table_info("$name")'))
          .map((c) => c['name']).toSet();
      for (final column in ['voc_id', 'imported_voc_id', 'duplicate_of_voc_id']) {
        if (!columns.contains(column)) continue;
        if (name == 'voc_identity_index') continue;
        await db.update(name, {column: target},
            where: '$column = ?', whereArgs: [oldId]);
      }
      if (columns.contains('referenced_voc_ids') && columns.contains('id')) {
        for (final item in await db.query(name,
            columns: ['id', 'referenced_voc_ids'],
            where: 'referenced_voc_ids IS NOT NULL')) {
          try {
            final refs = jsonDecode(item['referenced_voc_ids'] as String);
            if (refs is List && refs.contains(oldId)) {
              await db.update(name, {'referenced_voc_ids': jsonEncode(
                refs.map((v) => v == oldId ? target : v).toSet().toList())},
                where: 'id = ?', whereArgs: [item['id']]);
            }
          } on FormatException { /* Preserve unrecognized historical data. */ }
        }
      }
    }
    await db.update(AppConstants.tableVocs, {'duplicate_of_voc_id': null},
        where: 'id = ? AND duplicate_of_voc_id = ?', whereArgs: [target, target]);
    await db.update('voc_merge_archive', {'canonical_id': target},
        where: 'canonical_id = ?', whereArgs: [oldId]);
    await db.delete('voc_identity_index', where: 'voc_id = ?', whereArgs: [oldId]);
    await index(db, merged, aliases: keys(duplicate));
    await db.delete(AppConstants.tableVocs, where: 'id = ?', whereArgs: [oldId]);
  }
}
