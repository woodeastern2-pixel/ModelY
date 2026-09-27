import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 28);
  final meeting = KnowledgeBaseEntity(
    id: 'meeting',
    question: 'Brity Meeting 접속 방법',
    answer: '회의 목록에서 참가를 선택합니다.',
    category: '시스템매뉴얼',
    resolvedAt: now,
    createdAt: now,
  );
  final messenger = KnowledgeBaseEntity(
    id: 'messenger',
    question: 'Brity Messenger 알림 설정',
    answer: '설정에서 알림을 선택합니다.',
    category: '시스템매뉴얼',
    resolvedAt: now,
    createdAt: now,
  );

  test('Korean alias retrieves an English titled manual without a model', () {
    final results = LocalAnswerService().rank(
      '미팅 접속 방법', [messenger, meeting]);
    expect(results.first.knowledgeBase.id, 'meeting');
    expect(LocalAnswerService().answer(results), contains('회의 목록에서 참가'));
    expect(LocalAnswerService().answer(results), contains('Brity Meeting 접속 방법'));
  });

  test('unrelated question never invents an answer', () {
    final results = LocalAnswerService().rank('급여 지급일', [meeting]);
    expect(results, isEmpty);
    expect(LocalAnswerService().answer(results), contains('근거: 없음'));
  });

  test('answer only copies one stored source', () {
    final results = LocalAnswerService().rank('메신저 알림 설정', [meeting, messenger]);
    final answer = LocalAnswerService().answer(results);
    expect(answer, contains('설정에서 알림을 선택합니다.'));
    expect(answer, isNot(contains('회의 목록에서 참가')));
  });
}
