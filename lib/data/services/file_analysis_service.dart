/// 첨부파일 분석 서비스
/// PDF, DOCX, XLSX, PPTX 문서 분석

import 'dart:io';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:uuid/uuid.dart';

/// 파일 분석 결과
class FileAnalysisResult {
  final String fileName;
  final String fileType; // pdf, docx, xlsx, pptx
  final String extractedText;
  final List<String> keyIssues; // 핵심 이슈 추출
  final String summary; // 요약
  final double estimatedUrgency; // 0.0 ~ 1.0
  final List<String> keywords;
  final int pageCount;
  final DateTime? createdDate;

  FileAnalysisResult({
    required this.fileName,
    required this.fileType,
    required this.extractedText,
    required this.keyIssues,
    required this.summary,
    required this.estimatedUrgency,
    required this.keywords,
    required this.pageCount,
    this.createdDate,
  });
}

/// 파일 분석 옵션
class FileAnalysisOptions {
  final String fileName;
  final String filePath;
  final String? customer;
  final String? project;
  final bool extractKeyIssues;
  final bool generateSummary;
  final bool autoRunWorkflow;
  final int? maxPages; // 처리할 최대 페이지 수

  FileAnalysisOptions({
    required this.fileName,
    required this.filePath,
    this.customer,
    this.project,
    this.extractKeyIssues = true,
    this.generateSummary = true,
    this.autoRunWorkflow = true,
    this.maxPages,
  });
}

/// 파일 분석 서비스
abstract class FileAnalysisService {
  /// 파일 분석
  Future<FileAnalysisResult> analyzeFile(String filePath);

  /// 파일에서 VOC 생성
  Future<VocEntity> createVocFromFile(FileAnalysisOptions options);

  /// 지원 포맷 확인
  bool isSupportedFormat(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['pdf', 'docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt'].contains(ext);
  }

  /// 파일 유효성 확인
  Future<bool> validateFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final size = await file.length();
      // 최대 200MB
      return size > 0 && size < 200 * 1024 * 1024;
    } catch (e) {
      return false;
    }
  }

  /// 파일 타입 식별
  String identifyFileType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ext;
  }
}

/// 기본 파일 분석 구현
class DefaultFileAnalysisService extends FileAnalysisService {
  // 파일 분석 플러그인 맵
  final Map<String, FileAnalyzer> _analyzers = {};

  DefaultFileAnalysisService() {
    _initializeAnalyzers();
  }

  void _initializeAnalyzers() {
    _analyzers['pdf'] = PdfAnalyzer();
    _analyzers['docx'] = DocxAnalyzer();
    _analyzers['doc'] = DocxAnalyzer();
    _analyzers['xlsx'] = ExcelAnalyzer();
    _analyzers['xls'] = ExcelAnalyzer();
    _analyzers['pptx'] = PowerPointAnalyzer();
    _analyzers['ppt'] = PowerPointAnalyzer();
  }

  @override
  Future<FileAnalysisResult> analyzeFile(String filePath) async {
    final isValid = await validateFile(filePath);
    if (!isValid) {
      throw Exception('Invalid file: $filePath');
    }

    final fileName = filePath.split('/').last;
    final fileType = identifyFileType(fileName);
    final analyzer = _analyzers[fileType];

    if (analyzer == null) {
      throw Exception('Unsupported file type: $fileType');
    }

    return await analyzer.analyze(filePath);
  }

