#!/usr/bin/env bash
set -euo pipefail

# Stage lws_ai_daemon into APK assets (MediaMTX-style executable packaging).
#
# Required:
#   AI_DAEMON_BIN or default native/lensinspector/build_android/lws_ai_daemon
# Optional:
#   LIB_VERSION (written to version.txt)
#
# Output:
#   app/src/main/assets/ai_daemon/arm64-v8a/{lws_ai_daemon,libc++_shared.so,version.txt}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/native/lensinspector"
ABI="arm64-v8a"
DAEMON_BIN="${AI_DAEMON_BIN:-$SRC/build_android/lws_ai_daemon}"
ASSETS_DIR="$ROOT/app/src/main/assets/ai_daemon/$ABI"
JNI_DIR="$ROOT/app/src/main/jniLibs/$ABI"
VERSION="${LIB_VERSION:-0.0.0-dev}"

if [[ ! -f "$DAEMON_BIN" ]]; then
  echo "ERROR: missing daemon binary: $DAEMON_BIN (run make ai)" >&2
  exit 1
fi

mkdir -p "$ASSETS_DIR"
cp -f "$DAEMON_BIN" "$ASSETS_DIR/lws_ai_daemon"
chmod 755 "$ASSETS_DIR/lws_ai_daemon"

# Daemon links c++_shared; keep a copy beside the executable for $ORIGIN rpath.
LIBCXX_CANDIDATES=(
  "$JNI_DIR/libc++_shared.so"
)
if [[ -n "${ANDROID_NDK_PATH:-}" ]]; then
  LIBCXX_CANDIDATES+=(
    "$ANDROID_NDK_PATH/sources/cxx-stl/llvm-libc++/libs/$ABI/libc++_shared.so"
  )
fi
copied_libcxx=0
for candidate in "${LIBCXX_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    cp -f "$candidate" "$ASSETS_DIR/libc++_shared.so"
    copied_libcxx=1
    break
  fi
done
if [[ "$copied_libcxx" -ne 1 ]]; then
  echo "ERROR: libc++_shared.so not found for ai daemon packaging" >&2
  exit 1
fi

printf '%s\n' "$VERSION" > "$ASSETS_DIR/version.txt"

echo "staged ai daemon: $ASSETS_DIR/lws_ai_daemon (version=$VERSION, with libc++_shared.so)"
