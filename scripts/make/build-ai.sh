#!/usr/bin/env bash
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
# shellcheck source=ensure-rosetta-host.sh
source "$_SCRIPT_DIR/ensure-rosetta-host.sh"
ensure_rosetta_host_reexec "$0" "$@"

require_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $name" >&2
    return 1
  fi
}

cmake_arch_hint() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    return 0
  fi

  local host_arch
  host_arch="$(uname -m)"

  # When `make ai` re-execs under Rosetta on Apple Silicon, uname -m becomes x86_64.
  if [[ "$host_arch" == "x86_64" ]]; then
    cat >&2 <<'EOF'

Note (Apple Silicon + Rosetta):
  `make ai` runs under Rosetta (darwin-x86_64) so NDK r18b host tools work.
  Ensure CMake is available for x86_64 too (or as a universal binary).

If you installed CMake via Homebrew on Apple Silicon, you may only have arm64 CMake.
In that case, install a universal/x86_64 CMake, or provide an x86_64 cmake on PATH.
EOF
  fi
}

require_working_cmake() {
  if ! require_cmd cmake; then
    cat >&2 <<'EOF'

Install CMake, then retry:
  - macOS (Homebrew): brew install cmake
  - or install via Android Studio / Xcode CLI tools if you prefer

EOF
    return 1
  fi

  # Verify the binary runs under the current host arch (important under Rosetta).
  if ! cmake --version >/dev/null 2>&1; then
    echo "ERROR: 'cmake' exists but failed to run under the current host environment." >&2
    if command -v file >/dev/null 2>&1; then
      echo "cmake binary: $(command -v cmake)" >&2
      file "$(command -v cmake)" >&2 || true
    fi
    cmake_arch_hint
    return 1
  fi
  return 0
}

saved_rknn_rt_path="${RKNN_RT_PATH-}"
saved_opencv_path="${OPENCV_PATH-}"
saved_lib_version="${LIB_VERSION-}"
saved_infer_timing="${INFER_TIMING-}"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT/.env"
  set +a
fi

[[ -n "$saved_rknn_rt_path" ]] && export RKNN_RT_PATH="$saved_rknn_rt_path"
[[ -n "$saved_opencv_path" ]] && export OPENCV_PATH="$saved_opencv_path"
[[ -n "$saved_lib_version" ]] && export LIB_VERSION="$saved_lib_version"
[[ -n "$saved_infer_timing" ]] && export INFER_TIMING="$saved_infer_timing"

export ANDROID_NDK_PATH="$(bash "$ROOT/scripts/make/ndk-r18b-path.sh")"

if [[ -z "${RKNN_RT_PATH:-}" ]]; then
  RKNN_RT_PATH="$(bash "$ROOT/scripts/make/rknn-rt-path.sh")"
  export RKNN_RT_PATH
fi
: "${RKNN_RT_PATH:?set RKNN_RT_PATH to the RKNPU2 Android runtime directory}"

echo "make ai: ANDROID_NDK_PATH=$ANDROID_NDK_PATH"
echo "make ai: RKNN_RT_PATH=$RKNN_RT_PATH"

validate_ndk_mac_prebuilt
warn_if_arm64_cmake_under_rosetta
log_ai_build_host

if ! require_working_cmake; then
  exit 1
fi

export OPENCV_PATH="$(bash "$ROOT/scripts/make/opencv-path.sh")"
chmod +x "$ROOT/scripts/make/fetch-opencv-ximgproc-edgedrawing.sh"
bash "$ROOT/scripts/make/fetch-opencv-ximgproc-edgedrawing.sh"

LIB_VERSION="${LIB_VERSION:-v0.0.0}"
ANDROID_PLATFORM="${AI_ANDROID_PLATFORM:-android-24}"
SRC="$ROOT/native/lensinspector"
BUILD_DIR="$SRC/build_android"
JNI_DIR="$ROOT/app/src/main/jniLibs/arm64-v8a"
AI_LIBRARY="$ROOT/ai-library"
MODELS_DIR="$SRC/assets/models"
DET_ONNX_DEFAULT="$AI_LIBRARY/det_raw_head.onnx"
DET_RKNN_OUT="$AI_LIBRARY/det_raw_head.rknn"
DET_RKNN_EMBED="$MODELS_DIR/det_raw_head.rknn"

if [[ ! -f "$SRC/CMakeLists.txt" ]]; then
  echo "ERROR: missing vendored lensinspector source: $SRC/CMakeLists.txt" >&2
  exit 1
fi

# Main flag: SKIP_RKNN_CONVERT=1 (aligns with SKIP_BUNDLED_FETCH naming).
# Compatibility: AI_SKIP_RKNN_CONVERT=1 behaves the same.
SKIP_RKNN_CONVERT="${SKIP_RKNN_CONVERT:-${AI_SKIP_RKNN_CONVERT:-0}}"

