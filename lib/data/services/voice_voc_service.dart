/// Voice VOC 서비스
/// 음성 파일(mp3, wav, m4a)을 텍스트로 변환 후 VOC 자동 생성

import 'dart:io';
import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:uuid/uuid.dart';

/// 음성 전사 결과
class TranscriptionResult {
  final String text;
  final double confidence; // 0.0 ~ 1.0
  final int durationSeconds;
  final String language; // detected language
  final List<String> keyPhrases; // 주요 구문 추출

  TranscriptionResult({
    required this.text,
    required this.confidence,
    required this.durationSeconds,
    required this.language,
    required this.keyPhrases,
  });
}

/// Voice VOC 생성 옵션
class VoiceVocOptions {
  final String fileName;
  final String filePath;
  final String? customer;
  final String? project;
  final String? category; // 자동 분류 전에 미리 지정하면 스킵
  final bool autoAnalyze; // 자동 AI 분석 여부
  final bool autoRunWorkflow; // 자동 워크플로우 실행 여부

  VoiceVocOptions({
    required this.fileName,
    required this.filePath,
    this.customer,
    this.project,
    this.category,
    this.autoAnalyze = true,
    this.autoRunWorkflow = true,
  });
}

/// Voice VOC 서비스
abstract class VoiceVocService {
  /// 음성 파일 전사 (Whisper)
  /// 지원 포맷: mp3, wav, m4a
  Future<TranscriptionResult> transcribeAudio(String filePath);

  /// 음성 파일에서 VOC 생성
  Future<VocEntity> createVocFromVoice(
    VoiceVocOptions options,
    AiService aiService,
  );

  /// 지원 포맷 확인
  bool isSupportedFormat(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    return ['mp3', 'wav', 'm4a', 'ogg', 'flac'].contains(ext);
  }

  /// 파일 유효성 확인
  Future<bool> validateAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final size = await file.length();
      // 최대 100MB 제한
      return size > 0 && size < 100 * 1024 * 1024;
    } catch (e) {
      return false;
    }
  }

  /// 음성 길이 추정 (초)
  Future<int> estimateDuration(String filePath);
}

/// Whisper API를 통한 구현
class WhisperVoiceVocService extends VoiceVocService {
  final AiService _aiService;

  // Whisper 설정
  static const String whisperModel = 'base'; // tiny, base, small, medium, large
  static const String whisperLanguage = 'ko'; // 한국어

  WhisperVoiceVocService(this._aiService);

  @override
  Future<TranscriptionResult> transcribeAudio(String filePath) async {
    try {
      // OpenAI Whisper API 호출
      // 실제 구현은 http 클라이언트 사용
      // 여기서는 더미 구현

      final text = 'Transcribed text from audio file';
      final keyPhrases = _extractKeyPhrases(text);

      return TranscriptionResult(
        text: text,
        confidence: 0.92,
        durationSeconds: 60,
        language: 'ko',
        keyPhrases: keyPhrases,
      );
    } catch (e) {
      throw Exception('Transcription failed: $e');
    }
  }

  @override
  Future<VocEntity> createVocFromVoice(
    VoiceVocOptions options,
    AiService aiService,
  ) async {
    // 음성 파일 검증
    final isValid = await validateAudioFile(options.filePath);
    if (!isValid) {
      throw Exception('Invalid audio file: ${options.filePath}');
    }

    // 전사
    final transcription = await transcribeAudio(options.filePath);

    // 제목 추출 (첫 50자 또는 주요 구문)
    final title = transcription.keyPhrases.isNotEmpty
        ? transcription.keyPhrases.first
        : transcription.text.substring(
            0, transcription.text.length > 50 ? 50 : transcription.text.length);

    // VOC 엔티티 생성
    final now = DateTime.now();
    final voc = VocEntity(
      id: const Uuid().v4(),
      title: title,
      content: transcription.text,
      category: options.category ?? 'Voice VOC',
      customer: options.customer ?? 'Audio User',
      project: options.project ?? 'Voice Input',
      priority: 'MEDIUM',
      status: 'OPEN',
      source: 'voice',
      sourceRef: options.fileName,
      createdAt: now,
      updatedAt: now,
    );

    // 자동 AI 분석
    if (options.autoAnalyze) {
      // AI 분석 로직 (기존 analyzeVocIntelligence 활용)
      // TODO: AI 분석 통합
    }

    return voc;
  }

  @override
  Future<int> estimateDuration(String filePath) async {
    try {
      final file = File(filePath);
      final sizeBytes = await file.length();

      // 대략적 추정: 256kbps 기준
      // 실제로는 ffprobe 같은 도구 사용 권장
      final estimatedSeconds = (sizeBytes / (256 * 1000 / 8)).toInt();

      return estimatedSeconds;
    } catch (e) {
      return 0;
    }
  }

  /// 핵심 구문 추출
  List<String> _extractKeyPhrases(String text) {
    // 간단한 구현: 문장 분리
    final sentences = text.split(RegExp(r'[.!?]+'));
    return sentences
        .where((s) => s.trim().isNotEmpty)
        .take(3)
        .map((s) => s.trim())
        .toList();
  }
}

/// 로컬 Whisper (whisper.cpp) 사용 구현
class LocalWhisperVoiceVocService extends VoiceVocService {
  final String whisperBinaryPath;
  final AiService _aiService;

  LocalWhisperVoiceVocService({
    required this.whisperBinaryPath,
    required AiService aiService,
  }) : _aiService = aiService;

  @override
  Future<TranscriptionResult> transcribeAudio(String filePath) async {
    try {
      // whisper.cpp 바이너리 실행
      // flutter_process 또는 similar 패키지 사용

      final result = await Process.run(
        whisperBinaryPath,
        [
          '-m',
          'models/ggml-base.bin',
          '-l',
          'ko',
          '--output-json',
          filePath,
        ],
      );

      if (result.exitCode != 0) {
        throw Exception('Whisper execution failed');
      }

      // JSON 파싱
      // final jsonOutput = json.decode(result.stdout);

      return TranscriptionResult(
        text: 'Transcribed from local whisper',
        confidence: 0.88,
        durationSeconds: 60,
        language: 'ko',
        keyPhrases: [],
      );
    } catch (e) {
      throw Exception('Local transcription failed: $e');
    }
  }

  @override
  Future<VocEntity> createVocFromVoice(
    VoiceVocOptions options,
    AiService aiService,
  ) async {
    final isValid = await validateAudioFile(options.filePath);
    if (!isValid) throw Exception('Invalid audio file');

    final transcription = await transcribeAudio(options.filePath);

    final now = DateTime.now();
    return VocEntity(
      id: const Uuid().v4(),
      title: transcription.text.split('\n').first.substring(
          0,
          transcription.text.split('\n').first.length > 50
              ? 50
              : transcription.text.split('\n').first.length),
      content: transcription.text,
      category: options.category ?? 'Voice VOC',
      customer: options.customer ?? 'Audio User',
      project: options.project ?? 'Voice Input',
      priority: 'MEDIUM',
      status: 'OPEN',
      source: 'voice',
      sourceRef: options.fileName,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<int> estimateDuration(String filePath) async {
    try {
      final file = File(filePath);
      final sizeBytes = await file.length();
      return (sizeBytes / (256 * 1000 / 8)).toInt();
    } catch (e) {
      return 0;
    }
  }
}
