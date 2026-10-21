# 전체 시스템 시연 수정 검증 — 2026-10-21

요청한 중복 점검·백업 장면을 목차, 내레이션, 영상에서 삭제하고 실제 LLM 초안과 코파일럿 질의를 다시 녹화했다. 검색 근거와 승인 이력 연결도 수정했다.

## 실제 실행

- 애플리케이션 검증 커밋: `5a97d199d0673288c87968237d772e66194a7d1c`
- 브랜치: `work/voc-mate-quality-recording`
- 실제 녹화: [GitHub Actions 39582249785](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39582249785)
- 시연 모델: `qwen3:4b-instruct-2507-q4_K_M`, 로컬 Ollama, temperature 0.1, 최대 출력 640 tokens.
- AI 응답을 사람이 작성한 정답으로 대체하지 않았다. 실제 생성된 초안을 그대로 승인·저장했고, 코파일럿에는 해당 승인 답변이 전달되었다.
- 문의 등록 → 생성 → 근거 확인 → 승인 → 처리 이력 → 코파일럿 → 실제 수신 서버 공유까지 통과했다.
- 이 영상의 4B 모델은 Ollama 설정이다. Windows 배포본의 기본 내장 모델 Qwen3-1.7B Q8_0을 4B로 교체했다는 의미는 아니다.

## 답변 확인

초안의 Options > Notification 경로, Sound Alert Settings의 음소거 항목, Do Not Disturb Settings의 Busy 상태 및 알람 끄기 동작을 실제 공급된 Samsung SDS Desktop 매뉴얼 Notification 절과 대조했다. 근거 없는 재시작·재설치 안내는 없다. 장애의 실제 원인을 확정하거나 해결을 보장하는 시연은 아니다.

실제 초안:

```text
알림 설정은 [Options > Notification]에서 확인할 수 있습니다.
- 소리 알림은 [Sound Alert Settings]에서 '소리 끄기' 설정을 확인합니다.
- 방해 금지 설정은 [Do Not Disturb Settings]에서 'Busy' 상태로 설정하고 알람을 끄는 옵션을 확인합니다.
이 설정 항목들은 시스템 매뉴얼의 'Notification' 섹션에 명시되어 있습니다.
```

실제 코파일럿 응답:

```text
알림 설정은 [Options > Notification]에서 확인할 수 있습니다.  
소리 알림은 [Sound Alert Settings]에서 '소리 끄기' 설정을 확인합니다.  
방해 금지 설정은 [Do Not Disturb Settings]에서 'Busy' 상태로 설정하고 알람을 끄는 옵션을 확인합니다.  
근거: 브리티 메신저 PC 새 메시지 알림 문의
```

코파일럿 공급 자료는 실제 승인된 현재 문의의 답변 1건이다. 응답의 설정 경로와 점검 항목이 승인 내용과 일치하며 마지막 줄에 문의 제목을 표시한다.

## 코드 변경

- `local_answer_service.dart`: 메시지·소리·팝업·방해 금지의 한영 개념 검색, 기능 중심 검색, 승인 답변 요청의 주제와 출력 형식 지시 분리.
- `offline_search_index.dart`: 기존 검색 캐시의 키를 보존하며 새 개념 키를 보완.
- `ai_viewmodel.dart`: 강한 근거가 있을 때 낮은 관련성의 문서를 제외하고 모델 공급 근거를 최대 3건으로 제한.
- `ai_service.dart`: 간결한 근거 중심 초안 규칙, 설정의 켜짐/꺼짐과 적용 조건 구분, 근거 없는 일반 해결책 금지.
- 녹화 드라이버: 실제 모델·실제 클립보드·실제 승인/공유 검증, 파일 선택 창의 포커스 확인.
- 편집 도구: 대기 압축, 파일 선택 창 제거, 11개 목차, 짧은 구간 간 간격. 긴 원본 구간을 순차 처리하여 메모리 사용을 제한.

## 검증 및 산출물

[호환성 실행 39582249663](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39582249663)

- `flutter analyze --no-fatal-infos --no-fatal-warnings`: 성공, 새 error 없음. 전체 98개 warning/info. 기존 97개 외에 검색 진단 테스트의 `avoid_print` info 1개가 추가되었다.
- `flutter test --fail-fast --exclude-tags=golden`: 221개 통과. 녹화용 장시간 peer fixture는 별도 실제 녹화에서 검증했다.
- `flutter build windows --release`: 성공. `build/windows/x64/runner/Release/ai_voc_assistant.exe` 존재 검사 및 배포 폴더 업로드 성공. [Windows artifact](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39582249663/artifacts/12339377115).
- `flutter build apk --release`: 성공. `build/app/outputs/flutter-apk/app-release.apk` 업로드 성공. [Android artifact](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39582249663/artifacts/12339272756).
- 실행 환경에 Flutter/Windows/Android SDK가 없어 GitHub Actions를 사용했다. 앱 UI 레이아웃 변경은 없다.
- 최종 영상: `VOC_Mate_LLM_Full_System_Demo.mp4`, 177.719000초, 1920×1080, H.264/AAC, 8271528 bytes, 11개 구간.
- 전체 디코딩 성공, 2.5초 이상 무음 0건. 11개 장면과 초안·코파일럿 화면을 시각 검수했다. 파일 선택 창은 타임라인에서 제외했다.
- 영상 SHA-256: `b46d9a4ccfd39ab567688b31ca4886bca3973a2075e0a83e2cab7c0506d237d9`
- 화면에는 대기 구간 단축 사실을 표시한다. 영상의 생성 대기 길이를 실제 응답 지연 시간으로 해석하면 안 된다.

## Git 상태

소스는 위 브랜치에 GitHub 커밋 API로 기록하고 기대한 이전 SHA를 확인하며 fast-forward 갱신했다. 로컬 Git checkout을 사용하지 않았으므로 working tree clean 여부는 해당 없음이다. 최종 전달 커밋에는 이 검증 기록과 영상 편집/검수 스크립트만 추가하며 앱 코드는 검증 커밋과 동일하다. 불필요한 CI 재실행을 피하기 위해 전달 기록 커밋은 `[skip ci]`로 저장한다.
