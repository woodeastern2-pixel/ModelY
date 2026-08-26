import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/response_entity.dart';
import '../../domain/entities/voc_entity.dart';
import '../../domain/repositories/knowledge_base_repository.dart';
import '../../domain/repositories/voc_repository.dart';
import '../../presentation/viewmodels/ai_viewmodel.dart';
import '../../presentation/viewmodels/settings_viewmodel.dart';
import '../datasources/local/knowledge_base_local_datasource.dart';
import '../datasources/local/voc_local_datasource.dart';
import '../repositories/knowledge_base_repository_impl.dart';
import '../repositories/voc_repository_impl.dart';

class BulkAiProgress {
  const BulkAiProgress({
    required this.completed,
    required this.total,
    required this.success,
    required this.failed,
    required this.reused,
    this.currentTitle,
    this.lastError,
  });

  final int completed;
  final int total;
  final int success;
  final int failed;
  final int reused;
  final String? currentTitle;
  final String? lastError;
}

class BulkAiRunResult {
  const BulkAiRunResult({
    required this.total,
    required this.success,
    required this.failed,
    required this.reused,
    required this.stopped,
    this.lastError,
  });

  final int total;
  final int success;
  final int failed;
  final int reused;
  final bool stopped;
  final String? lastError;
}

class BulkAiResolveService {
  BulkAiResolveService(this.settings)
      : _vocRepository = VocRepositoryImpl(VocLocalDatasource(DatabaseHelper.instance)),
        _kbRepository = KnowledgeBaseRepositoryImpl(
          KnowledgeBaseLocalDatasource(DatabaseHelper.instance),
        );

  final SettingsViewModel settings;
  final VocRepository _vocRepository;
  final KnowledgeBaseRepository _kbRepository;
  final Uuid _uuid = const Uuid();

  Future<BulkAiRunResult> run({
    required bool Function() shouldStop,
    required void Function(BulkAiProgress progress) onProgress,
  }) async {
    final all = await _vocRepository.getAllVocs();
    final pending = all
        .where(
          (voc) =>
              voc.status == AppConstants.vocStatusOpen ||
              voc.status == AppConstants.vocStatusInProgress,
        )
        .toList();

    if (pending.isEmpty) {
      return const BulkAiRunResult(
        total: 0,
        success: 0,
        failed: 0,
        reused: 0,
        stopped: false,
      );
    }

    final concurrency = settings.aiProvider == AppConstants.aiProviderOllama ? 2 : 3;
    final workerCount = concurrency < pending.length ? concurrency : pending.length;
    var cursor = 0;
    var completed = 0;
    var success = 0;
    var failed = 0;
    var reused = 0;
    String? lastError;

    Future<void> worker() async {
      final aiVm = AiViewModel(_kbRepository, _vocRepository, settings);
      try {
        while (!shouldStop()) {
          if (cursor >= pending.length) break;
          final index = cursor;
          cursor += 1;
          final voc = pending[index];
          String? error;
          var wasReused = false;

          try {
            wasReused = await _processVoc(voc, aiVm);
            success += 1;
            if (wasReused) reused += 1;
          } catch (e) {
            failed += 1;
            error = _cleanError(e);
            lastError = error;
          } finally {
            completed += 1;
            onProgress(
              BulkAiProgress(
                completed: completed,
                total: pending.length,
                success: success,
                failed: failed,
                reused: reused,
                currentTitle: voc.title,
                lastError: error,
              ),
            );
          }
        }
      } finally {
        aiVm.dispose();
      }
    }

    final workers = List.generate(workerCount, (_) => worker());
    await Future.wait(workers);

    return BulkAiRunResult(
      total: pending.length,
      success: success,
      failed: failed,
      reused: reused,
      stopped: shouldStop() && completed < pending.length,
      lastError: lastError,
    );
  }

  Future<bool> _processVoc(VocEntity voc, AiViewModel aiVm) async {
    final responses = await _vocRepository.getResponsesByVocId(voc.id);
    final approved = responses.where((item) => item.isApproved).toList();

    if (approved.isNotEmpty) {
      await _resolveVoc(voc);
      return true;
    }

    final reusable = responses.where((item) => item.aiGenerated).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (reusable.isNotEmpty) {
      final existing = reusable.first;
      final now = DateTime.now();
      await _vocRepository.updateResponse(
        existing.copyWith(
          status: AppConstants.responseApproved,
          approvedBy: 'AI 채택',
          approvedAt: now,
          adoptionCount: existing.adoptionCount + 1,
          usageCount: existing.usageCount + 1,
          lastUsedAt: now,
          updatedAt: now,
        ),
      );
      await _resolveVoc(voc);
      return true;
    }

    aiVm.clearResults();
    await aiVm.searchSimilarVocs('${voc.title} ${voc.content}');
    final answer = await aiVm.generateAnswer(voc.title, voc.content);
    final text = answer?.answer.trim() ?? '';

    if (text.isEmpty) {
      throw StateError(aiVm.error ?? 'AI 답변이 비어 있습니다.');
    }
    if (answer != null && answer.confidence <= 0.25 && answer.referencedCases.isEmpty) {
      throw StateError('AI 답변 근거가 부족해 자동 등록하지 않았습니다.');
    }

    final referenceIds = aiVm.similarVocs
        .map((item) => item.knowledgeBase.vocId)
        .whereType<String>()
        .toSet()
        .toList();
    final now = DateTime.now();
    await _vocRepository.createResponse(
      ResponseEntity(
        id: _uuid.v4(),
        vocId: voc.id,
        content: text,
        status: AppConstants.responseApproved,
        aiGenerated: true,
        confidenceScore: answer?.confidence,
        referencedVocIds: referenceIds,
        approvedBy: 'AI 채택',
        approvedAt: now,
        adoptionCount: 1,
        usageCount: 1,
        lastUsedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _resolveVoc(voc);
    return false;
  }

  Future<void> _resolveVoc(VocEntity voc) async {
    if (voc.status == AppConstants.vocStatusResolved) return;
    await _vocRepository.updateVoc(
      voc.copyWith(
        status: AppConstants.vocStatusResolved,
        updatedAt: DateTime.now(),
      ),
    );
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', '');
}
