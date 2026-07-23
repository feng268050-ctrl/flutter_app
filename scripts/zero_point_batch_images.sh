#!/usr/bin/env bash
# Batch zero_point detect on a directory of images (same C++ as App JNI).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LENS="$ROOT/native/lensinspector"
ROI_JSON="${ROI_JSON:-$ROOT/app/src/main/assets/zero_point_roi.json}"
IMAGE_DIR="${1:-}"
OUT_DIR="${2:-$IMAGE_DIR}"

if [[ -z "$IMAGE_DIR" ]]; then
  echo "Usage: $0 <image-dir> [out-dir]" >&2
  echo "  Default out-dir is the same as image-dir (results under overlays/ + json/)." >&2
  echo "  ROI_JSON=path/to/zero_point_roi.json (optional)" >&2
  exit 1
fi

if [[ ! -d "$IMAGE_DIR" ]]; then
  echo "ERROR: image dir not found: $IMAGE_DIR" >&2
  exit 1
fi

if [[ ! -f "$ROI_JSON" ]]; then
  echo "ERROR: ROI JSON not found: $ROI_JSON" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

BIN="$LENS/build-host/zero_point_infer"
if [[ ! -x "$BIN" ]]; then
  # RKNN stub for cmake configure only (zero_point_infer does not link rknn).
  mkdir -p "$LENS/build-host/rknn-stub/include" "$LENS/build-host/rknn-stub/lib"
  if [[ ! -f "$LENS/build-host/rknn-stub/include/rknn_api.h" ]]; then
    printf '%s\n' '// stub' >"$LENS/build-host/rknn-stub/include/rknn_api.h"
    touch "$LENS/build-host/rknn-stub/lib/librknnrt.so"
  fi
  echo "Building zero_point_infer in Docker (linux/amd64) ..."
  docker run --rm --platform linux/amd64 \
    -v "$LENS:/src" \
    -w /src \
    ubuntu:22.04 \
    bash -lc '
      set -euo pipefail
      apt-get update -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        build-essential cmake git libopencv-dev >/dev/null
      OPENCV_CMAKE="$(dirname "$(find /usr -path "*/cmake/opencv4/OpenCVConfig.cmake" 2>/dev/null | head -1)")")"
      test -n "$OPENCV_CMAKE" && test -f "$OPENCV_CMAKE/OpenCVConfig.cmake"
      cmake -S /src -B /src/build-host \
        -DLIB_VERSION=v0.0.0 \
        -DRKNN_RT_PATH=/src/build-host/rknn-stub \
        -DOPENCV_PATH="$OPENCV_CMAKE" \
        -DBUILD_OPENCV_STAIN_DETECT_INFER=OFF \
        -DBUILD_RKNN_INFER=OFF \
        -DBUILD_PREVIEW_DET_JSON_SMOKE_TEST=OFF
      cmake --build /src/build-host --target zero_point_infer -j"$(nproc)"
    '
fi

if [[ ! -x "$BIN" ]]; then
  echo "ERROR: build failed: $BIN" >&2
  exit 1
fi

echo "zero_point batch: images=$IMAGE_DIR out=$OUT_DIR roi=$ROI_JSON"
"$BIN" --image-dir "$IMAGE_DIR" --roi-json "$ROI_JSON" --out-dir "$OUT_DIR" --tolerance-px 10
echo "Done. See $OUT_DIR/batch_summary.json and $OUT_DIR/overlays/"
