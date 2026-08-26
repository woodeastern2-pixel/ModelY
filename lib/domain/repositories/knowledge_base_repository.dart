import '../entities/knowledge_base_entity.dart';

abstract class KnowledgeBaseRepository {
  Future<List<KnowledgeBaseEntity>> getAllEntries();
  Future<KnowledgeBaseEntity?> getEntryById(String id);
  Future<List<KnowledgeBaseEntity>> getEntriesByCategory(String category);
  Future<KnowledgeBaseEntity> createEntry(KnowledgeBaseEntity entry);
  Future<KnowledgeBaseEntity> updateEntry(KnowledgeBaseEntity entry);
  Future<void> deleteEntry(String id);
  Future<void> updateEmbedding(String id, List<double> embedding);
  Future<List<KnowledgeBaseEntity>> getEntriesWithEmbeddings();
  Future<int> getTotalCount();
}