if [[ "${SKIP_RKNN_CONVERT:-0}" != "1" ]]; then
  if [[ ! -d "$AI_LIBRARY" ]]; then
    echo "ERROR: ai-library directory not found: $AI_LIBRARY" >&2
    echo "Place det_raw_head.onnx + calibration assets under ai-library/, or set SKIP_RKNN_CONVERT=1." >&2
    exit 1
  fi
  if [[ ! -f "$DET_ONNX_DEFAULT" && -z "${RKNN_ONNX:-}" ]]; then
    echo "ERROR: missing default ONNX: $DET_ONNX_DEFAULT" >&2
    echo "Place det_raw_head.onnx under ai-library/, or set RKNN_ONNX to an onnx under ai-library/." >&2
    exit 1
  fi

  echo "make ai: converting ONNX → RKNN via Docker (linux/amd64) ..."
  chmod +x "$ROOT/scripts/make/convert-rknn.sh" "$ROOT/scripts/make/fetch-rknn-toolkit.sh"
  RKNN_OUTPUT="$DET_RKNN_OUT" bash "$ROOT/scripts/make/convert-rknn.sh"

  mkdir -p "$MODELS_DIR"
  cp -f "$DET_RKNN_OUT" "$DET_RKNN_EMBED"
  echo "make ai: embedded model updated: $DET_RKNN_EMBED"
else
  echo "make ai: SKIP_RKNN_CONVERT=1 (skipping ONNX→RKNN; using existing $DET_RKNN_EMBED)"
fi

jobs() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
    return
  fi
  if command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu
    return
  fi
  echo 1
}

# Bash 3.2 + `set -u`: ensure the array is declared on all paths.
declare -a CMAKE_EXTRA=()
case "${INFER_TIMING:-0}" in
  1|ON|on|true|TRUE|yes|YES)
    CMAKE_EXTRA+=(-DLENS_INFER_TIMING=ON)
    ;;
esac

# Bash 3.2 + `set -u`: expanding an empty array via "${arr[@]}" can still trip nounset.
declare -a CMAKE_ARGS=(
  -S "$SRC"
  -B "$BUILD_DIR"
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_PATH/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a
  -DANDROID_PLATFORM="$ANDROID_PLATFORM"
  -DANDROID_STL=c++_shared
  -DCMAKE_BUILD_TYPE=Release
  -DRKNN_RT_PATH="$RKNN_RT_PATH"
  -DOPENCV_PATH="$OPENCV_PATH"
  -DLIB_VERSION="$LIB_VERSION"
  # CMake 4+ drops compatibility with very old cmake_minimum_required() values
  # in some third-party projects (e.g. yaml-cpp 0.8.0). This opts into a
  # baseline policy set so configuration can proceed.
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
)
if ((${#CMAKE_EXTRA[@]} > 0)); then
  CMAKE_ARGS+=("${CMAKE_EXTRA[@]}")
fi

if MPP_PATHS="$(bash "$ROOT/scripts/make/rockchip-mpp-path.sh" 2>/dev/null)"; then
  # shellcheck disable=SC1090
  eval "$MPP_PATHS"
  echo "make ai: ENABLE_ROCKCHIP_MPP=ON include=$ROCKCHIP_MPP_INCLUDE_DIR lib=$ROCKCHIP_MPP_LIB"
  CMAKE_ARGS+=(
    -DENABLE_ROCKCHIP_MPP=ON
    -DROCKCHIP_MPP_INCLUDE_DIR="$ROCKCHIP_MPP_INCLUDE_DIR"
    -DROCKCHIP_MPP_LIB="$ROCKCHIP_MPP_LIB"
  )
else
  echo "make ai: Rockchip MPP not configured; StreamDetect will use NdkMediaCodec fallback"
  echo "make ai: for RK3566 product builds run: scripts/make/fetch-rockchip-mpp.sh && adb pull /vendor/lib64/libmpp.so native/toolchains/rockchip-mpp/arm64-v8a/lib/"
fi

cmake "${CMAKE_ARGS[@]}"

cmake --build "$BUILD_DIR" --target ai lws_ai_daemon --parallel "$(jobs)"

SO="$BUILD_DIR/libai.so"
if [[ ! -f "$SO" ]]; then
  echo "ERROR: expected $SO after build" >&2
  exit 1
fi
DAEMON_BIN="$BUILD_DIR/lws_ai_daemon"
if [[ ! -f "$DAEMON_BIN" ]]; then
  echo "ERROR: expected $DAEMON_BIN after build" >&2
  exit 1
fi

bash "$SRC/scripts/verify_libai_jni.sh" "$SO"
bash "$ROOT/scripts/make/stage-ai-jni-libs.sh"
bash "$ROOT/scripts/make/stage-ai-daemon.sh"

# Package executable as a fake .so so AGP extracts it to nativeLibraryDir (exec-allowed).
JNI_DIR="$ROOT/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$JNI_DIR"
cp -f "$DAEMON_BIN" "$JNI_DIR/liblws_ai_daemon.so"
chmod 755 "$JNI_DIR/liblws_ai_daemon.so"
echo "staged nativeLibraryDir daemon: $JNI_DIR/liblws_ai_daemon.so"

echo "libai.so: $SO"
echo "lws_ai_daemon: $DAEMON_BIN"
echo "apk jniLibs: $JNI_DIR"
echo "next: make build (native libs are packaged into the APK)"
