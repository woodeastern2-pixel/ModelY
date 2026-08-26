#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$USER_SYSTEMD_DIR/ai-voc-sync-receiver.service"
DB_PATH="${1:-$ROOT_DIR/voc_assistant.db}"
HOST="${VOC_SYNC_HOST:-0.0.0.0}"
PORT="${VOC_SYNC_PORT:-8788}"
BEARER_TOKEN="${VOC_SYNC_BEARER_TOKEN:-}"
DESKTOP_NOTIFY="${VOC_SYNC_DESKTOP_NOTIFY:-true}"

mkdir -p "$USER_SYSTEMD_DIR"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AI VOC Sync Receiver
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$ROOT_DIR
Environment=VOC_SYNC_HOST=$HOST
Environment=VOC_SYNC_PORT=$PORT
$(if [[ -n "$BEARER_TOKEN" ]]; then echo "Environment=VOC_SYNC_BEARER_TOKEN=$BEARER_TOKEN"; fi)
Environment=VOC_SYNC_DESKTOP_NOTIFY=$DESKTOP_NOTIFY
ExecStart=$ROOT_DIR/scripts/start_voc_sync_receiver.sh $DB_PATH
ExecStop=$ROOT_DIR/scripts/stop_voc_sync_receiver.sh
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now ai-voc-sync-receiver.service

if command -v loginctl >/dev/null 2>&1; then
  loginctl enable-linger "$USER" >/dev/null 2>&1 || true
fi

echo "installed: $SERVICE_FILE"
echo "service: ai-voc-sync-receiver.service"
echo "check: systemctl --user status ai-voc-sync-receiver.service"
