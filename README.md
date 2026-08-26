# AI VOC Intelligence Platform

서버 없이 로컬에서 실행 가능한 Flutter 기반 기업용 VOC 운영 플랫폼입니다.

- Frontend: Flutter + Material Design 3
- Architecture: Clean Architecture + Repository Pattern + MVVM
- Database: SQLite (sqflite)
- Vector Search:
  - 기본: 앱 내 코사인 유사도 검색
  - 선택: FAISS 브릿지 서버 연동
- AI Engine: Ollama / OpenAI 선택
- Integration: JIRA REST API
- Target: Android APK, Windows EXE

## 1. 주요 기능 구현 상태

- VOC 등록: 고객명, 프로젝트명, 카테고리, 제목, 내용, 우선순위 저장
- AI 신규 VOC 분석(점수 포함)
  - 업무 관련 여부
  - 카테고리
  - 긴급도(Critical/High/Medium/Low)
  - 담당 부서 추천
  - 담당자 추천(Top 3)
  - 중복 VOC 탐지(임베딩 기반, 85% 이상)
  - JIRA 생성 필요 여부
- AI 답변 추천(RAG): 유사 사례 기반 추천 답변/신뢰도/참고 목록 제공
- 신규 VOC 등록 직후(업무 관련) AI 답변 화면 자동 진입
- 시스템 매뉴얼 업로드 기반 지식화
  - 지식베이스 화면에서 PDF, DOCX, XLSX, PPTX 업로드
  - 문서 본문을 섹션 단위로 분할해 knowledge_base에 자동 적재
  - 신규 VOC 답변 생성 시 시스템 매뉴얼 출처를 우선 참조
- 답변 승인 프로세스: Draft 저장 후 관리자 승인, Confluence FAQ 자동 등록 시도
- Outlook 연동: 메일 수집, 메일 기반 VOC 생성, 첨부파일 로컬 저장
- Excel 연동(xlsx): VOC 대량 Import, VOC Export
- Teams/Slack Webhook: 긴급 장애 알림, VOC/AI 답변 공유
- JIRA 연동: 이슈 생성/조회/연결 테스트
- 관리자 화면: VOC/답변/카테고리/설정 관리
- 통합 대시보드: 중복 감소율, AI 활용률, 평균 처리시간, 담당자별 처리 현황

## 2. 프로젝트 구조

```text
ai_voc_assistant/
  lib/
    core/
      constants/
      database/
      theme/
      utils/
    domain/
      entities/
      repositories/
    data/
      datasources/
        local/
        remote/
      repositories/
      services/
    presentation/
      screens/
        splash/
        login/
        home/
        dashboard/
        voc/
        knowledge_base/
        jira/
        settings/
        admin/
      viewmodels/
      widgets/
    main.dart
  assets/
    images/
    icons/
  scripts/
    faiss_bridge_server.py
    requirements-faiss.txt
  pubspec.yaml
```

## 3. DB 스키마

앱 시작 시 SQLite에 자동 생성됩니다.

- vocs
  - id, title, content, category, customer, project, priority, status, created_at
- responses
  - id, voc_id, content, status, ai_generated, confidence_score, approved_at
- knowledge_base
  - id, question, answer, category, embedding, resolved_at
- jira_links
  - id, voc_id, jira_key, jira_status
- settings
  - key, value

## 4. 로컬 실행

### 4.1 Flutter 준비

```bash
flutter --version
flutter doctor
```

### 4.2 의존성 설치

```bash
flutter pub get
```

### 4.3 플랫폼 파일 생성 (최초 1회)

현재 저장소에 Flutter 플랫폼 폴더가 없다면:

```bash
flutter create . --platforms=android,windows
```

### 4.4 실행

```bash
# Windows
flutter run -d windows

# Android 디바이스/에뮬레이터
flutter run -d android
```

## 5. AI 설정

앱의 설정 화면에서 선택:

- Ollama
  - URL 예: http://localhost:11434
  - 모델 예: llama3.2
- OpenAI
  - API Key
  - 모델 예: gpt-4o-mini

## 6. FAISS 연동 (선택)

기본은 앱 내부 검색으로 동작하며, 필요 시 FAISS 브릿지를 붙일 수 있습니다.

### 6.1 브릿지 실행

```bash
cd scripts
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\\Scripts\\activate
pip install -r requirements-faiss.txt
uvicorn faiss_bridge_server:app --host 127.0.0.1 --port 8787
```

### 6.2 앱 설정

- 설정 > AI 설정 > FAISS Endpoint
- 값: http://127.0.0.1:8787

## 7. Outlook / Excel / Teams / Slack / Confluence 설정

설정 > 연동 탭에서 등록:

- Outlook
  - Graph Access Token
  - 폴더(Inbox 등)
- Teams
  - Incoming Webhook URL
- Slack
  - Incoming Webhook URL
- Confluence
  - URL, Space Key, Email, Token
- Excel
  - xlsx Import/Export 버튼 제공

## 7.1 시스템 매뉴얼 업로드

- 위치: 지식베이스 화면 우측 상단 업로드 아이콘
- 권장 포맷: PDF, DOCX, XLSX, PPTX
- 처리 방식:
  - 문서 텍스트 추출
  - 약 900자 단위 섹션 분할
  - category=시스템매뉴얼로 지식베이스 등록
  - 임베딩 생성 후 검색 인덱스 반영
- 답변 생성 동작:
  - 유사 후보 검색 후 시스템 매뉴얼 항목에 가중치 부여
  - 프롬프트에 출처(시스템 매뉴얼/VOC 이력) 표시
  - 시스템 매뉴얼 출처를 우선 참조하도록 규칙 적용

참고: 구형 바이너리 포맷(doc/xls/ppt)은 직접 파싱이 어려워 OpenXML(docx/xlsx/pptx)로 저장 후 업로드를 권장합니다.

## 8. JIRA 설정

설정 > JIRA 설정에서 입력:

- URL (예: https://yourcompany.atlassian.net)
- Project Key
- Email
- API Token

## 9. 빌드 가이드

### 9.1 Android APK

```bash
flutter build apk --release
```

출력:

- build/app/outputs/flutter-apk/app-release.apk

### 9.1.1 고정 다운로드 링크 사용

항상 같은 링크로 최신 APK를 배포하려면 아래 스크립트를 사용하세요.

```bash
bash scripts/build_release_artifacts.sh
```

이 스크립트는 arm64 전용 APK로 빌드해서 용량을 줄인 뒤 아래 파일을 갱신합니다.

- ai_voc_assistant/release_artifacts/ai_voc_assistant-latest.apk
- ai_voc_assistant/release_artifacts/ai_voc_assistant-arm64-v8a-release.apk

고정 GitHub 다운로드 링크:

- https://github.com/woodeastern2-pixel/dex-java/raw/main/ai_voc_assistant/release_artifacts/ai_voc_assistant-latest.apk

`ai_voc_assistant-latest.apk`는 기본적으로 arm64-v8a APK를 가리킵니다.

### 9.2 Windows EXE

```bash
flutter build windows --release
```

출력:

- build/windows/x64/runner/Release/

## 10. 샘플 데이터

앱 첫 실행 시 샘플 지식베이스 데이터 5건이 자동 삽입됩니다.

## 11. 보안/운영 참고

- OpenAI API Key, JIRA Token은 SQLite settings에 저장됩니다.
- 운영 배포 시 암호화 저장소(예: flutter_secure_storage) 적용을 권장합니다.
