# Sync Operations Guide

이 문서는 앱 수가 4개를 넘어도 동일하게 운영할 수 있도록 작성한 표준 운영 가이드입니다.

## 1) 필수 설정
- 모든 앱에서 동일한 `VOC 동기화 Bearer 토큰`을 설정합니다.
- 송신 앱은 `VOC 동기화 수신 URL 목록`에 대상 앱 주소를 등록합니다.
- 단건 동기화는 `/webhook/voc`, 전체 동기화는 `/webhook/sync/full`로 전송됩니다.

앱 인스턴스명 규칙:
- 권장 포맷: `VOC-{환경}-{역할}-{번호}`
- 예시: `VOC-PROD-HQ-01`, `VOC-PROD-BRANCH-07`, `VOC-DEV-QA-02`
- 번호는 2자리 이상 고정(`01`, `02` ...)하여 정렬/검색 일관성을 유지합니다.

중앙 관리 원본:
- 앱/URL/토큰 정보는 [docs/sync-app-registry-template.csv](docs/sync-app-registry-template.csv) 형식으로 1개 파일에서 관리합니다.
- 송신 앱 설정에 붙여 넣을 URL 목록은 [scripts/sync_registry_to_targets.sh](scripts/sync_registry_to_targets.sh)로 생성합니다.
- 반영 전 정합성 검사는 [scripts/validate_sync_registry.sh](scripts/validate_sync_registry.sh)로 수행합니다.

## 2) 수신기 상시 실행
수신 앱에서 아래 환경변수를 먼저 지정합니다.

```bash
export VOC_SYNC_HOST=0.0.0.0
export VOC_SYNC_PORT=8788
export VOC_SYNC_BEARER_TOKEN='운영토큰'
```

자동 시작 등록:

```bash
cd /workspaces/ModelY
./scripts/install_voc_sync_receiver_autostart.sh /경로/voc_assistant.db
```

상태 확인:

```bash
./scripts/status_voc_sync_receiver.sh
curl -sS http://127.0.0.1:8788/health
```

여러 앱을 동시에 점검할 때:
- 중앙 레지스트리에서 `enabled=true`인 앱만 추출해 점검 대상을 구성합니다.
- 운영/개발 환경은 레지스트리 파일을 분리하여 관리합니다.

## 3) 운영 점검 시나리오
앱 화면에서 점검할 항목:
- 단건 VOC 등록 후 타 앱 동기화 반영
- 전체 VOC/매뉴얼 공유 전송 후 타 앱 반영
- 네트워크 장애 후 `실패 동기화 재시도` 버튼으로 재전송

주기 권장:
- 일일: health, 수신기 프로세스, 재시도 큐 건수 확인
- 주간: 표본 앱 간 단건/전체 동기화 리허설
- 월간: 토큰 교체 리허설(무중단 롤링 교체)

## 4) CLI E2E 점검
로컬 수신기 API를 빠르게 점검할 때 사용합니다.

```bash
cd /workspaces/ModelY
chmod +x scripts/e2e_sync_check.sh
VOC_SYNC_BEARER_TOKEN='운영토큰' ./scripts/e2e_sync_check.sh /tmp/ai_voc_sync_e2e.db
```

검증 항목:
- 토큰 설정 시 무인증 401
- 인증 요청 200
- `voc.created`, `sync.full` 수신 성공
- health `voc_count >= 1`

## 5) 장애 대응
- 재시도 대기 건수는 설정 화면의 `실패 동기화 재시도 (N)`에서 확인합니다.
- 앱 재시작 후에도 대기 큐는 설정 저장소에 유지됩니다.
- 토큰 변경 시 송신/수신 앱 모두 같은 값으로 즉시 동기화해야 합니다.

표준 재시도 정책:
- 앱 내부 즉시 재시도: 지수 백오프 3회
- 실패 큐 수동 재시도: 운영자 확인 후 즉시 1회
- 반복 실패(3회 이상): 수신기 health/API 인증/방화벽 우선 점검
- 장기 실패(30분 이상): 해당 앱 임시 제외 후 운영 공지

## 6) 다수 앱 URL 목록 생성
중앙 레지스트리(csv)에서 활성 앱 URL만 뽑아, 설정 화면의 `VOC 동기화 수신 URL 목록`에 붙여 넣습니다.

```bash
cd /workspaces/ModelY
./scripts/sync_registry_to_targets.sh ./docs/sync-app-registry-template.csv
```

선택 옵션:
- 현재 앱 인스턴스 제외: `./scripts/sync_registry_to_targets.sh ./docs/sync-app-registry-template.csv VOC-PROD-HQ-01`

## 7) 롤아웃 체크리스트
- 실제 운영 반영 순서는 [docs/sync-rollout-checklist.md](docs/sync-rollout-checklist.md)를 사용합니다.
