#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts
export LIBGL_ALWAYS_SOFTWARE=1
export GDK_BACKEND=x11
export XDG_DATA_HOME="$PWD/.demo-data/full-system"
export XDG_CONFIG_HOME="$PWD/.demo-config/full-system"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
openbox --sm-disable > artifacts/window-manager.log 2>&1 &
python3 tool/prepare_full_demo.py
flutter test test/recording_peer_test.dart --reporter expanded > artifacts/peer.log 2>&1 &
peer_process=$!
trap 'touch artifacts/peer-stop; kill "$peer_process" 2>/dev/null || true' EXIT
for attempt in {1..120}; do
  if test -f artifacts/peer-ready; then break; fi
  if ! kill -0 "$peer_process" 2>/dev/null; then cat artifacts/peer.log; exit 1; fi
  sleep 1
done
test -f artifacts/peer-ready
flutter test integration_test/desktop_demo_test.dart -d linux \
  --dart-define=DEMO_MODE=llm --reporter expanded \
  2>&1 | tee artifacts/full-system-driver.log
touch artifacts/peer-stop
wait "$peer_process"
