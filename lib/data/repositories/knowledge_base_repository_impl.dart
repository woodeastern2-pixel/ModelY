import 'dart:typed_data';
import '../../core/database/database_helper.dart';
import '../../domain/repositories/indexed_knowledge_repository.dart';
import '../services/offline_search_store.dart';
import '../datasources/local/knowledge_base_local_datasource.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';

class KnowledgeBaseRepositoryImpl implements KnowledgeBaseRepository, IndexedKnowledgeRepository {
  final KnowledgeBaseLocalDatasource _localDatasource;

  KnowledgeBaseRepositoryImpl(this._localDatasource);

  @override
  Future<List<SimilarVocResult>> searchOffline(String query, {String? excludeVocId}) async =>
      OfflineSearchStore.forDatabase(await DatabaseHelper.instance.database)
          .search(query, excludeVocId: excludeVocId);

  @override
  Future<void> preserveOriginal({required String fileName, required String fingerprint,
      required Uint8List bytes, required String extractedText,
      required Map<String, Uint8List> images}) async =>
      OfflineSearchStore.forDatabase(await DatabaseHelper.instance.database).preserveOriginal(
          fileName:fileName, fingerprint:fingerprint, bytes:bytes,
          extractedText:extractedText, images:images);

  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() =>
      _localDatasource.getAllEntries();

  @override
  Future<KnowledgeBaseEntity?> getEntryById(String id) =>
      _localDatasource.getEntryById(id);

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesByCategory(String category) =>
      _localDatasource.getEntriesByCategory(category);

  @override
  Future<KnowledgeBaseEntity> createEntry(KnowledgeBaseEntity entry) =>
      _localDatasource.insertEntry(entry);

  @override
  Future<KnowledgeBaseEntity> updateEntry(KnowledgeBaseEntity entry) =>
      _localDatasource.updateEntry(entry);

  @override
  Future<void> deleteEntry(String id) => _localDatasource.deleteEntry(id);

  @override
  Future<void> updateEmbedding(String id, List<double> embedding) =>
      _localDatasource.updateEmbedding(id, embedding);

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesWithEmbeddings() =>
      _localDatasource.getEntriesWithEmbeddings();

  @override
  Future<int> getTotalCount() => _localDatasource.getTotalCount();
}

