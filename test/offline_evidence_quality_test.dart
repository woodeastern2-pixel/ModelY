import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/data/services/offline_search_index.dart';
import 'package:ai_voc_assistant/data/services/offline_query_plan.dart';
import 'package:ai_voc_assistant/data/services/offline_answer_composer.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';

KnowledgeBaseEntity record(String id, String title, String body,
    {String project = 'Brity Drive', String? source}) => KnowledgeBaseEntity(
  id: id, question: title, answer: body, category: '시스템매뉴얼',
  project: project, customer: source ?? id,
  resolvedAt: DateTime(2026), createdAt: DateTime(2026));

void main() {
  final service = LocalAnswerService();
  test('English button is not mistaken for a discourse pivot', () {
    const query = 'Where is the participant button?';
    expect(OfflineQueryPlan.from(query).focus, query);
  });

  test('known different version is excluded before candidate limits', () {
    final index = OfflineSearchIndex();
    for (var i = 0; i < 100; i++) {
      index.put(record('old-$i', '드라이브 v1.0 파일 복원', '파일을 선택하고 복원합니다.'));
    }
    index.put(record('new', '드라이브 v2.0 파일 복원', '휴지통에서 파일을 선택하고 복원합니다.'));
    const query = '드라이브 v2.0 파일 복원 방법';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    expect(refs.every((r) => r.knowledgeBase.id == 'new'), isTrue);
    expect(service.answerForQuery(query, refs), contains('휴지통'));
  });

  test('confirmed matching version outranks an unversioned duplicate', () {
    final index = OfflineSearchIndex()
      ..put(record('a-unknown', '파일 복원', '파일을 선택하고 복원합니다.'))
      ..put(record('z-confirmed', '드라이브 v2.0 파일 복원', '파일을 선택하고 복원합니다.'));
    const query = '드라이브 v2.0 파일 복원 방법';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    expect(service.answerReferences(refs, query: query).first.knowledgeBase.id, 'z-confirmed');
    expect(service.evidenceGap(query, service.answerReferences(refs, query: query)), isEmpty);
  });

  test('unknown requested version is disclosed while showing related guidance', () {
    final index = OfflineSearchIndex()..put(record('restore', '파일 복원',
        '휴지통에서 파일을 선택하고 복원 버튼을 클릭합니다.'));
    const query = '드라이브 8.5.5 파일 복원 방법';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    expect(service.answerForQuery(query, refs), contains('버전 8.5.5'));
    expect(service.answerForQuery(query, refs), contains('확인되지 않은 부분'));
  });

  test('unverified numeric condition does not silently disappear in retries', () {
    final index = OfflineSearchIndex()..put(record('survey', '설문 대상자 지정',
        '설문 대상자 지정은 최대 500명까지 가능합니다.', project: 'Survey'));
    const query = '설문 대상자 1000명 지정 방법';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    final answer = service.answerForQuery(query, refs);
    expect(answer, contains('1000명 조건'));
    expect(answer, contains('500명'));
    expect(answer, isNot(contains('1000명까지 가능')));
  });

  test('irreversible deletion condition is not replaced by ordinary restore steps', () {
    final index = OfflineSearchIndex()..put(record('restore', '파일 복원',
        '휴지통에서 파일을 선택하고 복원 버튼을 클릭합니다.'));
    const query = '드라이브 영구 삭제 파일 복원 방법';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    expect(service.answerForQuery(query, refs), contains('「영구 삭제」 조건'));
    expect(service.answerForQuery(query, refs), contains('확정 안내는 아닙니다'));
  });

  test('independent question parts retrieve distinct sources without merging procedures', () {
    final index = OfflineSearchIndex()
      ..put(record('restore', '파일 복원', '휴지통에서 파일을 선택하고 복원 버튼을 클릭합니다.'))
      ..put(record('retention', '보관 기간', '보관 기간은 30일입니다.'));
    const query = '드라이브 파일 복원 방법 그리고 보관 기간';
    final refs = index.search(query);
    final answer = service.answerForQuery(query, refs);
    expect(answer, contains('복원 버튼'));
    expect(answer, contains('30일'));
    expect(answer, contains('근거: restore'));
    expect(answer, contains('근거: retention'));
    expect(service.evidenceGap(query, service.answerReferences(refs, query: query)), isEmpty);
  });

  test('unanswered question part is explicitly identified', () {
    final index = OfflineSearchIndex()..put(record('restore', '파일 복원',
        '휴지통에서 파일을 선택하고 복원 버튼을 클릭합니다.'));
    const query = '드라이브 파일 복원 방법 그리고 보관 기간';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    expect(service.answerForQuery(query, refs), contains('「보관 기간」에 답할 근거가 부족'));
  });

  test('inconsistent limits from different sources are disclosed', () {
    final index = OfflineSearchIndex()
      ..put(record('manual-a', '메일 첨부 최대 용량', '첨부 가능한 최대 용량은 50MB입니다.', project: 'Brity Mail'))
      ..put(record('manual-b', '메일 첨부 최대 용량', '첨부 가능한 최대 용량은 100MB입니다.', project: 'Brity Mail'));
    const query = '메일 첨부 최대 용량';
    final answer = service.answerForQuery(query, index.search(query));
    expect(answer, contains('서로 다른 안내'));
    expect(answer, contains('50MB'));
    expect(answer, contains('100MB'));
    expect(answer, contains('근거: manual-a'));
    expect(answer, contains('근거: manual-b'));
  });

  test('a location belonging to another control is not accepted as the requested location', () {
    final entry = record('camera', '참석자 메뉴',
        '참석자 메뉴에서 카메라 버튼은 하단에 표시됩니다.', project: 'Brity Meeting');
    expect(service.hasNavigationLocation('참석자 메뉴 위치', entry), isFalse);
  });

  test('duplicate raw windows do not crowd a precise source out of final candidates', () {
    final index = OfflineSearchIndex();
    for (var i = 0; i < 100; i++) {
      index.put(record('raw-duplicate-$i', '참석자 메뉴 · 원문 구간 $i',
          '참석자 메뉴에서 역할을 변경합니다.', project: 'Brity Meeting', source: 'same-section'));
    }
    index.put(record('raw-location', '참석자 메뉴',
        '회의 화면 하단 도구 모음에서 참가자 버튼을 선택하면 참석자 패널이 열립니다.', project: 'Brity Meeting'));
    const query = '미팅 참석자 메뉴 위치';
    final refs = index.search(query);
    expect(refs.any((r) => r.knowledgeBase.id == 'raw-location'), isTrue);
    expect(service.answerForQuery(query, refs), contains('하단 도구 모음'));
    expect(index.lastTotalCandidates, lessThanOrEqualTo(512));
  });

  test('a table of contents cannot outrank the explicit answer', () {
    final index = OfflineSearchIndex()
      ..put(record('contents', '영구 삭제 파일 복원',
        '삭제한 파일 복원하기\n복원 폴더 선택하는 경우\n영구 삭제 후 복원하기\n휴지통 화면'))
      ..put(record('answer', '영구 삭제 파일 복원',
        '영구 삭제한 파일은 복원이 불가능합니다.'));
    const query = '드라이브 영구 삭제 파일 복원 방법';
    final answer = service.answerForQuery(query, index.search(query));
    expect(answer, contains('복원이 불가능'));
    expect(answer, isNot(contains('선택하는 경우')));
    expect(answer, isNot(contains('다음 순서')));
  });

  test('concise multiline facts remain searchable', () {
    final index = OfflineSearchIndex()..put(record('facts', '파일 보관',
        '보관 기간: 30일\n복원 대상: 삭제 파일\n지원 제품: 드라이브'));
    const query = '드라이브 보관 기간';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    expect(service.answerForQuery(query, refs), contains('30일'));
  });

  test('figure captions do not become numbered instructions', () {
    final answer = OfflineAnswerComposer().compose('설문 지정 방법', [
      const OfflineAnswerFragment('Click\n①지정함Click\n을클릭하여대상자를지정합니다.\n2. 을클릭하여조직도에서지정합니다.\n참여자 지정을 클릭합니다.', 'manual')]);
    expect(answer, isNot(contains('1. Click')));
    expect(answer, isNot(contains('①지정함Click')));
    expect(answer, isNot(contains('을클릭하여')));
    expect(answer, contains('1. 참여자 지정을 클릭합니다.'));
  });

  test('required permissions are presented before action steps', () {
    final answer = OfflineAnswerComposer().compose('복원 방법', [
      const OfflineAnswerFragment('파일을 선택합니다. 복원을 클릭합니다.\n관리자만 복원할 수 있습니다.', 'manual')]);
    expect(answer.indexOf('관리자만'), lessThan(answer.indexOf('1. 파일')));
  });
}
