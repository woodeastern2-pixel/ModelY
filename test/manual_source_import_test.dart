import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:ai_voc_assistant/data/services/manual_media_store.dart';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/manual_document_import_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/knowledge_base_repository.dart';

void main() {
  test('xlsx imports every sheet as offline source without invented QA', () async {
    final dir = await Directory.systemTemp.createTemp('xlsx-source-');
    addTearDown(() => dir.delete(recursive: true));
    final excel = Excel.createExcel();
    excel[excel.tables.keys.first].appendRow([
      TextCellValue('메일 등록 방법'), TextCellValue('설정에서 계정을 추가합니다.'),
    ]);
    excel['Drive'].appendRow([
      TextCellValue('휴지통 보관 기간'), IntCellValue(30),
    ]);
    final file = File('${dir.path}/manual.xlsx');
    await file.writeAsBytes(excel.encode()!);
    final repo = _MemoryRepository();
    final service = ManualDocumentImportService(repo,
      mediaStore: ManualMediaStore(directory: Directory('${dir.path}/media')));
    final result = await service.importDocuments([file.path]);
    expect(result.processedFiles, 1);
    expect(result.warnings, isEmpty);
    final body = repo.entries.values.map((e) => e.answer).join('\n');
    expect(body, contains('메일 등록 방법 | 설정에서 계정을 추가합니다.'));
    expect(body, contains('[시트] Drive'));
    expect(body, contains('휴지통 보관 기간 | 30'));
    expect(repo.entries.values.every((e) => e.question.contains('원문 섹션')), isTrue);
    final count = repo.entries.length;
    await service.importDocuments([file.path]);
    expect(repo.entries.length, count);
    final old = await file.copy('${dir.path}/legacy.xls');
    final unsupported = await service.importDocuments([old.path]);
    expect(unsupported.processedFiles, 0);
    expect(unsupported.warnings.join(), contains('OpenXML'));
  });

  test('Word embedded image stays linked after source file removal', () async {
    final dir = await Directory.systemTemp.createTemp('manual-media-');
    addTearDown(() => dir.delete(recursive: true));
    const xml = '<w:document xmlns:w="urn:w" xmlns:a="urn:a" xmlns:r="urn:r"><w:body>'
        '<w:p><w:r><w:t>발신 취소하기</w:t><a:blip r:embed="rId7"/></w:r></w:p>'
        '</w:body></w:document>';
    const rels = '<Relationships><Relationship Id="rId7" Target="media/image.png"/></Relationships>';
    final bytes = Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aEfoAAAAASUVORK5CYII='));
    final zip = Archive()
      ..addFile(ArchiveFile('word/document.xml', utf8.encode(xml).length, utf8.encode(xml)))
      ..addFile(ArchiveFile('word/_rels/document.xml.rels', utf8.encode(rels).length, utf8.encode(rels)))
      ..addFile(ArchiveFile('word/media/image.png', bytes.length, bytes));
    final file = File('${dir.path}/image.docx');
    await file.writeAsBytes(ZipEncoder().encode(zip)!);
    final repo = _MemoryRepository();
    final media = ManualMediaStore(directory: Directory('${dir.path}/saved'));
    final service = ManualDocumentImportService(repo, mediaStore: media);
    final result = await service.importDocuments([file.path]);
    expect(result.processedFiles, 1);
    final entry = repo.entries.values.single;
    expect(entry.answer, '발신 취소하기');
    final attached = await media.imagesFor(entry.id);
    expect(attached.length, 1);
    await file.delete();
    expect(await media.imageBytes(attached.single['id'] as String), bytes);
  });
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


