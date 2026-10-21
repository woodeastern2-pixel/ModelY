# 근거 화면 한국어 표시 수정 검증

## 수정 범위

- 영상의 실제 답변이 인용한 `brity-messenger-desktop-020` 및 `raw-messenger-desktop-22`에 원문 대조 한국어 번역을 연결했습니다.
- 원문의 정확한 내용 해시가 일치할 때만 번역을 표시합니다. 사용자가 수정한 문서나 다른 버전의 문서에 잘못된 번역을 씌우지 않습니다.
- 한국어 본문을 기본으로 표시하고 영문 원문·출처·원본 이미지는 별도로 펼쳐 확인합니다. 저장된 원문과 검색 입력은 유지합니다.
- PDF 도표에서 분리된 단독 알파벳 표식은 대응하는 설명이 3개 이상 있을 때 정리합니다. 일반 목록과 코드는 보존합니다.
- 근거 화면에 AI 답변용 서식 제거 함수를 적용하던 경로를 수정하여 원문 URL의 밑줄도 보존합니다.
- 신규 번역 범위는 위 두 인용 항목입니다. 모든 영문 매뉴얼이 번역됐다고 주장하지 않습니다.

## 번역 검토

2020년 PC 매뉴얼 22쪽의 9개 설정을 모두 반영했습니다. 소리 설정은 ‘선택하면 대화창을 보는 동안 소리 끄기’, 알림창 설정은 ‘메시지 내용 표시’라는 원문 의미를 유지합니다. 다른 버전의 한국어 매뉴얼과 내용을 혼합하지 않았습니다.

## 영상 편집

- 기존 실제 Qwen3 4B Instruct 응답과 코파일럿 응답을 보존합니다.
- 06장은 실제 앱의 지식 자료 화면에서 기존 답변이 인용한 정확한 문서를 열어 다시 촬영합니다. 새로운 모델 추론이나 합성 앱 화면을 사용하지 않습니다.
- 07장 시작부에 남은 기존 영문 화면 2.4초를 제거하고 기존 음성은 그대로 유지합니다.
- 01–05, 08–11장 파일은 원본과 SHA-256 해시가 일치해야 합니다.
- 원래 11개 구성과 ‘중복 점검과 백업’ 제외를 유지합니다.

## 검증 상태

- 앱 소스 기준 커밋: `c1e4d2cee3204742a957622893c9a889515e587e`.
- 전체 정적 검사 통과. 기존 진단 98건이며 새 진단은 없습니다.
- 전체 회귀 검사 225건 통과. 화면 10개 크기·배율 조합과 내비게이션 검사 포함.
- 실제 앱 한국어 근거 화면 재촬영 통과: 실행 39588331006, 산출물 12341102961.
- 기존 대시보드 승인 이미지와 불일치가 발견됐습니다. 수정 전 `f549f6f`와 수정 후를 동일한 Flutter 3.47.2 환경에서 대조한 결과 휴대폰·태블릿·데스크톱 실제 이미지가 바이트 단위로 같았습니다. 신규 픽셀 차이는 0이며 승인 이미지는 덮어쓰지 않았습니다. 실행 39589659800의 quality 작업에서 비교 및 추가 검사 16건이 통과했습니다.
- Windows·Android 릴리스 빌드와 산출물 업로드가 모두 성공했습니다. 앱 소스와 테스트가 전체 정적 검사·225건 회귀 검사를 통과한 c1e4d2c와 정확히 같은지 Git 비교로 확인한 후 빌드했습니다.

## 전달 영상

- 파일: `VOC_Mate_LLM_Full_System_Demo.mp4`
- 길이: 178.492초, 1920×1080, H.264/AAC, 7,827,538바이트.
- 전체 디코딩 검사 통과. 2.5초 이상 무음 없음. 11장 구성, 백업 장면 없음.
- SHA-256: `0c6d34d7a7ad8b3a152f2e9944d391e630cd19fbd6ed5e6f40f8caf6387ff872`.
- 06장 한국어 본문 및 출처, 07장 시작부의 영문 잔상 제거를 직접 검수했습니다.


## Git와 환경

- 저장소: `woodeastern2-pixel/ModelY`, 브랜치: `work/voc-mate-quality-recording`.
- 로컬에는 Flutter·Windows·Android SDK와 Git 체크아웃이 없어 연결된 GitHub를 통해 커밋·push하고 Actions로 검사·빌드했습니다.
- 로컬 working tree clean 여부: 해당 없음(API로 반영). 의도한 소스·테스트·촬영/편집 코드·검증 문서만 커밋했습니다.
- 이번 감사용으로 기존 품질 워크플로에 임시 추가했던 승인 이미지 검사 단계는 원래대로 복구합니다. 수정 전후 비교와 재현 증거는 별도 `evidence-release-validation.yml` 및 `audit_evidence_ui_baseline.py`에 보존합니다.
- 마지막 전달 커밋은 검증 문서와 위 임시 단계 복구만 포함합니다. 이미 검증된 앱 소스에는 추가 변경이 없습니다.

## 남은 기존 항목

- 기존 정적 분석 진단 98건(warning/info/deprecated)은 그대로입니다. 이전 실행과 진단 목록을 비교하여 추가·삭제가 모두 0임을 확인했습니다.
- 기존 대시보드 승인 이미지 3장의 불일치는 이번 수정 이전에도 동일합니다. 신규 화면 변화가 없음을 확인했으며 기준 이미지를 임의 갱신하지 않았습니다.
- 한국어 번역은 이번 영상에 실제 인용된 동일 원문 두 항목에만 연결했습니다. 전체 영문 문서의 번역 완료로 확대 해석하면 안 됩니다.


## 배포 산출물

빌드 기준 커밋: `8e2aa4943ff221276988652e0358282da112b626`. [검증·빌드 실행](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800)

- Windows: `build/windows/x64/runner/Release/ai_voc_assistant.exe` 생성과 존재 확인 통과. [배포 ZIP](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800/artifacts/12342600089), 1,943,183,630바이트. 실행에 필요한 DLL 및 기존 내장 Qwen 패키지를 함께 포함합니다.
- Android: `build/app/outputs/flutter-apk/app-release.apk` 생성 확인, 93.7MB. [APK ZIP](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800/artifacts/12341661087), ZIP 55,004,718바이트.
- [수정 전후 화면 비교 증거](https://github.com/woodeastern2-pixel/ModelY/actions/runs/39589659800/artifacts/12340439764)

## 주요 파일

- `lib/data/services/reviewed_manual_translation.dart`: 원문 내용이 일치하는 검수 번역 연결.
- `lib/data/services/manual_content.dart`: 화면 표시용 본문과 원문 분리, 도표 표식 정리.
- `lib/presentation/widgets/manual_content_view.dart`: 한국어 기본 표시와 영문 원문 접기.
- `lib/presentation/screens/voc/ai_answer_screen_v2.dart`: 매뉴얼 원문을 훼손하지 않고 공통 표시 컴포넌트에 전달.
- `test/manual_korean_evidence_test.dart`: 실제 인용 내용, 수정 문서 보존, 한국어 기본 표시와 접힌 원문 검증.
- `integration_test/evidence_pickup_test.dart`, `tool/replace_evidence_chapter.py`: 실제 앱 재촬영과 해당 장면·연결부 편집.

모든 소스 변경과 검증 기록을 위 브랜치에 커밋하고 push했습니다. 마지막 전달 커밋에는 앱 변경이 없어 중복 빌드를 실행하지 않았습니다.
