#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/build_logs/voc_sync_receiver.pid"
LOG_FILE="$ROOT_DIR/build_logs/voc_sync_receiver.log"

if [[ ! -f "$PID_FILE" ]]; then
  echo "status: stopped"
  exit 0
fi

PID="$(cat "$PID_FILE" || true)"
if [[ -n "${PID:-}" ]] && kill -0 "$PID" >/dev/null 2>&1; then
  echo "status: running"
  echo "pid: $PID"
  echo "log: $LOG_FILE"
  exit 0
fi

echo "status: stale pid file"
echo "pid file: $PID_FILE"
exit 1
