#!/usr/bin/env bash
# Dump one MediaMetadataRetriever frame on device (ProcessVideoAiSession-compatible) and pull to Desktop.
# Usage:
#   ADB_SERIAL=192.168.0.29:5555 ./scripts/device/dump-retriever-frame.sh [sample_ms] [video_path] [desktop_name]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SERIAL="${ADB_SERIAL:-}"
SAMPLE_MS="${1:-2400}"
VIDEO_PATH="${2:-/storage/emulated/0/lws/movie/2026-05-31/26-05-31_22-58-58.mp4}"
DESKTOP_NAME="${3:-retriever_${SAMPLE_MS}ms_26-05-31_22-58-58.png}"
DEVICE_OUT="/sdcard/lws/debug/${DESKTOP_NAME}"
DESKTOP_OUT="${HOME}/Desktop/${DESKTOP_NAME}"

ADB=(adb)
if [[ -n "$SERIAL" ]]; then
  ADB+=(-s "$SERIAL")
fi

cd "$ROOT"
./gradlew :app:connectedReleaseAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.lasercyber.lws.ui.ai.DumpRetrieverFrameInstrumentedTest#dumpFrameAt2400ms \
  >/tmp/dump-retriever-frame-gradle.log 2>&1

"${ADB[@]}" shell "mkdir -p /sdcard/lws/debug"
# Re-run dump via am instrument if gradle did not leave file (test writes fixed path)
if ! "${ADB[@]}" shell "test -f '$DEVICE_OUT'" 2>/dev/null; then
  DEVICE_OUT="/sdcard/lws/debug/retriever_2400ms_26-05-31_22-58-58.png"
fi

"${ADB[@]}" pull "$DEVICE_OUT" "$DESKTOP_OUT"
ls -la "$DESKTOP_OUT"
echo "Pulled to $DESKTOP_OUT"
