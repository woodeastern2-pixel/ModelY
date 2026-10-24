import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/answer_evidence_selector.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';

void main() {
  test('four question parts retain separate sources and final restrictions', () {
    const features=['알림 설정','메시지 예약','파일 복원','비밀번호 변경'];
    final sources=[for(var i=0;i<features.length;i++) SimilarVocResult(
      knowledgeBase:KnowledgeBaseEntity(id:'source-$i',question:features[i],
        answer:'${features[i]} 방법: 메뉴를 선택합니다.\n\n주의: 관리자 권한이 없으면 ${features[i]} 작업을 할 수 없습니다.',
        category:'시스템매뉴얼',createdAt:DateTime(2026),resolvedAt:DateTime(2026)),similarityScore:.9)];
    final selected=AnswerEvidenceSelector.select(features.join(' 그리고 '),sources);
    expect(selected.map((r)=>r.knowledgeBase.id).toSet(),{'source-0','source-1','source-2','source-3'});
    expect(selected.every((r)=>r.knowledgeBase.answer.endsWith('작업을 할 수 없습니다.')),isTrue);
    final budget=AnswerEvidenceSelector.select(features.join(' 그리고 '),sources,maxCharacters:180);
    expect(budget.length,lessThan(selected.length));
    expect(budget.every((r)=>r.knowledgeBase.answer.endsWith('작업을 할 수 없습니다.')),isTrue);
  });
}
