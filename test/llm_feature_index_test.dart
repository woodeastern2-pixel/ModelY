import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/data/services/offline_search_index.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached records learn new bilingual feature concepts without losing data', () {
    final index = OfflineSearchIndex();
    final now = DateTime(2026, 10, 21);
    index.put(KnowledgeBaseEntity(
      id: 'existing-manual', question: 'Brity Messenger Desktop 알림',
      answer: 'Options > Notification. Do Not Disturb Settings turn off alarms.',
      category: '시스템매뉴얼', project: 'Brity Messenger',
      resolvedAt: now, createdAt: now,
    ), keys: ['c:messenger', 'c:desktop', 'c:notification', 'c:settings']);
    final result = index.search('Brity Messenger 방해 금지 설정');
    expect(result.map((r) => r.knowledgeBase.id), contains('existing-manual'));
    expect(result.first.knowledgeBase.answer, contains('Do Not Disturb Settings'));
  });
  test('approved answer summary ignores formatting instructions and unrelated manuals', () {
    final now = DateTime(2026, 10, 21);
    KnowledgeBaseEntity entry(String id, String question, String answer) => KnowledgeBaseEntity(
      id: id, question: question, answer: answer, category: '기능문의',
      resolvedAt: now, createdAt: now,
    );
    final entries = [
      entry('approved-voc-notification-response', '브리티 메신저 PC 새 메시지 알림 문의',
        'Options > Notification에서 알림 설정을 확인합니다. 방해 금지 설정을 체크하면 알림이 꺼집니다.'),
      entry('registered-voc-notification', '브리티 메신저 PC 새 메시지 알림 문의', '등록된 VOC 상태: 접수'),
      entry('manual-notification', '브리티 메신저 PC 새 메시지 알림 문의', '요약해 주세요 세 문장 알림 설정 방해 금지'),
      entry('approved-voc-mail-response', '브리티 메일 첨부파일 문의', '메일 첨부파일 제한을 확인합니다.'),
    ];
    final result = LocalAnswerService().rankChatReferences(
      '브리티 메신저 PC 새 메시지 알림 문의의 승인된 답변에서 알림 설정 위치와 방해 금지 확인사항을 세 문장 이내로 요약해 주세요.', entries);
    expect(result.map((r) => r.knowledgeBase.id), ['approved-voc-notification-response']);
    expect(LocalAnswerService().rankChatReferences(
      '알 수 없는 제품의 승인된 답변을 요약해 주세요.', entries), isEmpty);
  });

}
