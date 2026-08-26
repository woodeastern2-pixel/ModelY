import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

import '../../core/utils/vector_utils.dart';
import '../../domain/entities/knowledge_base_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';

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
  ManualDocumentImportService(this._kbRepository);

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
        final text = await _extractText(file.path, extension);
        final normalized = _normalizeText(text);

        if (normalized.trim().isEmpty) {
          warnings.add('$fileName: 텍스트 추출 결과가 비어 있어 건너뜀');
          continue;
        }

        final sections = _buildSections(normalized);
        if (sections.isEmpty) {
          warnings.add('$fileName: 처리 가능한 본문이 없어 건너뜀');
          continue;
        }

        preparedDocs.add(
          _PreparedManualDoc(
            filePath: file.path,
            fileName: fileName,
            sections: sections,
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
          final sectionLabel = _headline(section);
          final fallbackQuestion = _buildQuestion(doc.fileName, i + 1, section);

          List<ManualGeneratedQa> qaItems = const [];
          if (qaGenerator != null) {
            try {
              qaItems = await qaGenerator(
                doc.fileName,
                i + 1,
                sectionLabel,
                section.body,
              );
            } catch (e) {
              warnings.add('${doc.fileName} 섹션 ${i + 1}: AI 질문 분해 실패, 기본 형태로 저장 ($e)');
            }
          }

          if (qaItems.isEmpty) {
            final fallbackAnswer = answerRefiner == null
                ? section.body
                : await answerRefiner(fallbackQuestion, section.body);
            qaItems = [
              ManualGeneratedQa(
                question: fallbackQuestion,
                answer: fallbackAnswer,
              ),
            ];
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
            final embedding = VectorUtils.simpleTextEmbedding('${qa.question} ${qa.answer}');

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
    return const ['pdf', 'docx', 'xlsx', 'pptx', 'doc', 'xls', 'ppt'].contains(ext);
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
      throw Exception('구형 포맷($extension)은 직접 파싱이 어렵습니다. OpenXML(docx/xlsx/pptx)로 저장 후 업로드해 주세요.');
    }

    throw Exception('지원하지 않는 확장자: $extension');
  }

  Future<String> _extractFromPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      return text;
    } finally {
      document.dispose();
    }
  }

  Future<String> _extractFromDocx(String filePath) async {
    final archive = await _readZipArchive(filePath);
    final parts = <String>[];

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      if (!entry.name.startsWith('word/')) continue;
      if (!entry.name.endsWith('.xml')) continue;

      final content = utf8.decode(entry.content as List<int>, allowMalformed: true);
      parts.add(_extractTextNodesFromXml(content));
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
    const maxChars = 650;
    final paragraphs = input
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final sections = <_ManualSection>[];
    String? currentHeading;

    for (final paragraph in paragraphs) {
      final lines = paragraph
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        continue;
      }

      final lineSections = <String>[];
      for (final line in lines) {
        if (_looksLikeHeading(line)) {
          currentHeading = line;
          continue;
        }

        if (_looksLikeListItem(line)) {
          lineSections.add(_combineHeading(currentHeading, line));
          continue;
        }

        lineSections.add(line);
      }

      if (lineSections.isEmpty) {
        continue;
      }

      for (final lineSection in lineSections) {
        final pieces = _splitBySize(lineSection, maxChars);
        for (final piece in pieces) {
          final body = piece.trim();
          if (body.isEmpty) continue;
          sections.add(
            _ManualSection(
              heading: currentHeading,
              body: body,
            ),
          );
        }
      }
    }

    return sections;
  }

  List<String> _splitBySize(String text, int maxChars) {
    if (text.length <= maxChars) {
      return [text];
    }

    final sentenceParts = text
        .split(RegExp(r'(?<=[.!?。！？])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (sentenceParts.length > 1) {
      final chunks = <String>[];
      final current = StringBuffer();
      for (final sentence in sentenceParts) {
        final nextLength = current.isEmpty
            ? sentence.length
            : current.length + 1 + sentence.length;
        if (nextLength > maxChars && current.isNotEmpty) {
          chunks.add(current.toString().trim());
          current.clear();
        }
        if (current.isNotEmpty) {
          current.write(' ');
        }
        current.write(sentence);
      }
      if (current.isNotEmpty) {
        chunks.add(current.toString().trim());
      }
      if (chunks.isNotEmpty) {
        return chunks;
      }
    }

    return _hardSplit(text, maxChars);
  }

  List<String> _hardSplit(String text, int maxChars) {
    final pieces = <String>[];
    int start = 0;
    while (start < text.length) {
      final end = (start + maxChars < text.length) ? start + maxChars : text.length;
      pieces.add(text.substring(start, end));
      start = end;
    }
    return pieces;
  }

  bool _looksLikeHeading(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > 70) return false;
    return RegExp(r'^(\d+[\.)]|[가-힣]\.|[A-Z]\.|제\d+장|제\d+절|\[.*\])')
            .hasMatch(trimmed) ||
        trimmed.endsWith(':') ||
        trimmed.endsWith(']');
  }

  bool _looksLikeListItem(String line) {
    return RegExp(r'^(?:[-*•]|\d+[\.)]|[가-힣]\.)\s+').hasMatch(line.trim());
  }

  String _combineHeading(String? heading, String body) {
    if (heading == null || heading.trim().isEmpty) return body;
    return '$heading\n$body';
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
  final List<_ManualSection> sections;

  const _PreparedManualDoc({
    required this.filePath,
    required this.fileName,
    required this.sections,
  });
}
