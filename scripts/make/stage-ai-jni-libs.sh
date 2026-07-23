#!/usr/bin/env bash
set -euo pipefail

# Stage AI runtime libs for APK packaging (P3: daemon + runtimes; no product libai.so).
#
# Required env:
#   ANDROID_NDK_PATH, RKNN_RT_PATH
# Optional:
#   AI_DAEMON_BIN (defaults to native/lensinspector/build_android/lws_ai_daemon)
#   AI_STAGE_LIBAI=1  — also stage libai.so for instrumented tests / rollback (default 0)
#
# Output:
#   app/src/main/jniLibs/arm64-v8a/*.so
#   app/src/main/assets/config.yaml
#   build/ai/runtime-libs.txt

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/native/lensinspector"
ABI="arm64-v8a"
JNI_DIR="$ROOT/app/src/main/jniLibs/$ABI"
ASSETS_CONFIG="$ROOT/app/src/main/assets/config.yaml"
OUT_DIR="$ROOT/build/ai"
DAEMON_BIN="${AI_DAEMON_BIN:-$SRC/build_android/lws_ai_daemon}"
LIBAI_SO="${AI_LIBAI_SO:-$SRC/build_android/libai.so}"
STAGE_LIBAI="${AI_STAGE_LIBAI:-0}"

: "${ANDROID_NDK_PATH:?set ANDROID_NDK_PATH}"
: "${RKNN_RT_PATH:?set RKNN_RT_PATH}"

OPENCV_PATH="$(bash "$ROOT/scripts/make/opencv-path.sh")"
OPENCV_LIBS_DIR="$(cd "$(dirname "$OPENCV_PATH")/libs/$ABI" && pwd)"

find_libcxx_shared() {
  local ndk="$1"
  local candidate
  for candidate in \
    "$ndk/sources/cxx-stl/llvm-libc++/libs/$ABI/libc++_shared.so" \
    "$ndk/toolchains/llvm/prebuilt/"*/sysroot/usr/lib/$ABI/libc++_shared.so; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

find_readelf() {
  if [[ -n "${ANDROID_NDK_PATH:-}" ]]; then
    local candidate
    candidate="$(find "${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt" -name llvm-readelf -type f 2>/dev/null | head -1)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    candidate="$(find "${ANDROID_NDK_PATH}/toolchains/llvm/prebuilt" -name llvm-readobj -type f 2>/dev/null | head -1)"
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  fi
  if command -v llvm-readelf >/dev/null 2>&1; then
    command -v llvm-readelf
    return 0
  fi
  if command -v llvm-readobj >/dev/null 2>&1; then
    command -v llvm-readobj
    return 0
  fi
  if command -v readelf >/dev/null 2>&1; then
    command -v readelf
    return 0
  fi
  return 1
}

needed_shared_libs() {
  local readelf="$1"
  local so="$2"
  case "$(basename "$readelf")" in
    llvm-readobj*)
      "$readelf" -needed-libs -elf-output-style=GNU "$so" 2>/dev/null \
        | sed -n 's/^[[:space:]]\{1,\}\(lib[^[:space:]]\+\)$/\1/p'
      ;;
    *)
      "$readelf" -d "$so" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'
      ;;
  esac
}

is_system_lib() {
  case "$1" in
    libdl.so|liblog.so|libm.so|libc.so|libmediandk.so|libandroid.so|libz.so|libjnigraphics.so)
      return 0
      ;;
  esac
  return 1
}

