import 'package:ai_voc_assistant/core/utils/user_facing_text.dart';
import 'package:ai_voc_assistant/core/utils/voc_display_utils.dart';
import 'package:ai_voc_assistant/domain/entities/voc_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI markdown markers are removed from user-facing text', () {
    const source = '**선정 근거:**\n* **질문 상세:** 로그인 오류';

    expect(
      UserFacingText.fromAi(source),
      '선정 근거:\n• 질문 상세: 로그인 오류',
    );
  });

  test('VOC label uses project code and number instead of UUID', () {
    final now = DateTime(2026, 8, 14);
    final voc = VocEntity(
      id: '0449dff9-5f86-4e03-895d-29805543eca8',
      title: '메신저 타교 겸임 등록 문의',
      content: '문의 내용',
      category: '기능문의',
      customer: '양감중학교',
      project: 'BW서비스운영 | GVBSO | 2456',
      priority: 'MEDIUM',
      status: 'OPEN',
      createdAt: now,
      updatedAt: now,
    );

    expect(VocDisplayUtils.label(voc), 'GVBSO-2456 · 메신저 타교 겸임 등록 문의');
  });
}
