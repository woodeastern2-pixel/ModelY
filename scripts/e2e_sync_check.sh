#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DB_PATH="${1:-/tmp/ai_voc_sync_e2e.db}"
HOST="${VOC_SYNC_HOST:-127.0.0.1}"
PORT="${VOC_SYNC_PORT:-8788}"
BASE_URL="http://$HOST:$PORT"
TOKEN="${VOC_SYNC_BEARER_TOKEN:-}"

cd "$ROOT_DIR"

cleanup() {
  ./scripts/stop_voc_sync_receiver.sh >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[1/6] start receiver"
./scripts/start_voc_sync_receiver.sh "$DB_PATH"

echo "[2/6] wait health"
for _ in $(seq 1 15); do
  if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "$BASE_URL/health" >/dev/null

echo "[3/6] verify unauthorized request"
if [[ -n "$TOKEN" ]]; then
  code="$(curl -sS -o /tmp/sync_e2e_noauth.out -w '%{http_code}' \
    -X POST "$BASE_URL/webhook/sync/full" \
    -H 'Content-Type: application/json' \
    -d '{"event":"sync.full","source_app":"e2e-check","snapshot":{"vocs":[],"responses":[],"manuals":[]}}')"
  if [[ "$code" != "401" ]]; then
    echo "expected 401 without token, got $code"
    cat /tmp/sync_e2e_noauth.out
    exit 1
  fi
else
  echo "token not set: skip unauthorized check"
fi

echo "[4/6] send voc.created"
VOC_PAYLOAD='{"event":"voc.created","source_app":"e2e-check","voc":{"id":"e2e-voc-1","title":"E2E VOC","content":"sync check","category":"운영문의","customer":"tester","project":"BW서비스운영","priority":"MEDIUM","status":"OPEN","created_at":"2026-07-04T00:00:00","updated_at":"2026-07-04T00:00:00"}}'
AUTH_HEADER=()
if [[ -n "$TOKEN" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer $TOKEN")
fi

code="$(curl -sS -o /tmp/sync_e2e_voc.out -w '%{http_code}' \
  -X POST "$BASE_URL/webhook/voc" \
  -H 'Content-Type: application/json' \
  "${AUTH_HEADER[@]}" \
  -d "$VOC_PAYLOAD")"
if [[ "$code" != "200" ]]; then
  echo "voc webhook failed with $code"
  cat /tmp/sync_e2e_voc.out
  exit 1
fi

echo "[5/6] send sync.full"
FULL_PAYLOAD='{"event":"sync.full","source_app":"e2e-check","sync_mode":"upsert","snapshot":{"vocs":[{"id":"e2e-voc-2","title":"E2E FULL","content":"full sync check","category":"운영문의","customer":"tester","project":"BW서비스운영","priority":"HIGH","status":"OPEN","created_at":"2026-07-04T00:00:00","updated_at":"2026-07-04T00:00:00"}],"responses":[],"manuals":[]}}'
code="$(curl -sS -o /tmp/sync_e2e_full.out -w '%{http_code}' \
  -X POST "$BASE_URL/webhook/sync/full" \
  -H 'Content-Type: application/json' \
  "${AUTH_HEADER[@]}" \
  -d "$FULL_PAYLOAD")"
if [[ "$code" != "200" ]]; then
  echo "full sync failed with $code"
  cat /tmp/sync_e2e_full.out
  exit 1
fi

echo "[6/6] health verify"
HEALTH_JSON="$(curl -fsS "$BASE_URL/health")"
echo "$HEALTH_JSON"
VOC_COUNT="$(echo "$HEALTH_JSON" | sed -n 's/.*"voc_count":\([0-9]\+\).*/\1/p')"
if [[ -z "$VOC_COUNT" || "$VOC_COUNT" -lt 1 ]]; then
  echo "unexpected voc_count: $VOC_COUNT"
  exit 1
fi

echo "E2E sync check passed"