gather_opencv_libs() {
  local readelf="$1"
  local start_so="$2"
  local queue=("$start_so")
  local seen=()
  local opencv=()
  local so base dep dep_path already

  while ((${#queue[@]} > 0)); do
    so="${queue[0]}"
    queue=("${queue[@]:1}")
    [[ -f "$so" ]] || continue
    base="$(basename "$so")"
    already=0
    for s in "${seen[@]:-}"; do
      if [[ "$s" == "$base" ]]; then
        already=1
        break
      fi
    done
    [[ "$already" == 1 ]] && continue
    seen+=("$base")

    while IFS= read -r dep; do
      [[ -z "$dep" ]] && continue
      case "$dep" in
        libopencv_*.so)
          opencv+=("$dep")
          dep_path="$OPENCV_LIBS_DIR/$dep"
          if [[ -f "$dep_path" ]]; then
            queue+=("$dep_path")
          fi
          ;;
      esac
    done < <(needed_shared_libs "$readelf" "$so")
  done

  if ((${#opencv[@]} == 0)); then
    return 0
  fi
  printf '%s\n' "${opencv[@]}" | sort -u
}

if [[ ! -f "$DAEMON_BIN" ]]; then
  echo "ERROR: missing $DAEMON_BIN (build lws_ai_daemon first)" >&2
  exit 1
fi

READELF="$(find_readelf)" || {
  echo "ERROR: llvm-readelf/llvm-readobj/readelf not found (set ANDROID_NDK_PATH or install binutils)" >&2
  exit 1
}

LIBCXX_SHARED="$(find_libcxx_shared "$ANDROID_NDK_PATH")" || {
  echo "ERROR: libc++_shared.so not found under ANDROID_NDK_PATH=$ANDROID_NDK_PATH" >&2
  exit 1
}

RKNN_SO=""
if [[ -f "$RKNN_RT_PATH/librknnrt.so" ]]; then
  RKNN_SO="$RKNN_RT_PATH/librknnrt.so"
elif [[ -f "$RKNN_RT_PATH/lib/librknnrt.so" ]]; then
  RKNN_SO="$RKNN_RT_PATH/lib/librknnrt.so"
else
  echo "ERROR: librknnrt.so not found under RKNN_RT_PATH=$RKNN_RT_PATH" >&2
  exit 1
fi

mkdir -p "$JNI_DIR" "$OUT_DIR"

# Remove stale product libai unless explicitly staging for tests.
if [[ "$STAGE_LIBAI" != "1" ]]; then
  rm -f "$JNI_DIR/libai.so"
fi

cp -f "$LIBCXX_SHARED" "$JNI_DIR/libc++_shared.so"
cp -f "$RKNN_SO" "$JNI_DIR/librknnrt.so"
cp -f "$SRC/config.yaml" "$ASSETS_CONFIG"

OPENCV_LIBS=()
while IFS= read -r lib; do
  [[ -z "$lib" ]] && continue
  OPENCV_LIBS+=("$lib")
done < <(gather_opencv_libs "$READELF" "$DAEMON_BIN")

MANIFEST="$OUT_DIR/runtime-libs.txt"
: > "$MANIFEST"
for lib in libc++_shared.so librknnrt.so; do
  echo "$lib" >> "$MANIFEST"
done

if ((${#OPENCV_LIBS[@]} > 0)); then
  for lib in "${OPENCV_LIBS[@]}"; do
    src="$OPENCV_LIBS_DIR/$lib"
    if [[ ! -f "$src" ]]; then
      echo "ERROR: daemon requires $lib but it is missing under $OPENCV_LIBS_DIR" >&2
      exit 1
    fi
    cp -f "$src" "$JNI_DIR/$lib"
    echo "$lib" >> "$MANIFEST"
  done
else
  echo "opencv=static (linked into lws_ai_daemon)" >> "$MANIFEST"
  echo "stage-ai-jni-libs: OpenCV statically linked into lws_ai_daemon (no libopencv_*.so to copy)"
fi

if MPP_PATHS="$(bash "$ROOT/scripts/make/rockchip-mpp-path.sh" 2>/dev/null)"; then
  # shellcheck disable=SC1090
  eval "$MPP_PATHS"
  if [[ -f "$ROCKCHIP_MPP_LIB" ]]; then
    cp -f "$ROCKCHIP_MPP_LIB" "$JNI_DIR/libmpp.so"
    echo "libmpp.so" >> "$MANIFEST"
    echo "stage-ai-jni-libs: copied Rockchip MPP runtime libmpp.so"
  fi
fi

if [[ "$STAGE_LIBAI" == "1" ]]; then
  if [[ ! -f "$LIBAI_SO" ]]; then
    echo "ERROR: AI_STAGE_LIBAI=1 but missing $LIBAI_SO" >&2
    exit 1
  fi
  cp -f "$LIBAI_SO" "$JNI_DIR/libai.so"
  echo "libai.so" >> "$MANIFEST"
  echo "stage-ai-jni-libs: AI_STAGE_LIBAI=1 staged libai.so (tests/rollback)"
fi

while IFS= read -r dep; do
  [[ -z "$dep" ]] && continue
  if is_system_lib "$dep"; then
    continue
  fi
  if [[ ! -f "$JNI_DIR/$dep" ]]; then
    echo "ERROR: missing staged runtime library $dep (required by lws_ai_daemon)" >&2
    exit 1
  fi
done < <(needed_shared_libs "$READELF" "$DAEMON_BIN")

echo "stage-ai-jni-libs: copied native libs into $JNI_DIR (product: no libai.so)"
echo "  config: $ASSETS_CONFIG"
echo "  manifest: $MANIFEST"
find "$JNI_DIR" -maxdepth 1 -type f -name '*.so' | sort | while read -r f; do
  echo "  $(basename "$f")"
done
