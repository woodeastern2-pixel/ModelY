/// Bounded query planning. Quoted instructions are context, never evidence.
class OfflineQueryPlan {
  final String original;
  final String focus;
  final String request;
  final bool navigation;
  final List<String> parts;
  const OfflineQueryPlan._(this.original, this.focus, this.navigation, this.parts, this.request);

  static final versionPattern = RegExp(
      r'(?:\bv(?:ersion)?\s*|버전\s*)(\d+(?:\.\d+){1,3})|(?<![\d.])(\d+\.\d+\.\d+)(?![\d.])', caseSensitive: false);
  static final quantityPattern = RegExp(
      r'\d[\d,]*(?:\.\d+)?\s*(?:명|일|시간|분|초|개|GB|MB|KB)\b|\d[\d,]*(?:\.\d+)?\s*(?:명|일|시간|분|초|개)(?=[가-힣\s?.!,]|$)',
      caseSensitive: false);
  static final conditionPattern = RegExp(
      r'영구\s*삭제|관리자\s*없이|권한\s*없이|오프라인|외부\s*(?:사용자|참석자)|무기명|익명|읽기\s*전용');
  static List<String> conditions(String text) => conditionPattern.allMatches(text)
      .map((m) => m.group(0)!).toSet().toList();
  static List<String> versions(String text) =>
      versionPattern.allMatches(text).map((m) => m.group(1) ?? m.group(2)!).toSet().toList();
  static List<String> quantities(String text) => quantityPattern.allMatches(text)
      .map((m) => m.group(0)!.replaceAll(RegExp(r'[\s,]'), '').toLowerCase()).toSet().toList();

  factory OfflineQueryPlan.from(String query) {
    var focus = query.trim();
    // Word boundaries keep "button" / "attribute" from becoming "but".
    final pivots = RegExp(r'다만|하지만|그런데|그러나|문제는|\bhowever\b|\bbut\b',
        caseSensitive: false).allMatches(focus).toList();
    if (pivots.isNotEmpty) {
      final tail = focus.substring(pivots.last.end).trim();
      if (tail.length >= 4) focus = tail;
    }
    final request = focus;
    final parts = focus.replaceAllMapped(
        RegExp(r'(방법|절차|기간|용량)(?:과|와)\s+'), (m) => '${m.group(1)}\n')
        .split(RegExp(r'\s+(?:그리고|또한|및)\s+|[?？]\s+|\n'))
        .map((s) => s.trim()).where((s) => s.length >= 2).toList();
    final navigation = RegExp(
        r'메뉴.{0,35}위치|위치.{0,20}메뉴|어디|어느.{0,8}(메뉴|화면)|경로|못\s*찾|\bwhere\b',
        caseSensitive: false).hasMatch(focus);
    if (navigation && parts.length <= 1) {
      final bracket = RegExp(r'\[([^\[\]\n]{2,30})\]').firstMatch(focus);
      final named = RegExp(r'([가-힣A-Za-z0-9_ -]{2,35})\s*(메뉴|버튼|패널)(?:의|는|은|을|를|이|가)?').firstMatch(focus);
      final target = bracket?.group(1)?.trim() ?? named?.group(1)?.trim();
      if (target != null && target.isNotEmpty) focus = '$target 메뉴 위치';
    }
    return OfflineQueryPlan._(query, focus, navigation,
        parts.length > 1 ? parts : [focus], request);
  }
}
