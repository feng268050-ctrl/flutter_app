#!/usr/bin/env bash
# Cross-compile native/lws_ai → prebuilt/ai/linux-arm64 (lws_ai_daemon + libs).
# First-party product build (app-like): plain make build-ai is always incremental;
# FORCE=1 / make rebuild-ai wipes the CMake tree then full configure + build + restage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

SRC="$ROOT/native/lws_ai"
OUT_DIR="$ROOT/prebuilt/ai/linux-arm64"
CACHE_ROOT="$ROOT/.cache/lws_ai"
BUILD_DIR="$CACHE_ROOT/build-linux-arm64"
CMAKE_DIR="$BUILD_DIR/cmake"
FINGERPRINT_FILE="$CACHE_ROOT/configure.fingerprint"
OPENCV_DIR="$ROOT/prebuilt/opencv/linux-arm64"
RKNN_SO="$ROOT/prebuilt/rknn-rt/aarch64/librknnrt.so"
RKNN_INC="$ROOT/prebuilt/rknn-rt/include"
RKNN_RT_PATH="$ROOT/prebuilt/rknn-rt/aarch64"
XIMG="$ROOT/.cache/opencv/ximgproc-ed"
FORCE="${FORCE:-0}"
AI_VERSION="${AI_VERSION:-0.0.0-dev}"

find_cross_gcc() {
  local sdk="${SDK_DIR:-$ROOT/linux-sdk}"
  local cand
  for cand in \
    "$sdk/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-gcc" \
    "$sdk/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-gcc"
  do
    if [[ -x "$cand" ]]; then
      echo "$cand"
      return 0
    fi
  done
  local br
  br="$(resolve_br_output_dir "$sdk" 2>/dev/null || true)"
  if [[ -n "$br" && -d "$br/host/bin" ]]; then
    for cand in "$br/host/bin/"*-linux-gnu-gcc "$br/host/bin/"*-linux-gcc; do
      [[ -x "$cand" ]] || continue
      echo "$cand"
      return 0
    done
  fi
  return 1
}

# Configure fingerprint: toolchain + OpenCV/RKNN inputs + key -D options.
# Written under .cache/lws_ai/ after a successful configure/build/restage.
ai_configure_fingerprint() {
  cat <<EOF
CC=${CC}
CXX=${CXX}
OBJCOPY=${OBJCOPY}
STRIP=${STRIP}
SYSROOT=${SYSROOT:-}
OPENCV_CMAKE=${OPENCV_CMAKE}
RKNN_SO=${RKNN_SO}
RKNN_RT_PATH=${RKNN_RT_PATH}
XIMG=${XIMG}
AI_VERSION=${AI_VERSION}
CMAKE_BUILD_TYPE=Release
BUILD_LIBAI=OFF
BUILD_LWS_AI_DAEMON=ON
ENABLE_STREAM_DETECT_NDK_FALLBACK=OFF
BUILD_RKNN_STAIN_DETECT_PP_SMOKE_TEST=OFF
BUILD_OPENCV_DETECT_CODES_SMOKE_TEST=OFF
BUILD_RKNN_INFER=OFF
BUILD_OPENCV_STAIN_DETECT_INFER=OFF
BUILD_ZERO_POINT_INFER=OFF
BUILD_EDGEDRAWING_INFER=OFF
BUILD_RKNN_MEM_DEMO=OFF
EOF
}

if [[ "$(uname -s)" == Darwin ]] && [[ "${DOCKER:-}" != "1" ]]; then
  # docker-run only forwards selected -e vars; pass FORCE/AI_VERSION on the remote argv.
  exec env SKIP_OVERLAY=1 \
    bash "$ROOT/scripts/docker-run.sh" \
    env "FORCE=${FORCE}" "AI_VERSION=${AI_VERSION}" \
    bash /work/lws-hmi/scripts/build-ai.sh
fi

[[ -f "$SRC/CMakeLists.txt" ]] || {
  echo "ERROR: missing $SRC (vendor native/lws_ai)" >&2
  exit 1
}

if [[ ! -f "$OPENCV_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" && ! -f "$OPENCV_DIR/share/opencv4/OpenCVConfig.cmake" ]]; then
  echo "build-ai: OpenCV prebuilt missing — running make build-opencv ..."
  bash "$ROOT/scripts/build-opencv.sh"
fi

OPENCV_CMAKE="$OPENCV_DIR/lib/cmake/opencv4"
if [[ ! -f "$OPENCV_CMAKE/OpenCVConfig.cmake" ]]; then
  OPENCV_CMAKE="$OPENCV_DIR/share/opencv4"
fi
[[ -f "$OPENCV_CMAKE/OpenCVConfig.cmake" ]] || {
  echo "ERROR: OpenCVConfig.cmake not found under $OPENCV_DIR (run: make build-opencv)" >&2
  exit 1
}

[[ -f "$RKNN_SO" && -f "$RKNN_INC/rknn_api.h" ]] || {
  echo "ERROR: RKNN runtime missing ($RKNN_SO). Run: make fetch-rknn-rt" >&2
  exit 1
}

bash "$ROOT/scripts/fetch-opencv-ximgproc.sh"
[[ -f "$XIMG/src/edge_drawing.cpp" ]] || {
  echo "ERROR: EdgeDrawing sources missing at $XIMG (run: make fetch-opencv-ximgproc)" >&2
  exit 1
}

