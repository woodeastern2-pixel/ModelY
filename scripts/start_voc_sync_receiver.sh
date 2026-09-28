#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv-sync-receiver"
PYTHON_BIN="${PYTHON_BIN:-python3}"
HOST="${VOC_SYNC_HOST:-0.0.0.0}"
PORT="${VOC_SYNC_PORT:-8788}"
BEARER_TOKEN="${VOC_SYNC_BEARER_TOKEN:-}"
DESKTOP_NOTIFY="${VOC_SYNC_DESKTOP_NOTIFY:-true}"
DB_PATH="${1:-$ROOT_DIR/voc_assistant.db}"
LOG_DIR="$ROOT_DIR/build_logs"
PID_FILE="$LOG_DIR/voc_sync_receiver.pid"
LOG_FILE="$LOG_DIR/voc_sync_receiver.log"
REQ_FILE="$ROOT_DIR/scripts/requirements-sync-receiver.txt"

mkdir -p "$LOG_DIR"

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE" || true)"
  if [[ -n "${PID:-}" ]] && kill -0 "$PID" >/dev/null 2>&1; then
    echo "voc_sync_receiver already running (pid=$PID)"
    echo "log: $LOG_FILE"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "python3 not found"
  exit 1
fi

if [[ ! -d "$VENV_DIR" ]]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet -r "$REQ_FILE"

EXTRA_ARGS=()
if [[ -n "$BEARER_TOKEN" ]]; then
  EXTRA_ARGS+=(--bearer-token "$BEARER_TOKEN")
fi
EXTRA_ARGS+=(--desktop-notify "$DESKTOP_NOTIFY")

nohup "$VENV_DIR/bin/python" "$ROOT_DIR/scripts/voc_sync_receiver.py" \
  --db-path "$DB_PATH" \
  --host "$HOST" \
  --port "$PORT" \
  "${EXTRA_ARGS[@]}" \
  >> "$LOG_FILE" 2>&1 &

PID="$!"
echo "$PID" > "$PID_FILE"

echo "voc_sync_receiver started"
echo "pid: $PID"
echo "host: $HOST"
echo "port: $PORT"
echo "db: $DB_PATH"
echo "auth: $([[ -n \"$BEARER_TOKEN\" ]] && echo 'bearer-enabled' || echo 'disabled')"
echo "desktop_notify: $DESKTOP_NOTIFY"
echo "log: $LOG_FILE"
