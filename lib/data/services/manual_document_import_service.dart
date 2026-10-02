import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'manual_media_store.dart';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../../core/utils/search_query_expander.dart';
import '../../core/utils/vector_utils.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';
import '../../domain/repositories/indexed_knowledge_repository.dart';

class ManualImportResult {
  final int selectedFiles;
  final int processedFiles;
  final int importedEntries;
  final int updatedEntries;
  final List<String> warnings;

  const ManualImportResult({
    required this.selectedFiles,
    required this.processedFiles,
    required this.importedEntries,
    required this.updatedEntries,
    required this.warnings,
  });
}

class ManualGeneratedQa {
  final String question;
  final String answer;

  const ManualGeneratedQa({
    required this.question,
    required this.answer,
  });
}

class ManualImportProgress {
  final int totalFiles;
  final int totalSections;
  final int processedSections;
  final int generatedEntries;
  final String? currentFile;

  const ManualImportProgress({
    required this.totalFiles,
    required this.totalSections,
    required this.processedSections,
    required this.generatedEntries,
    this.currentFile,
  });
}

class ManualDocumentImportService {
  ManualDocumentImportService(this._kbRepository, {ManualMediaStore? mediaStore})
      : _mediaStore = mediaStore ?? const ManualMediaStore();

  final ManualMediaStore _mediaStore;
  final _extractedImages = <String, Uint8List>{};

  static const String manualCategory = '시스템매뉴얼';

  final KnowledgeBaseRepository _kbRepository;

