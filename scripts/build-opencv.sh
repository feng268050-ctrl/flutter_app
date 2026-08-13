#!/usr/bin/env bash
# Cross-compile OpenCV (sources from make fetch-opencv) → prebuilt/opencv/linux-arm64.
# Used by native/lws_ai CMake (-DOPENCV_PATH=…/lib/cmake/opencv4).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/third-party/opencv.version"
CACHE_DIR="$ROOT/.cache/opencv"
OUT_DIR="$ROOT/prebuilt/opencv/linux-arm64"
BUILD_DIR="$CACHE_DIR/build-linux-arm64"
FORCE="${FORCE:-0}"
VERSION="$(read_version_file "$VERSION_FILE" "4.5.5")"
SRC_DIR="$CACHE_DIR/opencv-${VERSION}"
CONTRIB_DIR="$CACHE_DIR/opencv_contrib-${VERSION}"

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

if prebuilt_ready "$OUT_DIR" && [[ -f "$OUT_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]] && [[ "$FORCE" != "1" ]]; then
  echo "build-opencv: prebuilt ready at $OUT_DIR"
  exit 0
fi

if [[ "$(uname -s)" == Darwin ]] && [[ "${DOCKER:-}" != "1" ]]; then
  exec env SKIP_OVERLAY=1 FORCE="$FORCE" \
    bash "$ROOT/scripts/docker-run.sh" \
    bash /work/lws-hmi/scripts/build-opencv.sh
fi

bash "$ROOT/scripts/fetch-opencv.sh"

if [[ ! -d "$SRC_DIR" ]]; then
  mkdir -p "$CACHE_DIR"
  tar -xzf "$CACHE_DIR/opencv-${VERSION}.tar.gz" -C "$CACHE_DIR"
fi
if [[ ! -d "$CONTRIB_DIR" ]]; then
  tar -xzf "$CACHE_DIR/opencv_contrib-${VERSION}.tar.gz" -C "$CACHE_DIR"
fi

CC="$(find_cross_gcc)" || {
  echo "ERROR: aarch64 cross gcc not found (linux-sdk prebuilts or Buildroot host). Run make setup / lunch." >&2
  exit 1
}
CXX="${CC%-gcc}-g++"
[[ -x "$CXX" ]] || {
  echo "ERROR: matching g++ missing for $CC" >&2
  exit 1
}
SYSROOT="$(cd "$(dirname "$CC")/../aarch64-none-linux-gnu/libc" 2>/dev/null && pwd || true)"
if [[ -z "$SYSROOT" || ! -d "$SYSROOT" ]]; then
  # Linaro layout
  SYSROOT="$(cd "$(dirname "$CC")/../aarch64-linux-gnu/libc" 2>/dev/null && pwd || true)"
fi

TOOLCHAIN_FILE="$BUILD_DIR/aarch64-toolchain.cmake"
mkdir -p "$BUILD_DIR"
cat >"$TOOLCHAIN_FILE" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER ${CC})
set(CMAKE_CXX_COMPILER ${CXX})
EOF
if [[ -n "$SYSROOT" && -d "$SYSROOT" ]]; then
  cat >>"$TOOLCHAIN_FILE" <<EOF
set(CMAKE_SYSROOT ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF
fi

echo "build-opencv: CC=$CC VERSION=$VERSION"
rm -rf "$BUILD_DIR/cmake"
mkdir -p "$BUILD_DIR/cmake" "$OUT_DIR"

cmake -S "$SRC_DIR" -B "$BUILD_DIR/cmake" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$OUT_DIR" \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_TESTS=OFF \
  -DBUILD_PERF_TESTS=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_opencv_apps=OFF \
  -DBUILD_opencv_python2=OFF \
  -DBUILD_opencv_python3=OFF \
  -DBUILD_opencv_java=OFF \
  -DWITH_GTK=OFF \
  -DWITH_QT=OFF \
  -DWITH_FFMPEG=OFF \
  -DWITH_GSTREAMER=OFF \
  -DWITH_CUDA=OFF \
  -DWITH_OPENCL=OFF \
  -DWITH_IPP=OFF \
  -DWITH_TBB=OFF \
  -DWITH_V4L=OFF \
  -DOPENCV_EXTRA_MODULES_PATH="$CONTRIB_DIR/modules" \
  -DBUILD_LIST=core,imgproc,imgcodecs,videoio,dnn,calib3d,features2d,flann

cmake --build "$BUILD_DIR/cmake" -j"${BUILD_JOBS:-8}"
cmake --install "$BUILD_DIR/cmake"

[[ -f "$OUT_DIR/lib/cmake/opencv4/OpenCVConfig.cmake" ]] || {
  # Some installs use lib64 or share path
  if [[ -f "$OUT_DIR/share/opencv4/OpenCVConfig.cmake" ]]; then
    mkdir -p "$OUT_DIR/lib/cmake/opencv4"
    ln -sfn ../../../share/opencv4/OpenCVConfig.cmake "$OUT_DIR/lib/cmake/opencv4/OpenCVConfig.cmake"
    ln -sfn ../../../share/opencv4/OpenCVConfig-version.cmake "$OUT_DIR/lib/cmake/opencv4/OpenCVConfig-version.cmake" 2>/dev/null || true
  else
    echo "ERROR: OpenCVConfig.cmake missing after install under $OUT_DIR" >&2
    find "$OUT_DIR" -name 'OpenCVConfig.cmake' 2>/dev/null | head -20 >&2 || true
    exit 1
  fi
}

prebuilt_stamp "$OUT_DIR" "opencv-${VERSION}-linux-arm64"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh" 2>/dev/null || true
echo "build-opencv: done → $OUT_DIR"
