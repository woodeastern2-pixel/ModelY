import 'dart:convert';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../domain/entities/knowledge_base_entity.dart';

class KnowledgeBaseLocalDatasource {
  final DatabaseHelper _dbHelper;

  KnowledgeBaseLocalDatasource(this._dbHelper);

  Future<List<KnowledgeBaseEntity>> getAllEntries() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableKnowledgeBase,
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToEntity).toList();
  }

  Future<KnowledgeBaseEntity?> getEntryById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableKnowledgeBase,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _mapToEntity(maps.first);
  }

  Future<List<KnowledgeBaseEntity>> getEntriesByCategory(String category) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableKnowledgeBase,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );
    return maps.map(_mapToEntity).toList();
  }

  Future<KnowledgeBaseEntity> insertEntry(KnowledgeBaseEntity entry) async {
    final db = await _dbHelper.database;
    await db.insert(AppConstants.tableKnowledgeBase, _entityToMap(entry));
    return entry;
  }

  Future<KnowledgeBaseEntity> updateEntry(KnowledgeBaseEntity entry) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tableKnowledgeBase,
      _entityToMap(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    return entry;
  }

  Future<void> deleteEntry(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      AppConstants.tableKnowledgeBase,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateEmbedding(String id, List<double> embedding) async {
    final db = await _dbHelper.database;
    await db.update(
      AppConstants.tableKnowledgeBase,
      {'embedding': jsonEncode(embedding)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<KnowledgeBaseEntity>> getEntriesWithEmbeddings() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tableKnowledgeBase,
      where: 'embedding IS NOT NULL',
    );
    return maps.map(_mapToEntity).toList();
  }

  Future<int> getTotalCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tableKnowledgeBase}',
    );
    return result.first['count'] as int;
  }

  KnowledgeBaseEntity _mapToEntity(Map<String, dynamic> map) {
    List<double>? embedding;
    final embeddingJson = map['embedding'];
    if (embeddingJson != null && (embeddingJson as String).isNotEmpty) {
      embedding = List<double>.from(jsonDecode(embeddingJson));
    }
    return KnowledgeBaseEntity(
      id: map['id'] as String,
      question: map['question'] as String,
      answer: map['answer'] as String,
      category: map['category'] as String,
      customer: map['customer'] as String?,
      project: map['project'] as String?,
      vocId: map['voc_id'] as String?,
      embedding: embedding,
      resolvedAt: DateTime.parse(map['resolved_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> _entityToMap(KnowledgeBaseEntity e) {
    return {
      'id': e.id,
      'question': e.question,
      'answer': e.answer,
      'category': e.category,
      'customer': e.customer,
      'project': e.project,
      'voc_id': e.vocId,
      'embedding': e.embedding != null ? jsonEncode(e.embedding) : null,
      'resolved_at': e.resolvedAt.toIso8601String(),
      'created_at': e.createdAt.toIso8601String(),
    };
  }
}