CC="$(find_cross_gcc)" || {
  echo "ERROR: aarch64 cross gcc not found" >&2
  exit 1
}
CXX="${CC%-gcc}-g++"
OBJCOPY="${CC%-gcc}-objcopy"
STRIP="${CC%-gcc}-strip"
SYSROOT="$(cd "$(dirname "$CC")/../aarch64-none-linux-gnu/libc" 2>/dev/null && pwd || true)"
if [[ -z "$SYSROOT" || ! -d "$SYSROOT" ]]; then
  SYSROOT="$(cd "$(dirname "$CC")/../aarch64-linux-gnu/libc" 2>/dev/null && pwd || true)"
fi

wipe_cmake=0
if [[ "$FORCE" == "1" ]]; then
  wipe_cmake=1
  echo "build-ai: FORCE=1 — wiping CMake tree at $CMAKE_DIR"
elif [[ -d "$CMAKE_DIR" ]]; then
  if [[ ! -f "$FINGERPRINT_FILE" ]]; then
    wipe_cmake=1
    echo "build-ai: missing configure fingerprint — wiping CMake tree"
  elif ! cmp -s <(ai_configure_fingerprint) "$FINGERPRINT_FILE"; then
    wipe_cmake=1
    echo "build-ai: configure fingerprint mismatch — wiping CMake tree"
  fi
fi

if [[ "$wipe_cmake" == "1" ]]; then
  rm -rf "$CMAKE_DIR"
fi

TOOLCHAIN_FILE="$BUILD_DIR/aarch64-toolchain.cmake"
mkdir -p "$BUILD_DIR" "$CMAKE_DIR" "$OUT_DIR/lib"
cat >"$TOOLCHAIN_FILE" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER ${CC})
set(CMAKE_CXX_COMPILER ${CXX})
set(CMAKE_OBJCOPY ${OBJCOPY})
set(CMAKE_STRIP ${STRIP})
EOF
if [[ -n "$SYSROOT" && -d "$SYSROOT" ]]; then
  cat >>"$TOOLCHAIN_FILE" <<EOF
set(CMAKE_SYSROOT ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${SYSROOT};${OPENCV_DIR})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
EOF
fi

echo "build-ai: CC=$CC AI_VERSION=$AI_VERSION (incremental cmake under $CMAKE_DIR)"

cmake -S "$SRC" -B "$CMAKE_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLIB_VERSION="$AI_VERSION" \
  -DOPENCV_PATH="$OPENCV_CMAKE" \
  -DRKNN_RT_PATH="$RKNN_RT_PATH" \
  -DRKNN_RT_LIB="$RKNN_SO" \
  -DOPENCV_XIMGPROC_ED_DIR="$XIMG" \
  -DBUILD_LIBAI=OFF \
  -DBUILD_LWS_AI_DAEMON=ON \
  -DENABLE_STREAM_DETECT_NDK_FALLBACK=OFF \
  -DBUILD_RKNN_STAIN_DETECT_PP_SMOKE_TEST=OFF \
  -DBUILD_OPENCV_DETECT_CODES_SMOKE_TEST=OFF \
  -DBUILD_RKNN_INFER=OFF \
  -DBUILD_OPENCV_STAIN_DETECT_INFER=OFF \
  -DBUILD_ZERO_POINT_INFER=OFF \
  -DBUILD_EDGEDRAWING_INFER=OFF \
  -DBUILD_RKNN_MEM_DEMO=OFF \
  -DFETCHCONTENT_FULLY_DISCONNECTED=OFF

cmake --build "$CMAKE_DIR" -j"${BUILD_JOBS:-8}" --target lws_ai_daemon

DAEMON_BIN="$CMAKE_DIR/lws_ai_daemon"
[[ -x "$DAEMON_BIN" ]] || {
  echo "ERROR: lws_ai_daemon missing after build" >&2
  exit 1
}

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/lib"
install -m 0755 "$DAEMON_BIN" "$OUT_DIR/lws_ai_daemon"

# Stage OpenCV (+ optional yaml-cpp) beside the install tree for /opt/hmi/lib.
# librknnrt.so stays on the product rootfs at /usr/lib (make fetch-rknn-rt);
# do not duplicate it under /opt/hmi — daemon resolves via the system linker.
copy_so() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  cp -a "$f" "$OUT_DIR/lib/"
}
shopt -s nullglob
for f in "$OPENCV_DIR"/lib/libopencv_*.so*; do
  copy_so "$f"
done
# yaml-cpp is often static via FetchContent; if a .so appears, stage it.
for f in "$CMAKE_DIR"/_deps/yaml-cpp-build/libyaml-cpp.so*; do
  copy_so "$f"
done
shopt -u nullglob
rm -f "$OUT_DIR"/lib/librknnrt.so*
# Leftover third-party stamp (if any) is not a control plane for AI.
rm -f "$OUT_DIR/.lws-prebuilt"

mkdir -p "$CACHE_ROOT"
ai_configure_fingerprint >"$FINGERPRINT_FILE"

bash "$ROOT/scripts/sync-prebuilt-manifest.sh" 2>/dev/null || true
file "$OUT_DIR/lws_ai_daemon" || true
echo "build-ai: done → $OUT_DIR/lws_ai_daemon"
