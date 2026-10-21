import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Reviewed translations are bound to the exact source, not just an entry ID.
/// User edits, other manual versions and the original searchable text are kept.
class ReviewedManualTranslation {
  ReviewedManualTranslation._();

  static const _notificationSources = {
    'brity-messenger-desktop-020':
        'cb56a56065cb83f11776fdfe7deed9a0efb69fb05df25eb69b376eee4a81e015',
    'raw-messenger-desktop-22':
        '972119222065207e2973916bc596d17ed2e375634fa01e79790dd9df10e42e01',
  };

  static String? forSource(String entryId, String source) {
    final expected = _notificationSources[entryId];
    if (expected == null) return null;
    final normalized = source.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (sha256.convert(utf8.encode(normalized)).toString() != expected) {
      return null;
    }
    return notification;
  }

  static const notification = '''알림 설정 · PC
메뉴 경로(한국어 번역): 옵션 > 알림

• 메시지 알림: 새 메시지가 도착했을 때 알림을 받을 방법을 선택합니다.
• 소리 알림: 이 항목을 선택하면 대화창을 보고 있는 동안 소리가 나지 않습니다.
• 알림창: 알림창에 메시지 내용을 표시할지 설정합니다.
• 작업 표시줄: 알림을 반복해서 깜박이도록 설정합니다.
• 대화방 표시: 알림을 끈 대화방은 작업 표시줄에 표시하지 않도록 설정합니다.
• 말풍선 알림: 로그인할 때 읽지 않은 메시지를 말풍선으로 알려줍니다.
• 방해 금지 — 발표 모드: 발표 중 상태를 ‘다른 용무’로 바꾸고 알림을 끕니다.
• 방해 금지 — 화면 복제: 모니터 화면을 복제할 때 상태를 ‘다른 용무’로 바꾸고 알림을 끕니다.
• 방해 금지 — 일반: 해당 항목을 선택하면 상태를 ‘다른 용무’로 바꾸고 알림을 끕니다.

출처: 삼성SDS 브리티 메신저 PC 사용자 매뉴얼, 2020년판 22쪽.
위 내용은 해당 영문 원문의 한국어 번역입니다. 메뉴의 원래 표기는 아래에서 확인할 수 있습니다.''';
}
