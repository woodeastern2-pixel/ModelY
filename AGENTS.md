# ai_voc_assistant Codex 작업 규약

이 문서는 `ai_voc_assistant` 프로젝트에서 Codex가 작업할 때 따라야 하는 기본 규약이다.

## 기본 원칙

- 기존 사용자 데이터, 설정, 대시보드, JIRA 연동, 인증 및 동기화 동작을 임의로 깨지 않는다.
- 변경 전후로 영향 범위를 확인하고, 기능 회귀 가능성이 있는 변경은 최소 단위로 수행한다.
- 확인하지 않은 결과를 성공으로 보고하지 않는다.
- 작업 완료 후에는 반드시 Git에 커밋하고 원격 GitHub 저장소로 push한다.
- force push, history rewrite, 기존 branch 삭제는 금지한다.

## 완료 조건

모든 기능 수정, 버그 수정, 리팩터링, 보안 수정 작업은 아래 항목이 완료되어야 작업 완료로 간주한다.

1. `flutter analyze` 실행
2. `flutter test` 실행
3. Windows EXE 빌드
4. Android APK 빌드
5. 빌드 산출물 존재 여부 확인
6. 변경 사항 커밋
7. GitHub 원격 저장소에 push
8. 최종 commit SHA 보고

정적 분석 warning/deprecated가 기존부터 존재하는 경우에는 새 오류가 추가되지 않았는지 구분해 보고한다.

UI를 변경한 경우에는 추가로 아래 항목을 완료한다.

9. `test/responsive_ui_harness_test.dart`의 10개 화면·텍스트 배율 조합 통과
10. `test/ui_preview_golden_test.dart`로 모바일·태블릿·데스크톱 실제 렌더 생성
11. 라이트·다크 테마, 단일 헤더, 내비게이션 도달성, 오버플로 부재를 시각 검수

## 빌드 정책

### Windows

가능하면 Codex 작업 환경에서 Flutter/Windows SDK를 사용해 직접 빌드한다.

권장 명령:

```bash
flutter build windows --release
```

최종 보고에는 실제 생성된 `.exe` 경로를 명시한다.

### Android

사용자 선호는 Codex 작업 환경에서 Android SDK를 사용해 APK를 직접 생성하는 방식이다.

우선 시도:

```bash
flutter build apk --release
```

최종 보고에는 실제 생성된 `.apk` 경로를 명시한다.

Codex 작업 환경에서 SDK, 디스크 공간, 네이티브 툴체인 등 환경 문제로 APK를 생성할 수 없는 경우에만 GitHub Actions 빌드를 보조 경로로 사용한다.

GitHub Actions를 사용하는 경우:

- analyze/test 품질 게이트를 통과한 뒤 빌드한다.
- APK를 workflow artifact로 업로드한다.
- 사용자가 GitHub Actions에서 직접 실행할 수 있는 `workflow_dispatch` 경로를 유지하거나 제공한다.
- 실패 시 코드 오류인지 CI 환경 오류인지 구분해서 보고한다.

## 산출물 규칙

작업 후 항상 다음 두 플랫폼의 배포 가능 상태를 확인한다.

- Windows: release EXE
- Android: release APK

산출물 자체를 Git에 커밋하는 것은 별도 지시가 없는 한 금지한다. 빌드 결과 파일은 로컬 작업 공간 또는 GitHub Actions artifact로 제공하고, 소스와 설정만 Git에 커밋한다.

## 빌드 실패 처리

EXE 또는 APK 생성 실패 상태에서 작업을 완료했다고 보고하지 않는다.

실패 시 아래를 반드시 기록한다.

- 실행한 명령
- 실패 단계
- 핵심 오류 메시지
- 코드 문제인지 환경 문제인지 판단
- 다시 빌드하기 위해 필요한 조치

환경 문제로 빌드가 불가능하더라도 소스 변경 검증과 Git push는 완료할 수 있으나, 최종 상태를 `빌드 미완료`로 명확하게 표시한다.

## Git 작업 규칙

작업 완료 시 반드시:

```bash
git status
git diff
git add <의도한 파일만>
git commit -m "<작업 내용을 설명하는 메시지>"
git push
```

커밋에는 작업과 무관한 파일을 섞지 않는다.

최종 보고에는 아래를 포함한다.

- branch
- commit SHA
- push 성공 여부
- working tree clean 여부

## 최종 보고 형식

### 변경 사항
- 변경 내용
- 주요 파일
- 변경 이유

### 검증
- `flutter analyze`
- `flutter test`
- Windows release build
- Android release APK build

### 산출물
- EXE 경로
- APK 경로 또는 GitHub Actions artifact 위치

### Git
- branch
- commit SHA
- push 결과
- working tree 상태

### 남은 문제
- warning/deprecated
- 미검증 항목
- 환경 문제
- 회귀 위험

## 중요

Codex는 작업 중 로컬 변경만 만들어 놓고 종료하지 않는다. 사용자가 명시적으로 금지하지 않는 한, 검증 가능한 상태까지 작업한 뒤 커밋하고 GitHub에 push하여 ChatGPT가 원격 저장소에서 결과를 검토할 수 있게 한다.
