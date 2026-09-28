class PrivacyMaskingService {
  PrivacyMaskingService._();

  static final RegExp _emailPattern = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _phonePattern = RegExp(
    r'(?:\+82[-\s]?)?0?(?:10|11|16|17|18|19|2|3[1-3]|4[1-4]|5[1-5]|6[1-4]|70)[-\s]?\d{3,4}[-\s]?\d{4}',
  );

  static final RegExp _residentRegistrationPattern = RegExp(
    r'\d{6}[-\s]?[1-4]\d{6}',
  );

  static final RegExp _cardPattern = RegExp(
    r'(?:\d{4}[-\s]){3}\d{4}',
  );

  static final RegExp _labeledNamePattern = RegExp(
    r'(고객명|성명|이름)(\s*[:：]\s*)([가-힣A-Za-z]{2,30})',
  );

  /// 외부 AI 전송 전에 명확하게 식별 가능한 개인정보를 최소화한다.
  ///
  /// 원본 데이터는 변경하지 않으며, 반환된 문자열만 외부 요청에 사용한다.
  /// 정규식 기반 보조수단이므로 모든 개인정보를 탐지한다고 보장하지 않는다.
  static String mask(String input) {
    if (input.isEmpty) return input;

    var masked = input;
    masked = masked.replaceAll(_emailPattern, '[이메일]');
    masked = masked.replaceAll(_residentRegistrationPattern, '[주민등록번호]');
    masked = masked.replaceAll(_cardPattern, '[카드번호]');
    masked = masked.replaceAll(_phonePattern, '[전화번호]');
    masked = masked.replaceAllMapped(
      _labeledNamePattern,
      (match) => '${match.group(1)}${match.group(2)}[이름]',
    );
    return masked;
  }
}
