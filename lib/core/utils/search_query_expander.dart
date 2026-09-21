class SearchQueryExpander {
  SearchQueryExpander._();

  static const List<Set<String>> _aliasGroups = [
    {
      'brity mail',
      'britymail',
      '브리티 메일',
      '브리티메일',
      'mail',
      '메일',
      'email',
      '이메일',
      '전자우편',
    },
    {
      'brity messenger',
      'britymessenger',
      '브리티 메신저',
      '브리티메신저',
      'messenger',
      '메신저',
      'chat',
      '채팅',
    },
    {
      'brity meeting',
      'britymeeting',
      '브리티 미팅',
      '브리티미팅',
      'meeting',
      '미팅',
      '화상회의',
      '영상회의',
      'web conference',
      'video conference',
    },
    {
      'brity drive',
      'britydrive',
      '브리티 드라이브',
      '브리티드라이브',
      'drive',
      '드라이브',
      'cloud storage',
      '클라우드 저장소',
      '파일 저장소',
    },
    {
      'brity copilot',
      'britycopilot',
      '브리티 코파일럿',
      '브리티코파일럿',
      'copilot',
      '코파일럿',
      'ai assistant',
      'ai 어시스턴트',
      '인공지능 비서',
    },
    {
      'desktop',
      '데스크톱',
      'pc',
      '피씨',
    },
    {
      'mobile',
      '모바일',
      'mobile app',
      '모바일 앱',
    },
  ];

  /// 검색 임베딩과 AI 재정렬에 쓸 수 있도록 발견된 개념의 한·영 별칭을
  /// 원문 뒤에 덧붙인다. 원문 자체는 보존하므로 답변 질문의 의미는 바뀌지 않는다.
  static String expand(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;

    final normalized = normalize(trimmed);
    final aliases = <String>[];
    for (final group in _aliasGroups) {
      if (!_containsAnyAlias(normalized, group)) continue;
      aliases.addAll(group.where((alias) => !_containsAlias(normalized, alias)));
    }
    if (aliases.isEmpty) return trimmed;
    return '$trimmed ${aliases.join(' ')}';
  }

  /// 검색어의 각 개념이 대상 문서에 얼마나 포함되는지를 계산한다.
  /// 제품명 별칭 묶음은 여러 토큰이 아니라 하나의 개념으로 계산한다.
  static double matchRatio(String query, String corpus) {
    final normalizedQuery = normalize(query);
    final normalizedCorpus = normalize(corpus);
    if (normalizedQuery.isEmpty || normalizedCorpus.isEmpty) return 0.0;

    final matchedGroups = <Set<String>>[];
    for (final group in _aliasGroups) {
      if (_containsAnyAlias(normalizedQuery, group)) {
        matchedGroups.add(group);
      }
    }

    final groupedTokens = matchedGroups
        .expand((group) => group)
        .expand(_tokenize)
        .toSet();
    final plainTokens = _tokenize(normalizedQuery)
        .where(
          (token) =>
              !groupedTokens.contains(token) &&
              !matchedGroups.any(
                (group) => _containsAnyAlias(token, group),
              ),
        )
        .toSet();

    var totalConcepts = matchedGroups.length + plainTokens.length;
    if (totalConcepts == 0) return 0.0;

    var hits = plainTokens.where(normalizedCorpus.contains).length;
    for (final group in matchedGroups) {
      if (_containsAnyAlias(normalizedCorpus, group)) hits++;
    }
    return hits / totalConcepts;
  }

  static bool matches(String query, String corpus) =>
      matchRatio(query, corpus) >= 1.0;

  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^0-9a-z가-힣\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _containsAnyAlias(String normalized, Set<String> aliases) {
    return aliases.any((alias) => _containsAlias(normalized, alias));
  }

  static bool _containsAlias(String normalized, String alias) {
    final normalizedAlias = normalize(alias);
    if (normalizedAlias.isEmpty) return false;
    if (RegExp(r'[가-힣]').hasMatch(normalizedAlias)) {
      return normalized.contains(normalizedAlias);
    }
    final escaped = RegExp.escape(normalizedAlias);
    return RegExp('(^|\\s)$escaped(?=\\s|\$|[가-힣])')
        .hasMatch(normalized);
  }

  static Iterable<String> _tokenize(String input) {
    return normalize(input)
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.length >= 2);
  }
}
