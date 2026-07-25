#!/usr/bin/env bash
# Runtime deps: board stack artifacts + staged sources/libs (libai, flutter, mediamtx).
# Requires make lunch before flutter-engine / flutter-embedded-linux compile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/fetch-opencv.sh"
bash "$ROOT/scripts/fetch-opencv-ximgproc.sh"
bash "$ROOT/scripts/fetch-rknn-rt.sh"
bash "$ROOT/scripts/build-gstreamer.sh"
bash "$ROOT/scripts/build-platform-packages.sh"
bash "$ROOT/scripts/fetch-flutter-engine.sh"
bash "$ROOT/scripts/build-flutter-engine.sh"
bash "$ROOT/scripts/build-flutter-embedded-linux.sh"
bash "$ROOT/scripts/build-mediamtx.sh"
bash "$ROOT/scripts/fetch-btop.sh"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"

echo "build-runtime-deps: ready"
echo "  prebuilt/: flutter-engine, flutter-embedded-linux, mediamtx, btop, rknn-rt, gstreamer/target, platform-packages/target"
echo "  .cache/opencv/: OpenCV sources (→ libai.so)"
echo "  Host build tools: make build-dev-deps  (FLUTTER_SDK, RKNN-Toolkit)"
echo "  All deps: make build-deps  (build-dev-deps + build-runtime-deps)"
echo "  Then: make apply-overlay && make build-rootfs"
