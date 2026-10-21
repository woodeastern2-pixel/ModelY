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
}
