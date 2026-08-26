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

  test('answer prompt explicitly prohibits unsupported UI and integration claims', () {
    expect(AiPrompts.answerGenerationSystem, contains('메뉴명'));
    expect(AiPrompts.answerGenerationSystem, contains('외부 서비스'));
    expect(AiPrompts.answerGenerationSystem, contains('정확한 안내가 어렵습니다'));
    expect(AiPrompts.answerGenerationSystem, contains('서로 다른 사례'));
  });
}
