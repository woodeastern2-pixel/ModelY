import 'package:ai_voc_assistant/core/utils/privacy_masking_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrivacyMaskingService', () {
    test('masks common personal identifiers before external AI use', () {
      const input = '''
고객명: 홍길동
이메일: gildong@example.com
전화: 010-1234-5678
주민번호: 900101-1234567
카드: 1234-5678-9012-3456
내용: 로그인 오류가 발생합니다.
''';

      final masked = PrivacyMaskingService.mask(input);

      expect(masked, contains('고객명: [이름]'));
      expect(masked, contains('[이메일]'));
      expect(masked, contains('[전화번호]'));
      expect(masked, contains('[주민등록번호]'));
      expect(masked, contains('[카드번호]'));
      expect(masked, contains('로그인 오류가 발생합니다.'));
      expect(masked, isNot(contains('홍길동')));
      expect(masked, isNot(contains('gildong@example.com')));
      expect(masked, isNot(contains('010-1234-5678')));
    });

    test('does not mutate ordinary operational text', () {
      const input = 'GVBSO-2456 로그인 서버에서 오류 코드 503이 발생했습니다.';
      expect(PrivacyMaskingService.mask(input), input);
    });

    test('supports compact Korean mobile phone format', () {
      expect(
        PrivacyMaskingService.mask('연락처 01012345678'),
        '연락처 [전화번호]',
      );
    });
  });
}
