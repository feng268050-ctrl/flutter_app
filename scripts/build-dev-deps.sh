#!/usr/bin/env bash
# Download/build P3/P5 host-side deps (OpenCV sources + prebuilt rknn-rt/mediamtx).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/build-opencv.sh"
bash "$ROOT/scripts/build-opencv-ximgproc.sh"
bash "$ROOT/scripts/build-rknn-toolkit.sh"
bash "$ROOT/scripts/build-rknn-rt.sh"
bash "$ROOT/scripts/build-mediamtx.sh"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"

echo "build-dev-deps: opencv/rknn sources in .cache/; rknn-rt + mediamtx in prebuilt/"
