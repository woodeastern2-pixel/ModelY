#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT_DIR/build_logs/voc_sync_receiver.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "voc_sync_receiver is not running (no pid file)"
  exit 0
fi

PID="$(cat "$PID_FILE" || true)"
if [[ -z "${PID:-}" ]]; then
  rm -f "$PID_FILE"
  echo "pid file was empty; cleaned"
  exit 0
fi

if kill -0 "$PID" >/dev/null 2>&1; then
  kill "$PID"
  echo "stopped voc_sync_receiver (pid=$PID)"
else
  echo "process not found (pid=$PID), cleaning pid file"
fi

rm -f "$PID_FILE"
