import 'package:ai_voc_assistant/core/utils/search_query_expander.dart';
import 'package:ai_voc_assistant/core/utils/vector_utils.dart';
import 'package:ai_voc_assistant/data/seeds/brity_suite_manual_seed.dart';
import 'package:ai_voc_assistant/data/services/vector_search_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Korean product names retrieve English-named Brity manuals', () async {
    final entries = BritySuiteManualSeed.entries.map((seed) {
      final question = seed['question']!;
      final answer = seed['answer']!;
      final searchable = [
        question,
        answer,
        seed['project']!,
        seed['sourceName']!,
      ].join(' ');
      return KnowledgeBaseEntity(
        id: seed['id']!,
        question: question,
        answer: answer,
        category: '시스템매뉴얼',
        customer: seed['sourceName'],
        project: seed['project'],
        embedding: VectorUtils.simpleTextEmbedding(
          SearchQueryExpander.expand(searchable),
        ),
        resolvedAt: DateTime(2026),
        createdAt: DateTime(2026),
      );
    }).toList();
    final service = VectorSearchService(_MemoryKnowledgeRepository(entries));

    final cases = {
      '미팅 화면 공유': 'Brity Meeting',
      '메신저 로그인': 'Brity Messenger',
      '드라이브 파일 공유': 'Brity Drive',
      '코파일럿 메일 요약': 'Brity Copilot',
    };

    for (final item in cases.entries) {
      final results = await service.searchSimilar(item.key, topK: 10);
      expect(results, isNotEmpty, reason: item.key);
      expect(
        results.any((result) => result.knowledgeBase.project == item.value),
        isTrue,
        reason: '${item.key} should find ${item.value}',
      );
    }
  });
}

class _MemoryKnowledgeRepository implements KnowledgeBaseRepository {
  _MemoryKnowledgeRepository(this.entries);

  final List<KnowledgeBaseEntity> entries;

  @override
  Future<KnowledgeBaseEntity> createEntry(KnowledgeBaseEntity entry) async {
    entries.add(entry);
    return entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => entries;

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesByCategory(String category) async =>
      entries.where((entry) => entry.category == category).toList();

  @override
  Future<KnowledgeBaseEntity?> getEntryById(String id) async {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesWithEmbeddings() async =>
      entries.where((entry) => entry.embedding != null).toList();

  @override
  Future<int> getTotalCount() async => entries.length;

  @override
  Future<KnowledgeBaseEntity> updateEntry(KnowledgeBaseEntity entry) async {
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index >= 0) entries[index] = entry;
    return entry;
  }

  @override
  Future<void> updateEmbedding(String id, List<double> embedding) async {}
}
