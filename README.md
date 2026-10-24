# VoC Mate

**고객 문의 접수부터 근거 확인, 답변 승인, 처리 이력과 내부 공유까지 연결하는 지식 기반 업무 도우미입니다.**

VOC(Voice of Customer, 고객의 소리)와 매뉴얼을 함께 관리하고, AI(Artificial Intelligence, 인공지능)가 검색한 자료를 바탕으로 답변 초안을 작성합니다. 담당자는 인용된 문서와 원문을 확인한 뒤 답변을 검토·승인합니다. Windows와 Android를 지원합니다.

> **현재 구현 기준: 2026-10-24 · 앱 버전 `1.1.27+29`**
> 한국어 매뉴얼 원문 검색 개선 소스는 [`work/korean-manual-retrieval`](https://github.com/woodeastern2-pixel/ModelY/tree/work/korean-manual-retrieval) 브랜치에 있습니다. 기존 배포·시연 링크는 아래에 이전 버전 기록으로 유지합니다.

한국어 원문 7종의 5,825개 구간을 색인으로 검색하며 FAQ 없이도 원문·표·이미지 인식 글자를 찾습니다. 답변 작성과 코파일럿이 같은 검색 색인을 사용하고, 복합 질문에는 여러 근거와 제한 사항을 함께 전달합니다. 영어 원문 2종 및 영어 출처의 파생 자료 208건을 제거하고 기존 설치의 색인도 갱신합니다. 보안 잠금된 메신저 v8.5.5 PDF는 해독하지 않았으며, 기존 한국어 Word 원문을 사용합니다. 자세한 범위와 검증은 [작업 기록](docs/korean-manual-retrieval-scope.md)을 참고하세요.

[배포 파일](#배포-파일과-실행) · [모델 구성](#ai-모델-구성) · [개발 환경](#개발-환경과-빌드) · [검증 기록](#검증-상태) · [운영 문서](#운영-문서와-주요-코드)

## 주요 기능

| 업무 | 제공 기능 |
| --- | --- |
| 운영 현황 | 문의 현황, 처리 상태와 담당 업무를 대시보드에서 확인 |
| 문의 관리 | 고객·프로젝트·유형·담당자·처리 상태 관리, 문의 등록과 처리 이력 조회 |
| 지식 자료 | 매뉴얼 등록·검색, 문서 본문·출처·원본 이미지 확인, PDF·DOCX·XLSX·PPTX 자료 가져오기 |
| 답변 작성 | 관련 지식 검색, 근거를 활용한 답변 초안, 담당자 검토와 승인 |
| 코파일럿 | 업무 질문에 대한 지식 기반 질의응답과 참고 근거 확인 |
| 공유와 연동 | 내부망 문의·매뉴얼 공유, 동기화 실패 재시도, JIRA·Confluence·Outlook·Teams/Slack 연동 설정 |
| 데이터 관리 | Excel 가져오기·내보내기, 백업 등 운영 기능, 외부 AI 전송 전 개인정보 패턴 마스킹 |

기본 업무 흐름은 **문의 접수 → 지식 검색 → 답변 초안 → 근거 확인 → 검토·승인 → 처리 이력·공유**입니다. 외부 업무 도구 연동은 각 서비스의 계정·권한·연결 설정이 필요합니다.

## 사용 기술과 역할

| 구성 | 기술 | 적용 역할 |
| --- | --- | --- |
| 앱 화면 | Flutter · Dart · Material 3 · Pretendard | Windows·Android 화면, 반응형 구성, 한국어 표시 |
| 상태와 구조 | Provider · ViewModel · Repository | 화면 상태, 업무 로직, 데이터 접근 분리 |
| 로컬 데이터 | SQLite · `sqflite` · `sqflite_common_ffi` | 문의·답변·지식·설정 저장 |
| 지식 검색 | 앱 내부 검색 인덱스 · 키워드/개념 확장 · 벡터 검색 | 관련 문서 탐색과 답변 근거 연결; 외부 FAISS 검색 브리지는 선택 사항 |
| 근거 기반 생성 | RAG(Retrieval-Augmented Generation, 검색 증강 생성) | 질문과 관련 자료를 함께 활용하는 답변 초안·코파일럿 |
| 로컬 언어 모델 | Qwen3 · Ollama · llama.cpp | 시연용 모델 연결 및 Windows 내장 모델 실행 |
| 선택형 외부 AI | OpenAI · Gemini · Claude | 사용자가 설정한 외부 API(Application Programming Interface, 프로그램 연동 인터페이스) 호출 |
| 개발·검증·배포 | Codex · GitHub Actions | 개발 보조, 정적 분석·회귀 검사, Windows·Android 빌드 |

## AI 모델 구성

LLM(Large Language Model, 대규모 언어 모델)은 실행 환경과 선택한 연결 방식에 따라 달라집니다.

| 방식 | 모델·구성 | 사용 범위 |
| --- | --- | --- |
| 로컬 지식 응답 | 앱 내부 검색·근거 조합 | LLM 연결 없이도 로컬 자료를 활용하는 응답 경로 |
| Windows 내장 Qwen | **Qwen3-1.7B Q8_0 + llama.cpp** | Qwen 포함 배포 폴더에서 별도 Ollama 설치나 인증키 없이 실행 |
| 최신 전체 시연 | **`qwen3:4b-instruct-2507-q4_K_M` + Ollama** | 실제 답변 초안·코파일럿 응답을 생성한 시연 모델 |
| 외부 서비스 | OpenAI · Gemini · Claude | 설정한 모델과 인증키로 연결; 요청 데이터가 해당 서비스로 전송됨 |

**시연의 4B 모델과 Windows에 포함된 1.7B 모델은 서로 다른 구성입니다.** 시연 결과를 내장 모델의 동일한 성능 보장으로 해석하면 안 됩니다. Android 배포본에는 Qwen 모델을 포함하지 않습니다.

내장 Qwen은 첫 요청에 모델을 준비하며, 5분 동안 사용하지 않거나 앱이 종료되면 실행 프로세스를 종료합니다. 모델 파일만 약 1.83GB이고, 실행에는 추가 메모리가 필요합니다. 응답 시간은 PC 성능과 입력 길이에 따라 달라집니다. 자세한 동작은 [내장 Qwen 안내](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/bundled_qwen.md)를 참고하세요.

## 배포 파일과 실행

2026-10-21 검증·빌드가 완료된 파일입니다. 빌드 기준 커밋은 `8e2aa4943ff221276988652e0358282da112b626`입니다.

| 플랫폼 | 다운로드 | 실행 방법 |
| --- | --- | --- |
| Windows | [Qwen 포함 배포 ZIP — 약 1.94GB](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800/artifacts/12342600089) | 전체 압축을 풀고 `ai_voc_assistant.exe` 실행 |
| Android | [APK가 포함된 ZIP — 약 55MB](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800/artifacts/12341661087) | 압축을 풀고 `app-release.apk` 설치 |

Windows 파일은 **폴더 단위로 실행하는 배포본**입니다. EXE(Executable, 실행 파일)만 따로 옮기지 말고 DLL(Dynamic-Link Library, 동적 연결 라이브러리), `data`, `local_ai`를 함께 유지하세요. 위 링크는 설치 마법사 형태의 Setup 파일이 아닙니다. Android APK(Android Package, 안드로이드 설치 패키지) 본체는 약 93.7MB입니다.

GitHub Actions 산출물 다운로드에는 로그인이 필요할 수 있습니다. 현재 보관 만료 예정일은 **2027-01-19**이며, 이후에는 [빌드 실행 페이지](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800)와 후속 배포 기록을 확인해야 합니다.

### 처음 사용하기

1. 배포 파일을 준비하고 앱을 실행합니다.
2. **설정 → AI 설정**에서 연결 방식을 확인합니다. Qwen 포함 Windows 새 설치는 내장 Qwen을 기본으로 사용하며, 기존에 저장한 외부 연결 설정은 유지합니다.
3. 기존 사용자가 내장형으로 전환하려면 **내장 Qwen**을 선택하고 저장·연결 확인을 실행합니다.
4. 지식 자료를 확인하거나 업무 매뉴얼을 등록한 뒤 문의를 접수합니다.
5. 답변 초안을 생성하고 인용 문서의 내용·버전·적용 조건을 확인한 후 검토·승인합니다.

### 시연과 같은 Ollama 모델 사용

Ollama를 사용하는 별도 환경에서는 아래 모델을 준비하고, 앱의 AI 설정에서 Ollama 주소와 모델명을 지정합니다. 내장 Qwen 사용자에게 필요한 설치 단계는 아닙니다.

```bash
ollama pull qwen3:4b-instruct-2507-q4_K_M
```

같은 PC에서 실행 중인 Ollama의 일반적인 주소는 `http://localhost:11434`입니다. 다른 PC 또는 Android에서 접속한다면 해당 기기의 `localhost`가 아닌 실제 모델 서버 주소를 설정해야 합니다. 최신 시연은 온도 `0.1`, 최대 출력 토큰 `640`을 사용했습니다.

## 이전 버전 전체 시연과 발표 자료

2026-10-21 버전의 시연은 **LLM을 적용한 전체 시스템 영상 한 편**입니다. 실제 앱과 Qwen3 4B의 생성 결과를 사용하며, 다음 흐름을 보여 줍니다.

1. 운영 현황
2. 언어 모델 연결
3. 지식 자료 관리
4. 문의 접수
5. 답변 초안 생성
6. 근거 확인
7. 검토와 승인
8. 처리 이력
9. 코파일럿 질의
10. 내부망 공유
11. 데이터 보호

`중복 점검과 백업` 장면은 시연에서 제외했습니다. 시연 데이터와 일부 대기 구간을 줄인 편집이 포함되어 있어 영상 길이를 실제 업무 처리 시간이나 모델 응답 속도 측정값으로 사용할 수는 없습니다.

| 별도 전달 자료 | 구성 |
| --- | --- |
| `VOC_Mate_LLM_Full_System_Demo.mp4` | 1920×1080, 약 2분 58초(178.492초), 한국어 근거 확인 반영 |
| `VOC_Mate_발표자료_최종본.pptx` | 15장, 사용 기술 장표 추가, 최신 시연 한 편 삽입 |
| `VOC_Mate_장표별_발표문.pdf` | 15쪽, 장표별 낭독용 원고와 전환 문장; PPT 설명문에 넣지 않고 별도 제공 |

위 발표·영상 파일은 별도로 전달한 자료이며 이 저장소의 다운로드 항목으로 게시하지 않았습니다. 최종 영상의 SHA-256 해시와 편집·검증 기록은 [한국어 근거 표시 검증 문서](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/evidence-korean-validation-2026-10-21.md)에 있습니다.

### 한국어 원문 근거

현재 버전은 한국어 Word 매뉴얼과 한국어 공식 메일 매뉴얼의 원문을 표시합니다. 알림 설정은 `brityworks_매뉴얼3.docx`의 11.2절을 사용하며, 표의 예외 조건과 원본 이미지도 유지합니다. 이전 영상에서 사용했던 영어 원문과 그 번역 표시 기능은 이번 버전에서 제거했습니다.

이미지 자동 인식 글자는 본문과 구분하여 원본 대조가 필요함을 표시합니다. 도표의 단독 알파벳 표식은 대응 설명이 있는 경우에만 정리하고 일반 목록과 코드는 보존합니다.

## 개발 환경과 빌드

아래 명령은 최신 작업 브랜치를 대상으로 합니다. 검증에 사용한 Flutter 버전은 **3.47.2**입니다. Windows 빌드에는 Windows와 해당 네이티브 개발 도구, Android 빌드에는 Android 개발 도구가 필요하며, 검증 워크플로는 Java 21을 사용합니다.

```bash
git clone --branch work/korean-manual-retrieval https://github.com/woodeastern2-pixel/ModelY.git
cd ModelY
flutter doctor
flutter pub get
flutter devices
```

Windows에서 실행:

```bash
flutter run -d windows
```

Android는 `flutter devices`에 표시된 실제 장치 ID로 `flutter run -d <device-id>`를 실행합니다.

```bash
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release
```

Windows의 Qwen 포함 배포를 재현하려면 Windows 빌드 후 다음 명령으로 모델과 실행 엔진을 배치합니다. 이 단계에는 Python과 다운로드 가능한 네트워크 환경이 필요합니다.

```bash
python tool/prepare_bundled_qwen.py build/windows/x64/runner/Release/local_ai
```

스크립트는 고정된 모델·실행 엔진 파일의 해시를 검증하고 라이선스·모델 카드를 함께 배치합니다. 일반 `flutter build windows`만으로 모델 다운로드·포함이 완료되는 것은 아닙니다.

- Windows 실행 파일: `build/windows/x64/runner/Release/ai_voc_assistant.exe`
- Android 설치 파일: `build/app/outputs/flutter-apk/app-release.apk`
- 기여·검증 규약: [AGENTS.md](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/AGENTS.md)

## 이전 버전 검증 기록

현재 변경의 검증은 [한국어 원문 검색 작업 기록](docs/korean-manual-retrieval-scope.md)과 [플랫폼 검증 워크플로](https://github.com/woodeastern2-pixel/ModelY/actions/workflows/korean-manual-release.yml)에서 확인할 수 있습니다. 아래는 이전 배포의 기록입니다.

아래는 **2026-10-21 앱 소스 `c1e4d2c` 및 동일 앱 소스를 포함한 배포 빌드 `8e2aa49`의 기록**입니다. 이후 변경의 결과나 모든 업무 질문에 대한 정확도 보장을 뜻하지 않습니다.

| 항목 | 확인 결과 |
| --- | --- |
| 정적 분석 | 기존 진단 98건 유지, 새 진단 0건 |
| 회귀 검사 | 225건 통과; 화면 10개 크기·텍스트 배율 조합과 내비게이션 검사 포함 |
| 화면 추가 감사 | 추가 검사 16건 통과; 수정 전후 휴대폰·태블릿·데스크톱 이미지가 동일하고 신규 픽셀 차이 0 |
| 기존 승인 이미지 | 대시보드 기준 이미지 3장의 기존 불일치가 남아 있으며 기준 이미지를 임의 갱신하지 않음 |
| 배포 | Windows·Android 릴리스 빌드, 파일 존재 확인, 산출물 업로드 성공 |
| 영상 | 실제 한국어 근거 화면 재촬영, 전체 디코딩 검사, 영문 잔상 제거 확인 |

[검증·빌드 실행](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800) · [검증 상세와 남은 항목](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/evidence-korean-validation-2026-10-21.md)

## 데이터 처리와 운영

문의·답변·지식·설정은 로컬 데이터베이스에 저장합니다. Windows 내장 Qwen은 해당 PC의 인증된 루프백 연결에서 추론하며, 외부 모델 서버가 필요하지 않습니다. Ollama는 사용자가 설정한 서버 주소에 연결합니다.

OpenAI·Gemini·Claude를 선택하면 답변 생성에 필요한 텍스트가 해당 외부 서비스로 전송됩니다. 외부 AI 요청 전 이메일·전화번호·주민등록번호 형식·카드번호 형식·일부 이름 표식을 패턴 기반으로 마스킹하며, 원본 로컬 자료는 변경하지 않습니다. 이 처리가 모든 개인정보를 탐지하거나 제거하는 것은 아닙니다.

내부망 공유 및 JIRA·Confluence·Outlook·Teams/Slack 연동은 설정에 따른 네트워크 통신을 사용합니다. 로컬 모델 사용만으로 앱의 모든 외부 통신이 차단되는 것은 아닙니다. 생성된 답변은 근거 확인과 담당자 검토를 거쳐 사용하세요.

## 운영 문서와 주요 코드

아래 링크는 최신 구현이 있는 작업 브랜치를 가리킵니다.

- [내장 Qwen 구성·배포 재현](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/bundled_qwen.md)
- [개인정보와 AI 데이터 처리](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/privacy_and_ai_data_policy.md)
- [내부망 동기화 운영](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/sync-operations.md) · [배포 점검표](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/sync-rollout-checklist.md)
- [시연 모델·응답 검증](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/demo-video-quality-validation-2026-10-21.md) · [최종 한국어 근거·영상·빌드 검증](https://github.com/woodeastern2-pixel/ModelY/blob/work/voc-mate-quality-recording/docs/evidence-korean-validation-2026-10-21.md)
- [화면·ViewModel](https://github.com/woodeastern2-pixel/ModelY/tree/work/voc-mate-quality-recording/lib/presentation) · [업무 모델·계약](https://github.com/woodeastern2-pixel/ModelY/tree/work/voc-mate-quality-recording/lib/domain) · [저장·검색·AI·연동](https://github.com/woodeastern2-pixel/ModelY/tree/work/voc-mate-quality-recording/lib/data)
- [회귀 검사](https://github.com/woodeastern2-pixel/ModelY/tree/work/voc-mate-quality-recording/test) · [실제 앱 통합 검사](https://github.com/woodeastern2-pixel/ModelY/tree/work/voc-mate-quality-recording/integration_test) · [GitHub Actions](https://github.com/woodeastern2-pixel/ModelY/tree/work/voc-mate-quality-recording/.github/workflows)
