/// Image Based VOC Service
/// 이미지 업로드 → OCR → 에러코드/화면 분석 → VOC 자동 생성

import 'dart:io';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:uuid/uuid.dart';

/// 이미지 분석 결과
class ImageAnalysisResult {
  final String extractedText; // OCR 결과
  final List<ErrorCode> detectedErrors; // 감지된 에러코드
  final String screenshotAnalysis; // 화면 분석 결과
  final String estimatedIssue; // 예상 장애
  final double confidence; // 0.0 ~ 1.0
  final String language;
  final List<String> keywords;

  ImageAnalysisResult({
    required this.extractedText,
    required this.detectedErrors,
    required this.screenshotAnalysis,
    required this.estimatedIssue,
    required this.confidence,
    required this.language,
    required this.keywords,
  });
}

/// 감지된 에러코드
class ErrorCode {
  final String code; // 에러코드 (예: E001, ERR_001)
  final String? meaning; // 의미
  final String? solution; // 해결 방법

  ErrorCode({
    required this.code,
    this.meaning,
    this.solution,
  });
}

/// Image VOC 생성 옵션
class ImageVocOptions {
  final String fileName;
  final String filePath;
  final String? customer;
  final String? project;
  final bool extractErrorCodes; // 에러코드 추출 여부
  final bool analyzeScreenshot; // 화면 분석 여부
  final bool autoRunWorkflow;

  ImageVocOptions({
    required this.fileName,
    required this.filePath,
    this.customer,
    this.project,
    this.extractErrorCodes = true,
    this.analyzeScreenshot = true,
    this.autoRunWorkflow = true,
  });
}

/// Image VOC Service
abstract class ImageVocService {
  /// 이미지 파일 분석
  Future<ImageAnalysisResult> analyzeImage(String filePath);

  /// 이미지에서 VOC 생성
  Future<VocEntity> createVocFromImage(
    ImageVocOptions options,
    AiService aiService,
  );

  /// 지원 포맷 확인
  bool isSupportedFormat(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['png', 'jpg', 'jpeg', 'bmp', 'webp'].contains(ext);
  }

  /// 파일 유효성 확인
  Future<bool> validateImageFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final size = await file.length();
      // 최대 50MB
      return size > 0 && size < 50 * 1024 * 1024;
    } catch (e) {
      return false;
    }
  }

  /// 이미지 크기 조회
  Future<ImageDimensions> getImageDimensions(String filePath);
}

class ImageDimensions {
  final int width;
  final int height;

  ImageDimensions({required this.width, required this.height});
}

/// Vision API를 통한 구현 (예: OpenAI Vision)
class VisionImageVocService extends ImageVocService {
  final AiService _aiService;

  VisionImageVocService(this._aiService);

  @override
  Future<ImageAnalysisResult> analyzeImage(String filePath) async {
    try {
      // OpenAI Vision API 호출 또는 로컬 모델 사용
      // 여기서는 더미 구현

      final extractedText = 'Extracted text from image using OCR';
      final errors = [
        ErrorCode(
          code: 'ERR_001',
          meaning: 'Database Connection Error',
          solution: 'Check database credentials and connection',
        ),
      ];

      final analysis =
          'This appears to be an error screen with error code ERR_001';
      const estimatedIssue = 'Database connectivity issue';

      return ImageAnalysisResult(
        extractedText: extractedText,
        detectedErrors: errors,
        screenshotAnalysis: analysis,
        estimatedIssue: estimatedIssue,
        confidence: 0.85,
        language: 'en',
        keywords: ['database', 'error', 'connection'],
      );
    } catch (e) {
      throw Exception('Image analysis failed: $e');
    }
  }