  @override
  Future<VocEntity> createVocFromFile(FileAnalysisOptions options) async {
    final isValid = await validateFile(options.filePath);
    if (!isValid) {
      throw Exception('Invalid file: ${options.filePath}');
    }

    final analysis = await analyzeFile(options.filePath);

    // 제목 생성
    final title = analysis.summary.isEmpty
        ? options.fileName
        : analysis.summary.split('\n').first.substring(
            0,
            analysis.summary.split('\n').first.length > 60
                ? 60
                : analysis.summary.split('\n').first.length);

    // 내용 생성
    final content = '''
===== 첨부파일 분석 결과 =====

**파일명:** ${analysis.fileName}
**파일형:** ${analysis.fileType.toUpperCase()}
**페이지:** ${analysis.pageCount}

**요약:**
${analysis.summary}

**핵심 이슈:**
${analysis.keyIssues.isNotEmpty ? analysis.keyIssues.map((i) => '- $i').join('\n') : 'No critical issues'}

**주요 키워드:** ${analysis.keywords.join(', ')}

**긴급도 점수:** ${(analysis.estimatedUrgency * 100).toStringAsFixed(0)}%

**원본 텍스트 (처음 500자):**
${analysis.extractedText.length > 500 ? analysis.extractedText.substring(0, 500) + '...' : analysis.extractedText}
''';

    // 긴급도에 따른 우선순위 결정
    final priority = analysis.estimatedUrgency > 0.7
        ? 'HIGH'
        : analysis.estimatedUrgency > 0.4
            ? 'MEDIUM'
            : 'LOW';

    final now = DateTime.now();
    return VocEntity(
      id: const Uuid().v4(),
      title: title,
      content: content,
      category: 'Document Analysis',
      customer: options.customer ?? 'File User',
      project: options.project ?? 'Document',
      priority: priority,
      status: 'OPEN',
      source: 'file',
      sourceRef: options.fileName,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// 파일 분석기 인터페이스
abstract class FileAnalyzer {
  Future<FileAnalysisResult> analyze(String filePath);
}

/// PDF 분석기
class PdfAnalyzer implements FileAnalyzer {
  @override
  Future<FileAnalysisResult> analyze(String filePath) async {
    try {
      // pdf 패키지 또는 similar 사용
      // 더미 구현
      return FileAnalysisResult(
        fileName: filePath.split('/').last,
        fileType: 'pdf',
        extractedText: 'Extracted text from PDF document',
        keyIssues: ['Issue 1', 'Issue 2'],
        summary: 'PDF document summary extracted',
        estimatedUrgency: 0.6,
        keywords: ['pdf', 'document'],
        pageCount: 5,
        createdDate: DateTime.now(),
      );
    } catch (e) {
      throw Exception('PDF analysis failed: $e');
    }
  }
}

/// DOCX 분석기
class DocxAnalyzer implements FileAnalyzer {
  @override
  Future<FileAnalysisResult> analyze(String filePath) async {
    try {
      // docx 패키지 사용
      // 더미 구현
      return FileAnalysisResult(
        fileName: filePath.split('/').last,
        fileType: 'docx',
        extractedText: 'Extracted text from Word document',
        keyIssues: [],
        summary: 'Word document summary',
        estimatedUrgency: 0.4,
        keywords: ['word', 'document'],
        pageCount: 3,
        createdDate: DateTime.now(),
      );
    } catch (e) {
      throw Exception('DOCX analysis failed: $e');
    }
  }
}

/// XLSX 분석기
class ExcelAnalyzer implements FileAnalyzer {
  @override
  Future<FileAnalysisResult> analyze(String filePath) async {
    try {
      // excel 패키지 사용
      // 더미 구현
      return FileAnalysisResult(
        fileName: filePath.split('/').last,
        fileType: 'xlsx',
        extractedText: 'Data extracted from Excel spreadsheet',
        keyIssues: ['Data anomaly detected'],
        summary: 'Excel data analysis: 5 sheets, 1000 rows',
        estimatedUrgency: 0.5,
        keywords: ['excel', 'data', 'spreadsheet'],
        pageCount: 5,
        createdDate: DateTime.now(),
      );
    } catch (e) {
      throw Exception('XLSX analysis failed: $e');
    }
  }
}

/// PowerPoint 분석기
class PowerPointAnalyzer implements FileAnalyzer {
  @override
  Future<FileAnalysisResult> analyze(String filePath) async {
    try {
      // pptx 패키지 또는 similar 사용
      // 더미 구현
      return FileAnalysisResult(
        fileName: filePath.split('/').last,
        fileType: 'pptx',
        extractedText: 'Presentation content extracted',
        keyIssues: [],
        summary: 'PowerPoint presentation: 10 slides',
        estimatedUrgency: 0.3,
        keywords: ['presentation', 'pptx'],
        pageCount: 10,
        createdDate: DateTime.now(),
      );
    } catch (e) {
      throw Exception('PPTX analysis failed: $e');
    }
  }
}
