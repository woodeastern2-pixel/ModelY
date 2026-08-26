class UserFacingText {
  UserFacingText._();

  /// 마크다운을 지원하지 않는 화면에 AI 응답을 안전한 일반 텍스트로 표시한다.
  static String fromAi(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '• ')
        .trim();
  }
}