  Future<ManualImportResult> importDocuments(
    List<String> filePaths, {
    Future<String> Function(String question, String sourceText)? answerRefiner,
    Future<List<ManualGeneratedQa>> Function(
      String fileName,
      int sectionNumber,
      String sectionTitle,
      String sectionBody,
    )?
    qaGenerator,
    void Function(ManualImportProgress progress)? onProgress,
  }) async {
    int processedFiles = 0;
    int importedEntries = 0;
    int updatedEntries = 0;
    final warnings = <String>[];

    final preparedDocs = <_PreparedManualDoc>[];

    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (!await file.exists()) {
          warnings.add('파일을 찾을 수 없음: $filePath');
          continue;
        }

        final extension = p.extension(file.path).toLowerCase().replaceAll('.', '');
        final fileName = p.basename(file.path);
        _extractedImages.clear();
        final text = await _extractText(file.path, extension);
        final normalized = _normalizeText(text);
        if (extension == 'pdf' || extension == 'docx') {
          warnings.add('$fileName: 텍스트·표와 Word의 삽입 이미지를 보존합니다. 이미지 속 글자 자동 인식과 PDF 이미지 추출은 지원하지 않습니다.');
        }

        if (normalized.trim().isEmpty) {
          warnings.add('$fileName: 텍스트 추출 결과가 비어 있어 건너뜀');
          continue;
        }

        if (_kbRepository is IndexedKnowledgeRepository) {
          final bytes = await file.readAsBytes();
          await (_kbRepository as IndexedKnowledgeRepository).preserveOriginal(
            fileName:fileName, fingerprint:sha256.convert(bytes).toString(),
            bytes:bytes, extractedText:normalized, images:Map.of(_extractedImages));
        }

        final sections = _buildSections(normalized);
        if (sections.isEmpty) {
          warnings.add('$fileName: 처리 가능한 본문이 없어 건너뜀');
          continue;
        }

        preparedDocs.add(
          _PreparedManualDoc(
            filePath: file.path,
            fingerprint: sha256.convert(await file.readAsBytes()).toString(),
            fileName: fileName,
            sections: sections,
            images: Map.of(_extractedImages),
          ),
        );
      } catch (e) {
        warnings.add('${p.basename(filePath)}: $e');
      }
    }

    final totalSections = preparedDocs.fold<int>(
      0,
      (sum, doc) => sum + doc.sections.length,
    );
    int processedSections = 0;
    int generatedEntries = 0;

    onProgress?.call(
      ManualImportProgress(
        totalFiles: filePaths.length,
        totalSections: totalSections,
        processedSections: processedSections,
        generatedEntries: generatedEntries,
      ),
    );

    for (final doc in preparedDocs) {
      try {
        for (int i = 0; i < doc.sections.length; i++) {
          final section = doc.sections[i];
          final imageIds = RegExp(r'\[manual-image:([a-z0-9-]+)\]')
              .allMatches(section.body).map((m) => m.group(1)!).toSet();
          final cleanBody = section.body.replaceAll(RegExp(r'\[manual-image:[a-z0-9-]+\]'), '').trim();
          final sectionLabel = _headline(_ManualSection(heading: section.heading, body: cleanBody));
          final fallbackQuestion = _buildQuestion(doc.fileName, i + 1, section);

          final now = DateTime.now();
          final sourceId = 'manual-source-${sha1.convert(utf8.encode(
              '${doc.fileName}::${doc.fingerprint}::$i${imageIds.isEmpty ? '' : '::media-v1'}')).toString()}';
          final source = KnowledgeBaseEntity(
            id: sourceId,
            question: '[${doc.fileName}] 원문 섹션 ${i + 1}: $sectionLabel',
            answer: cleanBody.isEmpty ? '이 구간의 설명은 첨부 원본 이미지를 확인해 주세요.' : cleanBody,
            category: manualCategory,
            customer: doc.fileName,
            project: 'manual-upload',
            resolvedAt: now,
            createdAt: now,
          );
          await _mediaStore.save(sourceId, {
            for (final id in imageIds) if (doc.images.containsKey(id)) id: doc.images[id]!,
          });
          if (await _kbRepository.getEntryById(sourceId) == null) {
            await _kbRepository.createEntry(source);
            importedEntries++;
          } else {
            updatedEntries++;
          }
          generatedEntries++;

          // Raw source is durable before any optional AI operation starts.
          List<ManualGeneratedQa> qaItems = const [];
          if (qaGenerator != null) {
            try {
              qaItems = await qaGenerator(
                doc.fileName,
                i + 1,
                sectionLabel,
                cleanBody,
              );
            } catch (e) {
              warnings.add('${doc.fileName} 섹션 ${i + 1}: AI 질문 분해 실패, 기본 형태로 저장 ($e)');
            }
          }

          if (qaItems.isEmpty && answerRefiner != null) {
            try {
              final refined = await answerRefiner(fallbackQuestion, cleanBody);
              if (refined.trim().isNotEmpty) {
                qaItems = [ManualGeneratedQa(question: fallbackQuestion, answer: refined)];
              }
            } catch (e) {
              warnings.add('${doc.fileName} 섹션 ${i + 1}: AI 정리 실패, 원문 보존 ($e)');
            }
          }

          for (int qaIndex = 0; qaIndex < qaItems.length; qaIndex++) {
            final qa = qaItems[qaIndex];
            final id = _buildDeterministicQaId(
              doc.filePath,
              i,
              qaIndex,
              qa.question,
              qa.answer,
            );
            final now = DateTime.now();
            final embedding = VectorUtils.simpleTextEmbedding(
              SearchQueryExpander.expand(
                '${qa.question} ${qa.answer} ${doc.fileName}',
              ),
            );

            final entity = KnowledgeBaseEntity(
              id: id,
              question: qa.question,
              answer: qa.answer,
              category: manualCategory,
              customer: doc.fileName,
              project: 'manual-upload',
              embedding: embedding,
              resolvedAt: now,
              createdAt: now,
            );

            final existing = await _kbRepository.getEntryById(id);
            if (existing == null) {
              await _kbRepository.createEntry(entity);
              importedEntries++;
            } else {
              await _kbRepository.updateEntry(entity);
              updatedEntries++;
            }
            generatedEntries++;
          }

          processedSections++;
          onProgress?.call(
            ManualImportProgress(
              totalFiles: filePaths.length,
              totalSections: totalSections,
              processedSections: processedSections,
              generatedEntries: generatedEntries,
              currentFile: doc.fileName,
            ),
          );
        }

        processedFiles++;
      } catch (e) {
        warnings.add('${doc.fileName}: $e');
      }
    }

    return ManualImportResult(
      selectedFiles: filePaths.length,
      processedFiles: processedFiles,
      importedEntries: importedEntries,
      updatedEntries: updatedEntries,
      warnings: warnings,
    );
  }

  bool isSupported(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    return const ['pdf', 'docx', 'xlsx', 'pptx', 'doc', 'xls', 'ppt']
        .contains(ext);
  }

  Future<String> _extractText(String filePath, String extension) async {
    if (extension == 'pdf') {
      return _extractFromPdf(filePath);
    }
    if (extension == 'docx') {
      return _extractFromDocx(filePath);
    }
    if (extension == 'xlsx') {
      return _extractFromXlsx(filePath);
    }
    if (extension == 'pptx') {
      return _extractFromPptx(filePath);
    }

    if (extension == 'doc' || extension == 'xls' || extension == 'ppt') {
      throw Exception(
        '구형 포맷($extension)은 직접 파싱이 어렵습니다. OpenXML(docx/xlsx/pptx)로 저장 후 업로드해 주세요.',
      );
    }

    throw Exception('지원하지 않는 확장자: $extension');
  }

  Future<String> _extractFromPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final signature = ascii.decode(
      bytes.take(64).toList(),
      allowInvalid: true,
    );
    if (signature.contains('NASCA DRM FILE')) {
      throw Exception(
        'NASCA DRM으로 보호된 문서입니다. DRM이 해제된 PDF로 저장한 뒤 다시 추가해 주세요.',
      );
    }
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final pages = <String>[];
      for (var page = 0; page < document.pages.count; page++) {
        final text = extractor.extractText(startPageIndex: page, endPageIndex: page);
        if (text.trim().isNotEmpty) pages.add('[페이지 ${page + 1}]\n$text');
      }
      return pages.join('\n\n');
    } finally {
      document.dispose();
    }
  }

  Future<String> _extractFromDocx(String filePath) async {
    final archive = await _readZipArchive(filePath);
    final parts = <String>[];
    final relations = <String, String>{};
    final rels = archive.findFile('word/_rels/document.xml.rels');
    if (rels != null) {
      final xml = XmlDocument.parse(utf8.decode(rels.content as List<int>));
      for (final rel in xml.descendants.whereType<XmlElement>()) {
        if (rel.name.local != 'Relationship' || rel.getAttribute('TargetMode') == 'External') continue;
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) {
          relations[id] = target.startsWith('/') ? target.substring(1)
              : p.posix.normalize(p.posix.join('word', target));
        }
      }
    }
    String imagesOf(XmlElement node) {
      final ids = <String>[];
      for (final element in node.descendants.whereType<XmlElement>()) {
        if (element.name.local != 'blip' && element.name.local != 'imagedata') continue;
        final refs = element.attributes.where((a) =>
            a.name.local == 'embed' || a.name.local == 'id').map((a) => a.value);
        final rid = refs.isEmpty ? null : refs.first;
        final target = relations[rid];
        final media = target == null ? null : archive.findFile(target);
        if (media == null) continue;
        final bytes = Uint8List.fromList(media.content as List<int>);
        final id = 'local-${sha256.convert(bytes)}';
        _extractedImages[id] = bytes;
        ids.add('[manual-image:$id]');
      }
      return ids.join('\n');
    }

    for (final entry in archive.files) {
      if (!entry.isFile || entry.name != 'word/document.xml') continue;
      final document = XmlDocument.parse(utf8.decode(entry.content as List<int>));
      final body = document.descendants.whereType<XmlElement>()
          .firstWhere((e) => e.name.local == 'body');
      String textOf(XmlElement node) => node.descendants.whereType<XmlElement>()
          .where((e) => e.name.local == 't').map((e) => e.innerText).join();
      for (final node in body.childElements) {
        if (node.name.local == 'tbl') {
          final rows = node.descendants.whereType<XmlElement>()
              .where((e) => e.name.local == 'tr');
          parts.add(rows.map((row) => row.childElements
              .where((e) => e.name.local == 'tc').map(textOf).join(' | ')).join('\n'));
          final images = imagesOf(node);
          if (images.isNotEmpty) parts.add(images);
        } else {
          final text = [textOf(node), imagesOf(node)].where((s) => s.isNotEmpty).join('\n');
          if (text.trim().isNotEmpty) parts.add(text);
        }
      }
    }

    return parts.join('\n\n');
  }

  Future<String> _extractFromPptx(String filePath) async {
    final archive = await _readZipArchive(filePath);
    final slideEntries = archive.files
        .where((entry) => entry.isFile && entry.name.startsWith('ppt/slides/slide') && entry.name.endsWith('.xml'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final parts = <String>[];
    for (final entry in slideEntries) {
      final content = utf8.decode(entry.content as List<int>, allowMalformed: true);
      parts.add(_extractTextNodesFromXml(content));
    }

    return parts.join('\n\n');
  }

  Future<String> _extractFromXlsx(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final buffer = StringBuffer();

    for (final tableEntry in excel.tables.entries) {
      final sheetName = tableEntry.key;
      final sheet = tableEntry.value;

      buffer.writeln('[시트] $sheetName');
      for (final row in sheet.rows) {
        final values = row
            .map((cell) => cell?.value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList();
        if (values.isEmpty) continue;
        buffer.writeln(values.join(' | '));
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  Future<Archive> _readZipArchive(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    return archive;
  }

  String _extractTextNodesFromXml(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final texts = document
        .descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 't')
        .map((e) => e.innerText)
        .where((text) => text.trim().isNotEmpty)
        .toList();
    return texts.join(' ');
  }

  String _normalizeText(String input) {
    return input
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  List<_ManualSection> _buildSections(String input) {
    const maxChars = 2400;
    final paragraphs = input.split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim()).where((e) => e.isNotEmpty);
    final result = <_ManualSection>[];
    final buffer = <String>[];
    var length = 0;
    String? heading;
    void flush() {
      if (buffer.isEmpty) return;
      result.add(_ManualSection(heading: heading, body: buffer.join('\n\n')));
      buffer.clear();
      length = 0;
    }
    for (final paragraph in paragraphs) {
      final isPage = paragraph.startsWith('[페이지 ');
      if (isPage) flush();
      if (length + paragraph.length > maxChars) flush();
      if (buffer.isEmpty) heading = paragraph.split('\n').first;
      // Keep a whole paragraph/table even if it exceeds the target size.
      buffer.add(paragraph);
      length += paragraph.length;
    }
    flush();
    return result;
  }

  String _buildQuestion(String fileName, int index, _ManualSection section) {
    final headline = _headline(section);
    final base = '[$fileName] 매뉴얼 섹션 $index';
    if (headline.isEmpty) {
      return '$base는 어떻게 하나요?';
    }
    return '$base $headline은 어떻게 하나요?';
  }

  String _headline(_ManualSection section) {
    final heading = section.heading?.trim();
    if (heading != null && heading.isNotEmpty) {
      return _trimHeadline(heading);
    }

    final firstLine = section.body.split('\n').first.trim();
    if (firstLine.isEmpty) return '핵심 절차';
    return _trimHeadline(firstLine);
  }

  String _trimHeadline(String input) {
    final stripped = input.replaceAll(RegExp(r'^(?:[-*•]|\d+[\.)]|[가-힣]\.)\s+'), '');
    if (stripped.length <= 40) return stripped;
    return '${stripped.substring(0, 40)}...';
  }

  String _buildDeterministicQaId(
    String filePath,
    int sectionIndex,
    int qaIndex,
    String question,
    String answer,
  ) {
    final digest = sha1
        .convert(utf8.encode('$filePath::$sectionIndex::$qaIndex::$question::$answer'))
        .toString();
    return 'manual-${digest.substring(0, 24)}';
  }
}

class _ManualSection {
  final String? heading;
  final String body;

  const _ManualSection({
    required this.heading,
    required this.body,
  });
}

class _PreparedManualDoc {
  final String filePath;
  final String fileName;
  final String fingerprint;
  final Map<String, Uint8List> images;
  final List<_ManualSection> sections;

  const _PreparedManualDoc({
    required this.filePath,
    required this.fileName,
    required this.sections,
    required this.fingerprint,
    required this.images,
  });
}

