/// Bounded, deterministic query planning. The user's quoted old answer is
/// context, not evidence, and must not drown out the current question.
class OfflineQueryPlan {
  final String original;
  final String focus;
  final bool navigation;
  const OfflineQueryPlan._(this.original, this.focus, this.navigation);

  factory OfflineQueryPlan.from(String query) {
    var focus = query.trim();
    final pivots = RegExp(r'다만|하지만|그런데|그러나|문제는|however|but',
        caseSensitive: false).allMatches(focus).toList();
    if (pivots.isNotEmpty) {
      final tail = focus.substring(pivots.last.end).trim();
      if (tail.length >= 4) focus = tail;
    }
    final navigation = RegExp(
        r'메뉴.{0,35}위치|위치.{0,20}메뉴|어디|어느.{0,8}(메뉴|화면)|경로|못\s*찾|where',
        caseSensitive: false).hasMatch(focus);
    if (navigation) {
      final bracket = RegExp(r'\[([^\[\]\n]{2,30})\]').firstMatch(focus);
      final named = RegExp(r'([가-힣A-Za-z0-9_ -]{2,35})\s*(메뉴|버튼|패널)(?:의|는|은|을|를|이|가)?').firstMatch(focus);
      final target = bracket?.group(1)?.trim() ?? named?.group(1)?.trim();
      if (target != null && target.isNotEmpty) focus = '$target 메뉴 위치';
    }
    return OfflineQueryPlan._(query, focus, navigation);
  }
}
