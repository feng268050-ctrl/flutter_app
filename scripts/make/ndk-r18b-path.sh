#!/usr/bin/env bash
set -euo pipefail

# Resolve the vendored Android NDK r18b root for lens-inspector / make ai only.
# Isolated under native/toolchains/ndk-r18b/ — Gradle and other native builds use their own NDK.
#
# Usage:
#   ANDROID_NDK_PATH="$(scripts/make/ndk-r18b-path.sh)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENDOR_NDK="$ROOT/native/toolchains/ndk-r18b/ndk"
TOOLCHAIN_FILE="build/cmake/android.toolchain.cmake"

if [[ ! -f "$VENDOR_NDK/$TOOLCHAIN_FILE" ]]; then
  cat >&2 <<EOF
ERROR: vendored NDK r18b not found at $VENDOR_NDK

Run once from the repo root:
  make ndk-r18b

This NDK is used only by \`make ai\`; other native targets may use different NDK versions.
EOF
  exit 1
fi

printf '%s\n' "$VENDOR_NDK"