  @override
  Future<VocEntity> createVocFromImage(
    ImageVocOptions options,
    AiService aiService,
  ) async {
    // 이미지 파일 검증
    final isValid = await validateImageFile(options.filePath);
    if (!isValid) {
      throw Exception('Invalid image file: ${options.filePath}');
    }

    // 이미지 분석
    final analysis = await analyzeImage(options.filePath);

    // 제목 생성
    final title = analysis.estimatedIssue.isEmpty
        ? 'Image Based VOC'
        : analysis.estimatedIssue.split(' ').take(10).join(' ');

    // 내용 생성
    final content = '''
===== 이미지 분석 결과 =====

**추출된 텍스트:**
${analysis.extractedText}

**화면 분석:**
${analysis.screenshotAnalysis}

**감지된 에러코드:**
${analysis.detectedErrors.isNotEmpty ? analysis.detectedErrors.map((e) => '- ${e.code}: ${e.meaning ?? "N/A"}').join('\n') : 'None'}

**예상 장애:**
${analysis.estimatedIssue}

**신뢰도:** ${(analysis.confidence * 100).toStringAsFixed(1)}%
**언어:** ${analysis.language}
''';

    // VOC 엔티티 생성
    final now = DateTime.now();
    final voc = VocEntity(
      id: const Uuid().v4(),
      title: title,
      content: content,
      category: 'Screenshot Analysis',
      customer: options.customer ?? 'Image User',
      project: options.project ?? 'Visual Input',
      priority: _determinePriorityFromAnalysis(analysis),
      status: 'OPEN',
      source: 'image',
      sourceRef: options.fileName,
      createdAt: now,
      updatedAt: now,
    );

    return voc;
  }

  @override
  Future<ImageDimensions> getImageDimensions(String filePath) async {
    try {
      // Image package를 사용하여 이미지 정보 읽기
      // 여기서는 더미 구현
      return ImageDimensions(width: 1920, height: 1080);
    } catch (e) {
      throw Exception('Failed to get image dimensions: $e');
    }
  }

  /// 분석 결과에서 우선순위 결정
  String _determinePriorityFromAnalysis(ImageAnalysisResult analysis) {
    // 에러코드나 키워드 기반 우선순위 결정
    if (analysis.estimatedIssue.toLowerCase().contains('critical') ||
        analysis.estimatedIssue.toLowerCase().contains('urgent')) {
      return 'HIGH';
    }

    if (analysis.detectedErrors
        .any((e) => e.code.toLowerCase().contains('critical'))) {
      return 'HIGH';
    }

    if (analysis.confidence < 0.5) {
      return 'LOW';
    }

    return 'MEDIUM';
  }
}

/// Local ML Kit를 통한 구현 (예: Google ML Kit)
class LocalMlKitImageVocService extends ImageVocService {
  final AiService _aiService;

  LocalMlKitImageVocService(this._aiService);

  @override
  Future<ImageAnalysisResult> analyzeImage(String filePath) async {
    try {
      // google_mlkit_text_recognition 패키지 사용
      // 또는 tensorflow_lite 사용

      return ImageAnalysisResult(
        extractedText: 'Text extracted using ML Kit',
        detectedErrors: [],
        screenshotAnalysis: 'Image analysis completed',
        estimatedIssue: 'No critical issues detected',
        confidence: 0.75,
        language: 'ko',
        keywords: [],
      );
    } catch (e) {
      throw Exception('Local image analysis failed: $e');
    }
  }

  @override
  Future<VocEntity> createVocFromImage(
    ImageVocOptions options,
    AiService aiService,
  ) async {
    final isValid = await validateImageFile(options.filePath);
    if (!isValid) throw Exception('Invalid image file');

    final analysis = await analyzeImage(options.filePath);

    final now = DateTime.now();
    return VocEntity(
      id: const Uuid().v4(),
      title: 'Image VOC: ${options.fileName}',
      content: '''
Extracted Text:
${analysis.extractedText}

Analysis:
${analysis.screenshotAnalysis}
''',
      category: 'Screenshot',
      customer: options.customer ?? 'Image User',
      project: options.project ?? 'Visual',
      priority: 'MEDIUM',
      status: 'OPEN',
      source: 'image',
      sourceRef: options.fileName,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<ImageDimensions> getImageDimensions(String filePath) async {
    return ImageDimensions(width: 1280, height: 720);
  }
}
