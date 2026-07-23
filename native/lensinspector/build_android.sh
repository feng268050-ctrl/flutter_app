#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# COREDEX — Android NDK r18b 交叉编译脚本 (aarch64)
# 输出: libai_<version>.so  (JNI 共享库)
# ═══════════════════════════════════════════════════════════════
#
# 使用前请设置环境变量:
#   LIB_VERSION       — 输出版本号 (例如 v1.0.0)
#   ANDROID_NDK_PATH  — Android NDK r18b 根目录
#   RKNN_RT_PATH      — RKNPU2 runtime SDK 路径
#   OPENCV_PATH       — OpenCV Android SDK 的 sdk/native/jni 目录（默认 native/toolchains/opencv）
#
# 示例 (Linux):
#   export LIB_VERSION=v1.0.0
#   export ANDROID_NDK_PATH=~/android-ndk-r18b
#   export RKNN_RT_PATH=~/rknpu2/runtime/Android/librknn_api/arm64-v8a
#   export OPENCV_PATH=~/opencv-android-sdk/sdk/native/jni
#   bash build_android.sh
#
# 示例 (WSL — NDK 在 Windows 盘):
#   export ANDROID_NDK_PATH=/mnt/d/Android/android-ndk-r18b
#   ...
# ═══════════════════════════════════════════════════════════════

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${ANDROID_NDK_PATH:?Please set ANDROID_NDK_PATH (e.g. /path/to/android-ndk-r18b)}"
: "${LIB_VERSION:?Please set LIB_VERSION (e.g. v1.0.0)}"
: "${RKNN_RT_PATH:?Please set RKNN_RT_PATH}"
if [[ -z "${OPENCV_PATH:-}" ]]; then
  OPENCV_PATH="$(bash "${REPO_ROOT}/../../scripts/make/opencv-path.sh" 2>/dev/null || true)"
fi
: "${OPENCV_PATH:?Please set OPENCV_PATH or run 'make opencv' from repo root}"

BUILD_DIR="${REPO_ROOT}/build_android"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

CMAKE_EXTRA=()
case "${LENS_INFER_TIMING:-}" in
  1|ON|on|true|TRUE|yes|YES)
    CMAKE_EXTRA+=(-DLENS_INFER_TIMING=ON)
    echo "==> CMake: LENS_INFER_TIMING=ON (infer_stain / DetPostprocess phase logs)"
    ;;
esac

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_PATH}/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DANDROID_STL=c++_shared \
    -DCMAKE_BUILD_TYPE=Release \
    -DRKNN_RT_PATH="${RKNN_RT_PATH}" \
    -DOPENCV_PATH="${OPENCV_PATH}" \
    -DLIB_VERSION="${LIB_VERSION}" \
    "${CMAKE_EXTRA[@]}"

make -j$(nproc)

if [[ ! -f libai.so ]]; then
  echo "ERROR: expected $(pwd)/libai.so after build" >&2
  exit 1
fi

bash "${REPO_ROOT}/scripts/verify_libai_jni.sh" "$(pwd)/libai.so" || exit 1

echo ""
echo "=== Build OK ==="
echo "Output: $(pwd)/libai.so  (LIB_VERSION=${LIB_VERSION} for zip/metadata only)"
echo ""
echo "部署到 Android 项目:"
echo "  cp $(pwd)/libai.so <android-project>/app/src/main/jniLibs/arm64-v8a/"
echo "  cp ${RKNN_RT_PATH}/librknnrt.so <android-project>/app/src/main/jniLibs/arm64-v8a/"
echo "  cp ${ANDROID_NDK_PATH}/sources/cxx-stl/llvm-libc++/libs/arm64-v8a/libc++_shared.so <android-project>/app/src/main/jniLibs/arm64-v8a/"
echo ""
