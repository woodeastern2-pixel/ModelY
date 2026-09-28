import 'package:flutter_test/flutter_test.dart';
import 'package:ai_voc_assistant/data/services/local_answer_service.dart';
import 'package:ai_voc_assistant/data/services/bundled_manual_service.dart';
import 'package:ai_voc_assistant/data/seeds/brity_suite_manual_seed.dart';
import 'package:ai_voc_assistant/domain/entities/knowledge_base_entity.dart';

KnowledgeBaseEntity entry(String id, String title, String body, {String? source}) =>
    KnowledgeBaseEntity(id: id, question: title, answer: body,
        category: '시스템매뉴얼', customer: source,
        resolvedAt: DateTime(2026), createdAt: DateTime(2026));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = LocalAnswerService();
  test('body-only evidence, spaced Korean and translated concepts are retrieved', () {
    final docs = [entry('body', '운영 안내 7장',
        '휴지통에서 삭제한 파일을 선택하고 복원을 누릅니다. 보관 기간이 지난 파일은 복원할 수 없습니다.')];
    final refs = service.rank('휴지통 파일 복구 방법', docs);
    expect(refs.first.knowledgeBase.id, 'body');
    expect(service.canAnswer('휴지통 파일 복구 방법', refs), isTrue);
    expect(service.answerForQuery('휴지통 파일 복구 방법', refs), contains('보관 기간'));
    final english = service.rank('비밀번호 설정', [entry('en', 'User Guide',
        'Open Settings and enter your Password. Only administrators can reset another account.')]);
    expect(english.single.knowledgeBase.id, 'en');
    expect(service.canAnswer('비밀번호 설정', english), isTrue);
    final spaced = service.rank('첨부 파일 다운로드', [entry('space', '운영 가이드',
        '첨부파일을 선택한 다음 다운로드 버튼을 누릅니다.')]);
    expect(service.canAnswer('첨부 파일 다운로드', spaced), isTrue);
  });
  test('a matching title and product never substitute for body evidence', () {
    final refs = service.rank('메신저 비밀번호 복구', [
      entry('wrong', '메신저 비밀번호 복구', '메신저 제품을 소개합니다.'),
      entry('irrelevant', '메신저 소개', '설정 메뉴를 선택합니다.'),
    ]);
    expect(service.canAnswer('메신저 비밀번호 복구', refs), isFalse);
  });
  test('procedural 전체 선택 is not classified as a dataset aggregation', () {
    expect(service.needsWholeDataset('파일 전체 선택 방법'), isFalse);
    expect(service.needsWholeDataset('전체 VOC 보고서'), isTrue);
  });
  test('long evidence preserves restrictions and source without unrelated prose', () {
    final filler = List.filled(90, '다른 화면의 배경 설명입니다.').join(' ');
    final doc = entry('long', '가이드', '$filler\n\n관련 기능 소개\n\n'
        '휴지통 파일 복원: 항목을 선택한 후 복원 버튼을 누릅니다.\n\n'
        '주의: 영구 삭제된 파일은 복원할 수 없습니다.\n\n'
        '출처: 운영 매뉴얼 12장\n\n$filler');
    final refs = service.rank('휴지통 복원', [doc]);
    final answer = service.answerForQuery('휴지통 복원', refs);
    expect(answer, contains('영구 삭제된 파일은 복원할 수 없습니다'));
    expect(answer, contains('운영 매뉴얼 12장'));
    expect(answer.length, lessThan(doc.answer.length));
  });
  test('same-document evidence remains separate and other versions are excluded', () {
    final refs = [
      SimilarVocResult(knowledgeBase: entry('a', '복원', '복원 절차', source: 'v2'), similarityScore: .95),
      SimilarVocResult(knowledgeBase: entry('b', '복원 제한', '복원 제한 조건', source: 'v2'), similarityScore: .94),
      SimilarVocResult(knowledgeBase: entry('c', '복원', '구버전 절차', source: 'v1'), similarityScore: .94),
    ];
    final answer = service.answerForQuery('복원', refs);
    expect(answer, contains('복원 절차'));
    expect(answer, contains('복원 제한 조건'));
    expect(answer, isNot(contains('구버전 절차')));
  });
  test('complete bundled corpus: old English body and new documents are searchable', () async {
    final pack = await BundledManualService.load();
    final rows = [...BritySuiteManualSeed.entries, ...(pack['entries'] as List)];
    expect(BritySuiteManualSeed.entries.length, 476);
    expect(rows.length, 1008);
    final docs = rows.map((r) => entry(r['id'] as String, r['question'] as String,
        r['answer'] as String, source: r['sourceName'] as String?)).toList();
    final queries = <String, String>{
      '메신저 제거 conversation data': 'All conversation data',
      '메신저 바로가기 desktop': 'Shortcut',
      '드라이브 다른 사람이 편집 중인 파일 취소': '강제 취소 기능을 제공하지 않습니다',
    };
    final watch = Stopwatch()..start();
    for (final query in queries.entries) {
      final refs = service.rank(query.key, docs);
      expect(service.canAnswer(query.key, refs), isTrue, reason: query.key);
      expect(service.answerForQuery(query.key, refs), contains(query.value), reason: query.key);
    }
    expect(service.canAnswer('급여 지급일 세금 계산', service.rank('급여 지급일 세금 계산', docs)), isFalse);
    // Catch accidental pathological full-corpus scans, without a tight device-specific SLA.
    expect(watch.elapsed.inSeconds, lessThan(30));
  });
}
