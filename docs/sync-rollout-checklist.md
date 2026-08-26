# Sync Rollout Checklist

## 1) 준비
- 대상 앱 목록을 [docs/sync-app-registry-template.csv](docs/sync-app-registry-template.csv) 형식으로 정리
- 각 환경(prod/dev)별 토큰 별칭 확정
- receiver 포트/방화벽 정책 확정

## 2) 사전 검증
```bash
cd /workspaces/ModelY
chmod +x scripts/validate_sync_registry.sh
./scripts/validate_sync_registry.sh ./docs/sync-app-registry-template.csv
```

## 3) 수신 URL 목록 생성
```bash
cd /workspaces/ModelY
./scripts/sync_registry_to_targets.sh ./docs/sync-app-registry-template.csv VOC-PROD-HQ-01
```
- 출력 결과를 송신 앱의 `VOC 동기화 수신 URL 목록`에 붙여넣기

## 4) 앱별 설정 반영
- 앱 인스턴스 이름 규칙 적용
- VOC 동기화 Bearer 토큰 입력
- 자동 포워딩 ON

## 5) 수신기 자동시작 반영
```bash
cd /workspaces/ModelY
export VOC_SYNC_BEARER_TOKEN='운영토큰'
./scripts/install_voc_sync_receiver_autostart.sh /경로/voc_assistant.db
./scripts/status_voc_sync_receiver.sh
curl -sS http://127.0.0.1:8788/health
```

## 6) E2E 확인
```bash
cd /workspaces/ModelY
VOC_SYNC_BEARER_TOKEN='운영토큰' ./scripts/e2e_sync_check.sh /tmp/ai_voc_sync_e2e.db
```
- 기대 결과: unauthorized 401, authorized 200, health voc_count 증가

## 7) 운영 전환
- 표본 1개 앱에서 단건/전체 동기화 실검
- 장애 시 `실패 동기화 재시도` 수행 절차 공유
- 토큰 교체 일정 공지
