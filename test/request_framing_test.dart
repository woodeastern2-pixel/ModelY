import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/data/services/offline_query_plan.dart';
import 'package:ai_voc_assistant/data/services/offline_search_index.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';

void main() {
  final service = LocalAnswerService();
  const frames = [
    '에 어려움이 있습니다. 도와주세요',
    '에 어려움을 겪고 있습니다. 도움을 부탁드립니다.',
    '이 어려워요. 안내 부탁드립니다.',
    ' 방법을 잘 모르겠어요. 설명해 주세요.',
    '에 도움이 필요합니다. 문의드립니다.',
  ];
  for (final core in ['미팅개설', '휴지통 복원', '설문 대상자 지정']) {
    test('request wording preserves the search intent: $core', () {
      final expected = service.queryIndexKeys(core);
      for (final frame in frames) {
        expect(service.queryIndexKeys('$core$frame'), expected,
            reason: '$core$frame');
        expect(service.retrievalQueries('$core$frame').length,
            lessThanOrEqualTo(4));
      }
    });
  }
  test('technical constraints and unknown identifiers are never discarded', () {
    const core = '미팅 모바일 v8.5.5 외부 참석자 1000명 권한 없이 QX-917';
    final question = '$core 에 어려움이 있습니다. 도와주세요';
    final search = OfflineQueryPlan.searchText(question);
    expect(search, contains(core));
    expect(OfflineQueryPlan.versions(search), ['8.5.5']);
    expect(OfflineQueryPlan.quantities(search), ['1000명']);
    expect(OfflineQueryPlan.conditions(search), containsAll(['외부 참석자', '권한 없이']));
    expect(OfflineQueryPlan.from(question).request, question);
    expect(service.queryIndexKeys(question), service.queryIndexKeys(core));
  });
  test('help wording retrieves authored evidence but cannot invent it', () {
    final index = OfflineSearchIndex();
    index.put(KnowledgeBaseEntity(id: 'raw-meeting', question: '미팅 사용하기',
        answer: 'Brity Meeting 권한이 있는 경우 메뉴가 제공됩니다. '
            '즉시시작을 클릭하면 회의가 개설됩니다.',
        category: '시스템매뉴얼', project: 'Brity Meeting',
        resolvedAt: DateTime(2026), createdAt: DateTime(2026)));
    const query = '미팅개설 미팅개설에 어려움이 있습니다. 도와주세요';
    final refs = index.search(query);
    expect(service.canAnswer(query, refs), isTrue);
    final answer = service.answerForQuery(query, refs);
    expect(answer, contains('즉시시작'));
    expect(answer, contains('권한'));
    expect(answer, contains('원인은 자료만으로'));
    for (final unrelated in [
      '급여 지급일에 어려움이 있습니다. 도와주세요',
      '미팅에 어려움이 있습니다. 도와주세요',
      '도와주세요',
    ]) {
      expect(service.canAnswer(unrelated, index.search(unrelated)), isFalse,
          reason: unrelated);
    }
    expect(index.lastTotalCandidates, lessThanOrEqualTo(512));
  });
}
