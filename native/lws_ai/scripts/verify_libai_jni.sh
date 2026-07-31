#!/usr/bin/env bash
# Verify required JNI symbols are exported from libai.so (dynamic table).
#
# When adding or renaming OpenCV detect JNI (*_jni.cpp):
#   1) Add the short method name to REQUIRED below (without Java_com_... prefix).
#   2) Update native/lensinspector/docs/*_NATIVE_API.md.
#   3) Update app/.../NativeBridge.java and App integration (see docs/OPENCV_DETECT_APP_INTEGRATION.md).
#   4) If App must call the symbol, add to scripts/ci/verify-opencv-detect-integration.sh DEX_REQUIRED.
set -euo pipefail

SO="${1:-}"
shift || true
if [[ -z "$SO" ]]; then
  echo "Usage: $0 /path/to/libai.so [--skip-edgedrawing]" >&2
  exit 1
fi
if [[ ! -f "$SO" ]]; then
  echo "verify_libai_jni: file not found: $SO" >&2
  echo "  Build on Linux/WSL: LIB_VERSION=v1.2.5 bash build_android.sh" >&2
  exit 1
fi

JNI_PREFIX="Java_com_lasercyber_lws_ai_NativeBridge_"
CORE_REQUIRED=(
  nativeCreate
  nativeDestroy
  nativeStart
  nativeRknnStainDetectFromStream
  nativeSetLaserOn
  nativeSetStreamDetectLaserOn
  nativeSetStreamDetectBurstMode
  nativeSetStreamDetectZeroPointTargetMode
  nativeIsStreamDetectRunning
  nativeSetStreamDetectListener
  nativeConfigureStreamDetect
  nativeStartStreamDetect
  nativeStopStreamDetect
  nativeSetAiVisionPreviewDetectionEnabled
  nativeCreateOpencvStainDetectSession
  nativeDestroyOpencvStainDetectSession
  nativeOpencvStainDetectFromJpg
  nativeOpencvStainDetectFromRgb
  nativeOpencvStainDetectFromNv12
  nativeCreateOpencvZeroPointDetector
  nativeDestroyOpencvZeroPointDetector
  nativeSetOpencvZeroPointDetectTargetMode
  nativeOpencvZeroPointDetectFromJpg
  nativeOpencvZeroPointDetectFromRgb
  nativeOpencvZeroPointDetectFromNv12
  nativeRknnStainDetectFromJpgAndSave
  nativeRknnStainDetectFromJpg
  nativeRknnStainDetectFromNv12
  nativeRknnStainDetectFromRgb
  nativeRknnStainDetectFromVideoAndSave
)

# EdgeDrawing JNI is omitted when libai.so is built with -DENABLE_EDGEDRAWING=OFF.
# Set VERIFY_LIBAI_SKIP_EDGEDRAWING=1 (or pass --skip-edgedrawing) to skip these symbols.
EDGEDRAWING_REQUIRED=(
  nativeCreateOpencvEdgeDrawingDetector
  nativeDestroyOpencvEdgeDrawingDetector
  nativeOpencvEdgeDrawingDetectFromJpg
  nativeOpencvEdgeDrawingDetectFromRgb
  nativeOpencvEdgeDrawingDetectFromNv12
)

SKIP_EDGEDRAWING="${VERIFY_LIBAI_SKIP_EDGEDRAWING:-0}"
for arg in "$@"; do
  if [[ "$arg" == "--skip-edgedrawing" ]]; then
    SKIP_EDGEDRAWING=1
  fi
done

REQUIRED=("${CORE_REQUIRED[@]}")
if [[ "$SKIP_EDGEDRAWING" != "1" ]]; then
  REQUIRED+=("${EDGEDRAWING_REQUIRED[@]}")
fi

pick_nm() {
  if [[ -n "${NM:-}" ]] && command -v "$NM" >/dev/null 2>&1; then
    echo "$NM"
    return
  fi
  if [[ -n "${ANDROID_NDK_PATH:-}" ]]; then
    local llvm_nm=""
    llvm_nm="$(find "${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt" -name llvm-nm -type f 2>/dev/null | head -1)"
    if [[ -n "$llvm_nm" ]]; then
      echo "$llvm_nm"
      return
    fi
  fi
  command -v nm
}

NM_BIN="$(pick_nm)" || {
  echo "verify_libai_jni: nm/llvm-nm not found (set NM or ANDROID_NDK_PATH)" >&2
  exit 1
}

SYMFILE="$(mktemp)"
trap 'rm -f "$SYMFILE"' EXIT

# Write one JNI symbol per line; never stash full nm output in a shell variable.
"$NM_BIN" -D "$SO" 2>/dev/null \
  | tr -d '\r' \
  | sed -n "s/.*\\(${JNI_PREFIX}[A-Za-z0-9_]*\\).*/\\1/p" \
  | sed 's/@@.*$//' \
  | sort -u > "$SYMFILE"

if [[ ! -s "$SYMFILE" && -n "${ANDROID_NDK_PATH:-}" ]]; then
  LLVM_NM="$(find "${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt" -name llvm-nm -type f 2>/dev/null | head -1)"
  if [[ -n "$LLVM_NM" && "$LLVM_NM" != "$NM_BIN" ]]; then
    NM_BIN="$LLVM_NM"
    "$NM_BIN" -D "$SO" 2>/dev/null \
      | tr -d '\r' \
      | sed -n "s/.*\\(${JNI_PREFIX}[A-Za-z0-9_]*\\).*/\\1/p" \
      | sed 's/@@.*$//' \
      | sort -u > "$SYMFILE"
  fi
fi

if [[ ! -s "$SYMFILE" ]]; then
  echo "verify_libai_jni: no ${JNI_PREFIX}* in dynamic symbol table: $SO" >&2
  echo "  nm used: $NM_BIN" >&2
  "$NM_BIN" -D "$SO" 2>/dev/null | head -5 >&2 || true
  exit 1
fi

missing=()
for name in "${REQUIRED[@]}"; do
  name="${name//$'\r'/}"
  want="${JNI_PREFIX}${name}"
  if ! grep -qxF "$want" "$SYMFILE"; then
    missing+=("$name")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "verify_libai_jni: missing JNI export(s) in $SO:" >&2
  for m in "${missing[@]}"; do
    printf '  - %s (%s%s)\n' "$m" "$JNI_PREFIX" "$m" >&2
  done
  echo "Exported ${JNI_PREFIX}* (from nm -D):" >&2
  cat "$SYMFILE" >&2
  exit 1
fi

echo "verify_libai_jni: OK (${#REQUIRED[@]} symbols) in $SO (nm=$NM_BIN)"
