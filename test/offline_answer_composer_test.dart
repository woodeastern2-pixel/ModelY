import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/offline_answer_composer.dart';

void main() {
  final composer = OfflineAnswerComposer();
  test('procedure is composed into ordered steps with restrictions and sources', () {
    final answer = composer.compose('일정 등록 어떻게 하나요', [
      const OfflineAnswerFragment(
        '메인 메뉴에서 일정을 클릭하세요. 일정 등록을 선택하세요.\n'
        '제목과 날짜를 입력하세요. 저장을 누르세요.\n'
        '회의실 예약은 회사 정책에 따라 제공되지 않을 수 있습니다.\n'
        '첨부 가능한 최대 용량은 50MB 입니다.\n[출처] 일정 5.2', '사용자 매뉴얼'),
    ]);
    expect(answer, contains('1. 메인 메뉴에서 일정을 클릭하세요.\n2. 일정 등록을 선택하세요.'));
    expect(answer, contains('3. 제목과 날짜를 입력하세요.\n4. 저장을 누르세요.'));
    expect(answer, contains('최대 용량은 50MB'));
    expect(answer, contains('회사 정책에 따라 제공되지 않을 수 있습니다'));
    expect(answer, contains('근거: 사용자 매뉴얼'));
    expect(answer, contains('[출처] 일정 5.2'));
  });
  test('conditions are never separated from conditional actions or negations', () {
    final answer = composer.compose('복원 방법', [
      const OfflineAnswerFragment('관리자인 경우에만 복원 버튼을 누르세요.\n'
          '영구 삭제된 파일은 복원할 수 없습니다.', 'v2'),
      const OfflineAnswerFragment('영구 삭제된 파일은 복원할 수 없습니다.', 'v2'),
    ]);
    expect(answer, contains('관리자인 경우에만 복원 버튼을 누르세요.'));
    expect('영구 삭제된 파일'.allMatches(answer).length, 1);
    expect(answer, isNot(contains('1. 복원 버튼')));
  });
  test('wrapped English restrictions keep their object in the same sentence', () {
    final answer = composer.compose('메신저 제거 대화 기록', [
      const OfflineAnswerFragment('If you reinstall, you can view only conversations stored on the\nserver.', 'PDF'),
    ]);
    expect(answer, contains('only conversations stored on the server.'));
  });
  test('alternative meeting buttons are not consecutive required steps', () {
    final answer = composer.compose('미팅 개설 방법', [
      const OfflineAnswerFragment('메인 메뉴에서 미팅을 클릭하세요.\n예약하기를 클릭하면 예약 사이트로 이동합니다.\n즉시시작을 클릭하면 회의가 개설됩니다.\n참여를 클릭하면 참석합니다.\nMeeting 권한이 있는 경우 메뉴가 제공됩니다.', '매뉴얼')]);
    expect(answer, contains('선택한 기능에 따른 동작'));
    expect(answer, isNot(contains('2. 예약하기')));
    expect(answer.indexOf('권한'), lessThan(answer.indexOf('1. 메인')));
  });
  test('a factual question does not turn a limit into a procedure', () {
    final answer = composer.compose('첨부 최대 용량은?', [
      const OfflineAnswerFragment('첨부 가능한 최대 용량은 50MB 입니다.', '매뉴얼'),
    ]);
    expect(answer, contains('50MB'));
    expect(answer, isNot(contains('다음 순서')));
  });
}
