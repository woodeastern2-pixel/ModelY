import 'dart:io';

import 'package:ai_voc_assistant/data/services/manual_document_import_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('NASCA DRM manuals are rejected with an actionable warning', () async {
    final directory = await Directory.systemTemp.createTemp('ai-voc-drm-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/Brity Messenger 사용자 매뉴얼.pdf');
    await file.writeAsBytes(
      '<## NASCA DRM FILE - VER1.00 ##>encrypted'.codeUnits,
    );

    final service = ManualDocumentImportService(_EmptyKnowledgeRepository());
    final result = await service.importDocuments([file.path]);

    expect(result.processedFiles, 0);
    expect(result.importedEntries, 0);
    expect(result.warnings.single, contains('NASCA DRM'));
    expect(result.warnings.single, contains('DRM이 해제된 PDF'));
  });
}

class _EmptyKnowledgeRepository implements KnowledgeBaseRepository {
  @override
  Future<KnowledgeBaseEntity> createEntry(KnowledgeBaseEntity entry) async =>
      entry;

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => const [];

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesByCategory(String category) async =>
      const [];

  @override
  Future<KnowledgeBaseEntity?> getEntryById(String id) async => null;

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesWithEmbeddings() async => const [];

  @override
  Future<int> getTotalCount() async => 0;

  @override
  Future<KnowledgeBaseEntity> updateEntry(KnowledgeBaseEntity entry) async =>
      entry;

  @override
  Future<void> updateEmbedding(String id, List<double> embedding) async {}
}
