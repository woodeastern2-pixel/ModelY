#!/usr/bin/env bash
set -euo pipefail
demo_mode="$1"
mkdir -p artifacts
export LIBGL_ALWAYS_SOFTWARE=1
export GDK_BACKEND=x11
export XDG_DATA_HOME="$PWD/.demo-data/$demo_mode"
export XDG_CONFIG_HOME="$PWD/.demo-config/$demo_mode"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
# This is an isolated runner, never an end-user database.
find .dart_tool -maxdepth 3 -name '*.db' -delete
openbox --sm-disable > "artifacts/$demo_mode-window-manager.log" 2>&1 &
flutter test integration_test/desktop_demo_test.dart -d linux \
  --dart-define="DEMO_MODE=$demo_mode" --reporter expanded \
  2>&1 | tee "artifacts/$demo_mode-driver.log"
