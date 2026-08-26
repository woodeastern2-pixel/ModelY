import 'dart:async';

import 'package:ai_voc_assistant/core/constants/app_constants.dart';
import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:ai_voc_assistant/domain/entities/response_entity.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:ai_voc_assistant/domain/repositories/voc_repository.dart';
import 'package:ai_voc_assistant/presentation/viewmodels/voc_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simultaneous identical registration creates only one VOC', () async {
    final repository = _VocRepository();
    final viewModel = VocViewModel(repository);

    final first = viewModel.createVoc(
      title: '중복 등록 방지',
      content: '동일한 등록 요청이 동시에 실행됩니다.',
      category: '기능문의',
      priority: 'MEDIUM',
    );
    final second = viewModel.createVoc(
      title: '중복 등록 방지',
      content: '동일한 등록 요청이 동시에 실행됩니다.',
      category: '기능문의',
      priority: 'MEDIUM',
    );

    await Future.wait([first, second]);

    expect(repository.createCount, 1);
    expect(repository.vocs, hasLength(1));
  });

  test('bulk AI resolve processes every pending VOC with one AI answer each', () async {
    final now = DateTime(2026, 8, 14);
    final repository = _VocRepository(vocs: _pendingVocs(3), responses: [
      ResponseEntity(
        id: 'existing-ai-new',
        vocId: 'voc-0',
        content: '기존 AI 답변',
        status: AppConstants.responseDraft,
        aiGenerated: true,
        createdAt: now,
        updatedAt: now,
      ),
      ResponseEntity(
        id: 'existing-ai-old',
        vocId: 'voc-0',
        content: '중복된 이전 AI 답변',
        status: AppConstants.responseDraft,
        aiGenerated: true,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
    final viewModel = VocViewModel(repository);
    await viewModel.loadVocs();

    final result = await viewModel.autoResolvePendingWithAi(
      prepareSimilarCases: (_) async {},
      generateAnswer: (_, __) async => const AiAnswerResult(
        answer: '확인 후 조치했습니다.',
        confidence: 0.9,
        referencedCases: [],
        notes: '',
      ),
    );

    expect(result.targetCount, 3);
    expect(result.generatedCount, 2);
    expect(result.reusedAiCount, 1);
    expect(result.resolvedCount, 3);
    expect(
      repository.vocs
          .where((voc) => voc.status == AppConstants.vocStatusResolved),
      hasLength(3),
    );
    for (final voc in repository.vocs) {
      expect(
        repository.responses.where(
          (response) => response.vocId == voc.id && response.aiGenerated,
        ),
        hasLength(1),
      );
    }
  });

  test('bulk AI resolve stop request prevents saving the in-flight answer',
      () async {
    final repository = _VocRepository(vocs: _pendingVocs(1));
    final viewModel = VocViewModel(repository);
    final answerStarted = Completer<void>();
    final finishAnswer = Completer<AiAnswerResult?>();
    await viewModel.loadVocs();

    final operation = viewModel.autoResolvePendingWithAi(
      prepareSimilarCases: (_) async {},
      generateAnswer: (_, __) {
        answerStarted.complete();
        return finishAnswer.future;
      },
    );
    await answerStarted.future;
    viewModel.stopBulkAutoResolve();
    finishAnswer.complete(const AiAnswerResult(
      answer: '저장되면 안 되는 답변',
      confidence: 0.9,
      referencedCases: [],
      notes: '',
    ));

    final result = await operation;

    expect(result.stopped, isTrue);
    expect(result.generatedCount, 0);
    expect(repository.responses, isEmpty);
    expect(repository.vocs.single.status, AppConstants.vocStatusOpen);
  });
}

List<VocEntity> _pendingVocs(int count) {
  final now = DateTime(2026, 8, 14);
  return List.generate(
    count,
    (index) => VocEntity(
      id: 'voc-$index',
      title: '미처리 VOC $index',
      content: '처리가 필요한 테스트 문의 내용입니다.',
      category: '기능문의',
      customer: '고객사',
      project: 'PROJECT | VOC | $index',
      priority: 'MEDIUM',
      status: AppConstants.vocStatusOpen,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

class _VocRepository implements VocRepository {
  final List<VocEntity> vocs;
  final List<ResponseEntity> responses;
  int createCount = 0;

  _VocRepository({List<VocEntity>? vocs, List<ResponseEntity>? responses})
      : vocs = vocs ?? [], responses = responses ?? [];

  @override
  Future<List<VocEntity>> getAllVocs() async => List.of(vocs);

  @override
  Future<VocEntity> createVoc(VocEntity voc) async {
    createCount += 1;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    vocs.add(voc);
    return voc;
  }

  @override
  Future<List<ResponseEntity>> getResponsesByVocId(String vocId) async =>
      responses.where((response) => response.vocId == vocId).toList();

  @override
  Future<ResponseEntity> createResponse(ResponseEntity response) async {
    responses.add(response);
    return response;
  }

  @override
  Future<ResponseEntity> updateResponse(ResponseEntity response) async {
    final index = responses.indexWhere((item) => item.id == response.id);
    if (index >= 0) responses[index] = response;
    return response;
  }

  @override
  Future<void> deleteResponse(String id) async {
    responses.removeWhere((response) => response.id == id);
  }

  @override
  Future<VocEntity> updateVoc(VocEntity voc) async {
    final index = vocs.indexWhere((item) => item.id == voc.id);
    if (index >= 0) vocs[index] = voc;
    return voc;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
