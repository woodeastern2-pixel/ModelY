import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/offline_search_index.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/data/services/offline_query_plan.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';

const attendeeQuestion = '진행권 부여 방법 이전에 진행권 부여 방법을 다음과 같이 안내 받았습니다. '
    '1. 진행권 부여방법: [참석자] 메뉴에서 해당 참석자를 클릭하신 후, [더보기] 버튼을 통해 '
    '진행권을 부여하실 수 있습니다. 다만 [참석자] 메뉴는 위치를 제가 못찾는 듯 합니다. '
    '혹시 어떤 경로로 들어가야하는지 알 수 있을까요?';

KnowledgeBaseEntity source(String id, String title, String answer,
    {String project = 'Brity Meeting'}) => KnowledgeBaseEntity(
    id: id, question: title, answer: answer, category: '시스템매뉴얼',
    project: project, customer: id, resolvedAt: DateTime(2026), createdAt: DateTime(2026));

void main() {
  final service = LocalAnswerService();
  test('note formatting and retention do not retrieve unrelated Drive controls', () {
    final index = OfflineSearchIndex();
    index.put(source('drive', 'Brity Drive 전용 기능',
        '공유, 링크 복사, 버전 이력, 웹 뷰, 실행 상태 초기화 기능을 제공합니다.',
        project: 'Brity Drive'));
    index.put(source('note', 'Brity Messenger 쪽지 보관 기간',
        '쪽지 보관 기간은 관리자 정책을 확인합니다.', project: 'Brity Messenger'));
    const query = '쪽지 복사 시 서식 초기화 안녕하세요 쪽지 전송 후 쪽지 내용을 복사하면 '
        '색깔이 들어있는 글자가 초기화가 되어 불편합니다. 복사 시 글자색, 진하게 등 서식이 '
        '같이 복사될 수 있도록 해주시면 감사하겠습니다. 추가로 질문이 있습니다. '
        '보낸 쪽지함과 받은 쪽지함은 보관 일수가 어떻게 되는지 궁금합니다.';
    final refs = index.search(query);
    expect(refs.map((r) => r.knowledgeBase.id), isNot(contains('drive')));
    expect(refs.map((r) => r.knowledgeBase.id), contains('note'));
    expect(index.lastQueries.length, lessThanOrEqualTo(4));
    expect(index.lastTotalCandidates, lessThanOrEqualTo(512));
  });

  test('current question is separated from the quoted previous instructions', () {
    final plan = OfflineQueryPlan.from(attendeeQuestion);
    expect(plan.focus, '참석자 메뉴 위치');
    expect(plan.navigation, isTrue);
    expect(service.retrievalQueries(attendeeQuestion).length, lessThanOrEqualTo(4));
  });

  test('long request retries and retrieves original-only location with no QA', () {
    final index = OfflineSearchIndex();
    index.put(source('raw-location', '참석자 목록',
        '회의 화면 하단 도구 모음에서 참가자 버튼을 선택하면 참석자 패널이 열립니다.'));
    // Same keyword in the wrong product must not replace the meeting answer.
    index.put(source('mail', '메일 일정 참석자',
        '메인 메뉴의 일정에서 참석자 버튼을 클릭합니다.', project: 'Brity Mail'));
    final refs = index.search(attendeeQuestion);
    expect(index.lastQueries.length, greaterThan(1));
    expect(index.lastQueries.length, lessThanOrEqualTo(4));
    expect(index.lastTotalCandidates, lessThanOrEqualTo(512));
    expect(service.canAnswer(attendeeQuestion, refs), isTrue);
    expect(refs.first.knowledgeBase.id, 'raw-location');
    final answer = service.answerForQuery(attendeeQuestion, refs);
    expect(answer, contains('하단 도구 모음'));
    expect(answer, isNot(contains('더보기')));
    expect(answer, isNot(contains('메일 일정')));
  });

  test('related explanation is shown without inventing a missing location', () {
    final index = OfflineSearchIndex();
    index.put(source('roles', '주최자 권한 넘기기',
        '참석자 메뉴에서 다른 참석자에게 주최자나 진행 권한을 부여합니다.'));
    final refs = index.search(attendeeQuestion);
    expect(service.canAnswer(attendeeQuestion, refs), isTrue);
    final answer = service.answerForQuery(attendeeQuestion, refs);
    expect(answer, contains('확인되지 않은 부분'));
    expect(answer, contains('확인된 관련 설명'));
    expect(answer, isNot(contains('하단')));
    expect(answer, isNot(contains('더보기')));
    expect(index.lastQueries.length, greaterThan(1));
  });

  test('participant mention in unrelated controls is not navigation evidence', () {
    final index = OfflineSearchIndex();
    index.put(source('camera', '카메라와 마이크',
        '회의 하단 제어 영역에서 카메라를 켭니다. 참석자의 음소거를 관리할 수 있습니다.'));
    final refs = index.search(attendeeQuestion);
    expect(service.canAnswer(attendeeQuestion, refs), isFalse);
  });

  test('an unrelated query and unapproved question never become evidence', () {
    final index = OfflineSearchIndex();
    index.put(source('raw-meeting', '참석자 메뉴', '참석자 패널에서 역할을 확인합니다.'));
    index.put(source('registered-voc-question', '급여 지급일', '급여는 매월 10일인가요?'));
    final refs = index.search('급여 지급일');
    expect(service.canAnswer('급여 지급일', refs), isFalse);
  });

  test('explicit product and platform survive focused retries', () {
    final index = OfflineSearchIndex();
    index.put(source('pc', 'Brity Meeting PC 참석자 메뉴',
        '회의 화면 하단 참석자 버튼을 누릅니다.'));
    final query = '미팅 모바일에서 예전에 안내를 받았습니다. 다만 [참석자] 메뉴는 어디에 있나요?';
    expect(service.canAnswer(query, index.search(query)), isFalse);
  });
}

