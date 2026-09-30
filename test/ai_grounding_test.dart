import 'package:ai_voc_assistant/data/services/ai_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('low-similarity evidence does not trigger speculative AI generation', () async {
    final service = AiService();
    final now = DateTime(2026, 8, 18);
    final result = await service.generateAnswer(
      '외부 메신저 연동 문의',
      '등록되지 않은 외부 메신저 기능을 사용할 수 있나요?',
      [
        SimilarVocResult(
          knowledgeBase: KnowledgeBaseEntity(
            id: 'case-low',
            question: ' unrelated 기능 문의',
            answer: '다른 기능에 대한 기존 답변입니다.',
            category: '기능문의',
            resolvedAt: now,
            createdAt: now,
          ),
          similarityScore: 0.31,
        ),
      ],
    );

    expect(result.confidence, lessThan(0.4));
    expect(result.referencedCases, isEmpty);
    expect(result.answer, contains('정확한 안내가 어렵습니다'));
  });

  test('review citations use validated stable IDs and never infer all sources', () {
    final service = AiService();
    final now = DateTime(2026, 9, 30);
    final source = SimilarVocResult(knowledgeBase: KnowledgeBaseEntity(
      id: 'stable-source', question: '동일한 제목', answer: '설정에서 알림을 선택합니다.',
      category: '시스템매뉴얼', resolvedAt: now, createdAt: now), similarityScore: 0.9);
    final cited = service.parseReviewDraft(
      '{"answer":"안내", "referenced_case_ids":["stable-source","unknown","stable-source"], "referenced_cases":["다른 제목"]}', [source]);
    expect(cited.referencedCaseIds, ['stable-source']);
    expect(cited.referencedCases, ['동일한 제목']);
    for (final raw in ['{"answer":"안내"}', '일반 텍스트 답변',
      '{"answer":"안내","referenced_case_ids":["unknown"]}',
      '{"answer":"안내","referenced_cases":["동일한 제목"]}',
      '{"answer":"안내","referenced_case_ids":"invalid"}']) {
      expect(service.parseReviewDraft(raw, [source]).referencedCaseIds, isEmpty);
      expect(service.parseReviewDraft(raw, [source]).referencedCases, isEmpty);
    }
    expect(AiPrompts.answerGenerationUser('질문', '내용', [source]), contains('자료 ID: stable-source'));
  });

  test('answer prompt explicitly prohibits unsupported UI and integration claims', () {
    expect(AiPrompts.answerGenerationSystem, contains('메뉴명'));
    expect(AiPrompts.answerGenerationSystem, contains('외부 서비스'));
    expect(AiPrompts.answerGenerationSystem, contains('정확한 안내가 어렵습니다'));
    expect(AiPrompts.answerGenerationSystem, contains('서로 다른 사례'));
  });
}

