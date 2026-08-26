import '../constants/app_constants.dart';

class VocCategoryCatalog {
  VocCategoryCatalog._();

  static const int dashboardVisibleLimit = 7;
  static const String fallbackCategory = '기타';

  static const Map<String, List<String>> _keywordsByCategory = {
    '장애': [
      '장애',
      '오류',
      '에러',
      '실패',
      'fail',
      'error',
      'exception',
      'crash',
      '다운',
      '중단',
      '불가',
      '안됨',
      '먹통',
      'timeout',
      '404',
      '401',
      '500',
      '503',
    ],
    '기능문의': ['기능', '문의', '동작', '지원', '옵션', '설정', '기술'],
    '사용법': [
      '사용법',
      '어떻게',
      '방법',
      '가이드',
      'manual',
      'how to',
      '절차',
      '설명',
      '도움말',
    ],
    '개선요청': [
      '개선',
      '요청',
      '제안',
      '추가',
      '변경',
      '수정 요청',
      'enhancement',
      'feature request',
    ],
    '운영문의': ['운영', '정책', '일정', '배포', '공지', '프로세스', '상태'],
    '계약문의': [
      '계약',
      '견적',
      '비용',
      '요금',
      '청구',
      '정산',
      '결제',
      '라이선스',
      'license',
    ],
    '성능': ['성능', '느림', '지연', '속도', 'latency', 'slow', '메모리', 'cpu', '버벅'],
    '보안': ['보안', '취약', '침해', 'security', 'ssl', '암호', '개인정보', '해킹', '인증서'],
    '연동': [
      '연동',
      'api',
      'webhook',
      'jira',
      'slack',
      'teams',
      'confluence',
      'sync',
      '동기화',
      'sso',
      'oauth',
    ],
    '데이터': [
      '데이터',
      'db',
      'database',
      '저장',
      '조회',
      '누락',
      '정합성',
      '엑셀',
      'import',
      'export',
      '백업',
    ],
    '권한': ['권한', '로그인', '접속', '계정', '승인', '인증', '인가', 'permission', 'role', 'admin'],
    'UI/UX': ['ui', 'ux', '화면', '레이아웃', '디자인', '글씨', '색상', '정렬', '대시보드'],
    '모바일': ['모바일', 'android', 'ios', 'apk', 'app store', 'play store', '앱'],
    '인프라': ['서버', 'infra', '인프라', '네트워크', '포트', '클라우드', 'docker', 'kubernetes', 'k8s', 'vm'],
    '기타': ['기타', '일반', 'voice voc', 'screenshot analysis', 'screenshot', 'document analysis'],
  };

  static List<String> get categories => AppConstants.defaultCategories;

  static bool isAllowed(String? category) {
    if (category == null) return false;
    return categories.contains(category.trim());
  }

  static String normalize(
    String? rawCategory, {
    String? title,
    String? content,
    String? aiCategory,
    String? tags,
  }) {
    final raw = rawCategory?.trim() ?? '';
    if (isAllowed(raw)) {
      return raw;
    }

    final fromSignal = _findCategoryByKeywords(
      [raw, aiCategory ?? '', tags ?? '', title ?? '', content ?? '']
          .where((value) => value.trim().isNotEmpty)
          .join(' '),
    );
    if (fromSignal != null) {
      return fromSignal;
    }

    return fallbackCategory;
  }

  /// 일괄 재지정에서는 기존 category를 우선하지 않고,
  /// ai_category + 제목/내용/태그 신호를 기준으로 다시 분류한다.
  static String recategorize({
    String? currentCategory,
    String? title,
    String? content,
    String? aiCategory,
    String? tags,
  }) {
    final aiRaw = aiCategory?.trim() ?? '';
    if (isAllowed(aiRaw)) {
      return aiRaw;
    }

    final fromSignal = _findCategoryByKeywords(
      [aiRaw, tags ?? '', title ?? '', content ?? '']
          .where((value) => value.trim().isNotEmpty)
          .join(' '),
    );
    if (fromSignal != null) {
      return fromSignal;
    }

    final current = currentCategory?.trim() ?? '';
    if (!isAllowed(current)) {
      return fallbackCategory;
    }

    return fallbackCategory;
  }

  static String? _findCategoryByKeywords(String rawText) {
    final haystack = rawText.toLowerCase();
    if (haystack.trim().isEmpty) {
      return null;
    }

    for (final entry in _keywordsByCategory.entries) {
      for (final keyword in entry.value) {
        if (haystack.contains(keyword.toLowerCase())) {
          return entry.key;
        }
      }
    }

    return null;
  }

  static Map<String, int> aggregateCounts(Map<String, int> rawCounts) {
    final aggregated = <String, int>{};
    for (final entry in rawCounts.entries) {
      final normalized = normalize(entry.key);
      aggregated[normalized] = (aggregated[normalized] ?? 0) + entry.value;
    }

    final sorted = aggregated.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) {
          return countCompare;
        }
        return categories.indexOf(a.key).compareTo(categories.indexOf(b.key));
      });

    return {for (final entry in sorted) entry.key: entry.value};
  }
}