#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/release_artifacts/latest"
LOCAL_FLUTTER="$ROOT_DIR/.tools/flutter/bin/flutter"
LATEST_APK_NAME="AI_VOC_Assistant-latest.apk"
LATEST_WIN_ZIP_NAME="AI_VOC_Assistant-latest-windows.zip"
CI_WIN_ZIP_NAME="ai_voc_assistant-latest-windows-x64-release.zip"
LATEST_WIN_ARTIFACT_NAME="ai_voc_assistant-latest-windows-x64-release"

mkdir -p "$OUT_DIR"

if [[ -x "$LOCAL_FLUTTER" ]]; then
  FLUTTER="$LOCAL_FLUTTER"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER="$(command -v flutter)"
else
  echo "Flutter is not installed in this environment."
  echo "Install Flutter or place it at $ROOT_DIR/.tools/flutter."
  exit 1
fi

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ROOT_DIR/android-sdk}"

echo "[1/5] Checking Flutter toolchain..."
"$FLUTTER" --version

cd "$ROOT_DIR"

echo "[2/5] Resolving dependencies"
if [[ -f "$ROOT_DIR/.dart_tool/package_config.json" ]]; then
  echo "Dependencies already resolved; skipping pub get"
else
  "$FLUTTER" pub get
fi

echo "[3/5] Building Android APK"
"$FLUTTER" build apk --release --target-platform android-arm64 --no-pub
APK_OUT_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"
# Keep a single stable APK path and always overwrite it.
cp -f "$APK_OUT_DIR/app-release.apk" "$OUT_DIR/$LATEST_APK_NAME"

echo "[4/5] Skipping demo data (not needed for production)"

echo "[5/5] Preparing Windows EXE bundle"
if [[ "$(uname -s)" == "Linux" ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found; cannot fetch Windows EXE artifact automatically."
  else
    REPO_ROOT="$(git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "$REPO_ROOT" ]]; then
      echo "Not inside a git repository; cannot fetch Windows EXE artifact automatically."
    else
      CURRENT_HEAD_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
      # Parse latest successful run with gh --jq to avoid external jq dependency.
      RUN_ID="$(gh run list --workflow build-windows-exe.yml --branch main --limit 20 --json databaseId,conclusion --jq '[.[] | select(.conclusion=="success")][0].databaseId' 2>/dev/null || true)"
      RUN_HEAD_SHA="$(gh run list --workflow build-windows-exe.yml --branch main --limit 20 --json headSha,conclusion --jq '[.[] | select(.conclusion=="success")][0].headSha' 2>/dev/null || true)"

      if [[ -z "${RUN_ID:-}" || "$RUN_ID" == "null" ]]; then
        echo "No successful Windows workflow run found."
        echo "Need GitHub Actions run of .github/workflows/build-windows-exe.yml first."
      else
        TMP_DIR="$(mktemp -d)"
        if gh run download "$RUN_ID" -n "$LATEST_WIN_ARTIFACT_NAME" -D "$TMP_DIR" >/dev/null 2>&1; then
          cp -f "$TMP_DIR/$CI_WIN_ZIP_NAME" "$OUT_DIR/$LATEST_WIN_ZIP_NAME"

          echo "Windows EXE artifact synced from GitHub Actions run: $RUN_ID"
          if [[ -n "${RUN_HEAD_SHA:-}" && "$RUN_HEAD_SHA" != "$CURRENT_HEAD_SHA" ]]; then
            echo "Warning: latest Windows artifact is from commit $RUN_HEAD_SHA, current HEAD is $CURRENT_HEAD_SHA"
            echo "If you need exact same commit EXE, push current changes to main to trigger workflow."
          fi
        else
          echo "Failed to download Windows EXE artifact from run: $RUN_ID"
          echo "Check gh auth scope and workflow artifact availability."
        fi
        rm -rf "$TMP_DIR"
      fi
    fi
  fi
else
  "$FLUTTER" build windows --release
  WIN_SRC="$ROOT_DIR/build/windows/x64/runner/Release"
  if [[ -f "$OUT_DIR/$LATEST_WIN_ZIP_NAME" ]]; then
    unlink "$OUT_DIR/$LATEST_WIN_ZIP_NAME"
  fi
  (cd "$WIN_SRC" && zip -q -r "$OUT_DIR/$LATEST_WIN_ZIP_NAME" .)
fi

echo "Done. Artifacts are in: $OUT_DIR"
echo "Stable local APK path: $OUT_DIR/$LATEST_APK_NAME"
echo "Stable local Windows zip path: $OUT_DIR/$LATEST_WIN_ZIP_NAME"
