import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = LocalAnswerService();
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

  test('unrelated feature and saved clarification never become answer evidence', () {
    final unrelated = KnowledgeBaseEntity(id: 'minutes',
      question: 'Brity Copilot 회의록 초안', answer: '회의 내용을 기반으로 회의록 초안을 생성합니다.',
      category: '시스템매뉴얼', resolvedAt: now, createdAt: now);
    final refs = [SimilarVocResult(knowledgeBase: unrelated, similarityScore: 0.99)];
    expect(service.canAnswer('Copilot으로 메일 답장 초안 작성', refs), isFalse);
    expect(service.answerReferences(refs, query: 'Copilot으로 메일 답장 초안 작성'), isEmpty);
    final saved = KnowledgeBaseEntity(id: 'saved', question: '카메라 필터 알림',
      answer: service.clarificationDraft('카메라 필터 알림', '계속 뜹니다'),
      category: '문의', resolvedAt: now, createdAt: now);
    expect(service.isAnswerSource(saved), isFalse);
    expect(service.focusedEvidence('진행권 부여 방법\n참석자 메뉴는 어디에 있나요?', meeting), isFalse);
  });

  test('Korean alias retrieves an English titled manual without a model', () {
    final results = LocalAnswerService().rank(
      '미팅 접속 방법', [messenger, meeting]);
    expect(results.first.knowledgeBase.id, 'meeting');
    expect(LocalAnswerService().answer(results), contains('회의 목록에서 참가'));
    expect(LocalAnswerService().answer(results), contains('Brity Meeting 접속 방법'));
  });

  test('a raw registered question cannot be echoed as an answer', () {
    final question = KnowledgeBaseEntity(
      id: 'registered-voc-1', question: '진행권 부여 방법',
      answer: '참석자 메뉴는 어디에 있나요?', category: '문의',
      resolvedAt: now, createdAt: now);
    final service = LocalAnswerService();
    final refs = [SimilarVocResult(knowledgeBase: question, similarityScore: 1)];
    expect(service.answer(refs), contains('근거: 없음'));
    expect(service.answer(refs), isNot(contains('참석자 메뉴는 어디에 있나요')));
    expect(service.canAnswer('진행권 부여 방법', refs), isFalse);
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

  test('a partial match is not presented as an overall report', () {
    final service = LocalAnswerService();
    final results = service.rank('미팅 접속 방법', [meeting]);
    expect(service.answerForQuery('전체 VOC 보고서', results), contains('집계가 필요합니다'));
    expect(service.answerForQuery('전체 VOC 보고서', results), isNot(contains('회의 목록에서 참가')));
  });
  test('a product report feature is not mistaken for VOC statistics', () {
    expect(service.needsWholeDataset('Copilot · 보고서 초안 처음 이용하는 절차\n보고서 작성을 문의한 직원입니다. 보고서 초안을 만들고 싶습니다.'), isFalse);
    expect(service.needsWholeDataset('전체 VOC 보고서'), isTrue);
  });

  test('long context does not echo each sentence as missing evidence', () {
    const query = '메신저 알림 설정\n상황을 확인하고 있습니다\n직원들이 도움을 요청했습니다\n이 부분도 살펴봐 주세요';
    final refs = [SimilarVocResult(knowledgeBase: messenger, similarityScore: 1)];
    final answer = service.answerForQuery(query, refs);
    expect(answer, isNot(contains('에 답할 근거가 부족')));
    expect(answer, contains('설정에서 알림'));
  });

  test('conversation layout change is not answered with member expulsion steps', () {
    const query = '대화창의 표시\n상대방과 내가 모두 왼쪽에 표시되니 불편합니다. '
        '나는 오른쪽에 표시되도록 변경해주시길 요청드립니다.';
    final entry = KnowledgeBaseEntity(id: 'layout', question: '대화창',
      answer: '대화방 목록에서 대화방을 선택하면 오른쪽에 대화창이 보입니다.\n'
          '리더가 선택되었을 경우 멤버 내보내기는 할 수 없습니다.',
      category: '시스템매뉴얼', resolvedAt: now, createdAt: now);
    final answer = service.answerForQuery(query,
        [SimilarVocResult(knowledgeBase: entry, similarityScore: 1)]);
    expect(answer, contains('개선 요청'));
    expect(answer, contains('변경 가능 여부'));
    expect(answer, isNot(contains('멤버 내보내기')));
    expect(answer, isNot(contains('설정에서 변경할 수')));
  });

}


