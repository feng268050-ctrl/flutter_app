#!/usr/bin/env bash
# Batch opencv_stain_detect on a directory of images (native C++ CLI).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LENS="$ROOT/native/lensinspector"
IMAGE_DIR="${1:-}"
OUT_DIR="${2:-}"
DUMP_STAGES="${DUMP_STAGES:-0}"

if [[ -z "$IMAGE_DIR" ]]; then
  echo "Usage: $0 <image-dir> [out-dir]" >&2
  echo "  DUMP_STAGES=1: save per-step images via opencv_stain_detect_infer --dump-stages" >&2
  exit 1
fi

if [[ ! -d "$IMAGE_DIR" ]]; then
  echo "ERROR: image dir not found: $IMAGE_DIR" >&2
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$IMAGE_DIR")/$(basename "$IMAGE_DIR")_opencv_stain_detect"
fi

mkdir -p "$OUT_DIR"

BIN="$LENS/build-host/opencv_stain_detect_infer"

build_native() {
  local opencv_cmake=""
  if [[ -d /opt/homebrew/opt/opencv/lib/cmake/opencv4 ]]; then
    opencv_cmake="/opt/homebrew/opt/opencv/lib/cmake/opencv4"
  elif command -v brew >/dev/null 2>&1; then
    opencv_cmake="$(brew --prefix opencv 2>/dev/null)/lib/cmake/opencv4"
  fi
  [[ -n "$opencv_cmake" && -f "$opencv_cmake/OpenCVConfig.cmake" ]] || return 1
  mkdir -p "$LENS/build-host/rknn-stub/include" "$LENS/build-host/rknn-stub/lib"
  if [[ ! -f "$LENS/build-host/rknn-stub/include/rknn_api.h" ]]; then
    printf '%s\n' '// stub' >"$LENS/build-host/rknn-stub/include/rknn_api.h"
    touch "$LENS/build-host/rknn-stub/lib/librknnrt.so"
  fi
  echo "Building opencv_stain_detect_infer (native) ..."
  cmake -S "$LENS" -B "$LENS/build-host" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DLIB_VERSION=v0.0.0 \
    -DRKNN_RT_PATH="$LENS/build-host/rknn-stub" \
    -DOPENCV_PATH="$opencv_cmake" \
    -DBUILD_RKNN_INFER=OFF \
    -DBUILD_ZERO_POINT_INFER=OFF \
    -DBUILD_PREVIEW_DET_JSON_SMOKE_TEST=OFF \
    -DBUILD_RKNN_STAIN_DETECT_PP_SMOKE_TEST=OFF
  cmake --build "$LENS/build-host" --target opencv_stain_detect_infer -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
}

if [[ ! -x "$BIN" ]]; then
  build_native || true
fi

if [[ ! -x "$BIN" ]]; then
  echo "ERROR: build failed: $BIN" >&2
  exit 1
fi

echo "opencv_stain_detect batch: images=$IMAGE_DIR out=$OUT_DIR dump_stages=$DUMP_STAGES"
ARGS=(--image-dir "$IMAGE_DIR" --out-dir "$OUT_DIR")
if [[ "$DUMP_STAGES" == "1" ]]; then
  ARGS+=(--dump-stages)
fi
"$BIN" "${ARGS[@]}"
echo "Done. See $OUT_DIR/batch_summary.json and $OUT_DIR/overlays/"
