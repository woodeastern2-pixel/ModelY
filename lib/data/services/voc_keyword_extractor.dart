/// Operational topics, counted once per VOC. Ordinary sentence fragments never
/// become dashboard topics just because they occur frequently.
class VocKeywordExtractor {
  static final _topics = <String, RegExp>{
    '로그인': RegExp(r'로그인|sign[ -]?in|log[ -]?in', caseSensitive: false),
    '비밀번호': RegExp(r'비밀번호|암호|password', caseSensitive: false),
    '접근 권한': RegExp(r'접근\s*권한|권한|permission|access denied', caseSensitive: false),
    '첨부파일': RegExp(r'첨부\s*파일|첨부|attachment', caseSensitive: false),
    '메일 수신': RegExp(r'(?:메일|email|mail).{0,12}수신|수신.{0,12}메일', caseSensitive: false),
    '메일 발송': RegExp(r'(?:메일|email|mail).{0,12}(?:발송|발신)|(?:발송|발신).{0,12}메일', caseSensitive: false),
    '대화창 표시': RegExp(r'대화창|말풍선|메시지.{0,15}(?:표시|정렬|왼쪽|오른쪽)'),
    '알림': RegExp(r'알림|notification', caseSensitive: false),
    '파일 공유': RegExp(r'파일.{0,12}공유|공유.{0,12}파일|file shar', caseSensitive: false),
    '업로드': RegExp(r'업로드|upload', caseSensitive: false),
    '다운로드': RegExp(r'다운로드|내려받|download', caseSensitive: false),
    '동기화': RegExp(r'동기화|\bsync(?:hronization)?\b', caseSensitive: false),
    '화상회의': RegExp(r'화상\s*회의|영상\s*회의|미팅|meeting', caseSensitive: false),
    '화면 공유': RegExp(r'화면\s*공유|screen shar', caseSensitive: false),
    '연락처': RegExp(r'연락처|contacts?', caseSensitive: false),
    '일정': RegExp(r'일정|캘린더|calendar', caseSensitive: false),
    '설문': RegExp(r'설문|survey', caseSensitive: false),
    '검색': RegExp(r'검색|search', caseSensitive: false),
    '파일 복원': RegExp(r'복원|복구|휴지통|recovery|restore', caseSensitive: false),
    '저장 용량': RegExp(r'용량|저장\s*공간|quota|storage', caseSensitive: false),
    '설치': RegExp(r'설치|install', caseSensitive: false),
    '업데이트': RegExp(r'업데이트|update', caseSensitive: false),
    '인증서': RegExp(r'인증서|certificate', caseSensitive: false),
    '접속 장애': RegExp(r'접속.{0,12}(?:안|불가|실패|오류)|연결.{0,12}(?:안|실패)|connection refused', caseSensitive: false),
    '응답 지연': RegExp(r'느리|느려|끊김|끊겨|지연|timeout|latency', caseSensitive: false),
    '메신저': RegExp(r'메신저|messenger', caseSensitive: false),
    '드라이브': RegExp(r'드라이브|\bdrive\b', caseSensitive: false),
    '메일': RegExp(r'메일|\b(?:e-?mail)\b', caseSensitive: false),
    '코파일럿': RegExp(r'코파일럿|copilot', caseSensitive: false),
  };

  static Set<String> extract(String text) {
    final topics = <String>{
      for (final item in _topics.entries)
        if (item.value.hasMatch(text)) item.key,
    };
    // Specific functions are more useful than their enclosing product name.
    if (topics.any((t) => !{'메일', '메신저', '드라이브', '코파일럿'}.contains(t))) {
      topics.removeAll({'메일', '메신저', '드라이브', '코파일럿'});
    }
    for (final match in RegExp(r'\b(?:ERR_[A-Z0-9_]+|HTTP[ -]?[45][0-9]{2}|0x[0-9a-f]{4,})\b',
        caseSensitive: false).allMatches(text)) {
      topics.add(match.group(0)!.toUpperCase());
    }
    return topics;
  }
}
