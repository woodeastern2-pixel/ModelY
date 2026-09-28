import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/manual_document_import_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';

void main() {
  test('raw paragraphs, numbered steps and table cells survive offline import and AI failure', () async {
    final dir = await Directory.systemTemp.createTemp('manual-source-');
    addTearDown(() => dir.delete(recursive: true));
    const xml = '<w:document xmlns:w="urn:test"><w:body>'
        '<w:p><w:r><w:t>1. 복원 절차</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>1. 휴지통을 엽니다.</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>2. 파일을 선택하고 복원합니다.</w:t></w:r></w:p>'
        '<w:tbl><w:tr><w:tc><w:p><w:r><w:t>보관 기간</w:t></w:r></w:p></w:tc>'
        '<w:tc><w:p><w:r><w:t>30일</w:t></w:r></w:p></w:tc></w:tr></w:tbl>'
        '<w:p><w:r><w:t>주의: 영구 삭제는 복원 불가</w:t></w:r></w:p>'
        '</w:body></w:document>';
    final archive = Archive()..addFile(ArchiveFile('word/document.xml', utf8.encode(xml).length, utf8.encode(xml)));
    final file = File('${dir.path}/manual.docx');
    await file.writeAsBytes(ZipEncoder().encode(archive)!);
    final repo = _MemoryRepository();
    final service = ManualDocumentImportService(repo);
    final first = await service.importDocuments([file.path]);
    expect(first.processedFiles, 1);
    expect(repo.entries.length, 1);
    final body = repo.entries.values.single.answer;
    for (final text in ['1. 복원 절차', '1. 휴지통을 엽니다.', '2. 파일을 선택하고 복원합니다.', '보관 기간 | 30일', '영구 삭제는 복원 불가']) {
      expect(body, contains(text));
    }
    final second = await service.importDocuments([file.path],
        qaGenerator: (a, b, c, d) async => throw StateError('AI offline'),
        answerRefiner: (a, b) async => throw StateError('AI offline'));
    expect(second.processedFiles, 1);
    expect(second.importedEntries, 0);
    expect(repo.entries.length, 1);
    expect(repo.entries.values.single.answer, body);
    expect(second.warnings.join(), contains('원문 보존'));
    final otherDir = Directory('${dir.path}/other')..createSync();
    final copy = await file.copy('${otherDir.path}/manual.docx');
    await service.importDocuments([copy.path]);
    expect(repo.entries.length, 1, reason: 'same content at a different path is not duplicated');
  });
}

class _MemoryRepository implements KnowledgeBaseRepository {
  final entries = <String, KnowledgeBaseEntity>{};
  @override
  Future<KnowledgeBaseEntity> createEntry(KnowledgeBaseEntity entry) async =>
      entries[entry.id] = entry;

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<List<KnowledgeBaseEntity>> getAllEntries() async => entries.values.toList();

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesByCategory(String category) async =>
      const [];

  @override
  Future<KnowledgeBaseEntity?> getEntryById(String id) async => entries[id];

  @override
  Future<List<KnowledgeBaseEntity>> getEntriesWithEmbeddings() async => entries.values.toList();

  @override
  Future<int> getTotalCount() async => entries.length;

  @override
  Future<KnowledgeBaseEntity> updateEntry(KnowledgeBaseEntity entry) async =>
      entries[entry.id] = entry;

  @override
  Future<void> updateEmbedding(String id, List<double> embedding) async {}
}

