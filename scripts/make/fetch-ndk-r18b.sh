#!/usr/bin/env bash
set -euo pipefail

# Download Android NDK r18b into native/toolchains/ndk-r18b/ndk/ (AI / lens-inspector only).
#
# Usage:
#   scripts/make/fetch-ndk-r18b.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENDOR_DIR="$ROOT/native/toolchains/ndk-r18b"
VERSION_FILE="$VENDOR_DIR/VERSION"
CACHE_DIR="$VENDOR_DIR/_cache"
NDK_ROOT="$VENDOR_DIR/ndk"
MARKER="$NDK_ROOT/build/cmake/android.toolchain.cmake"
BASE_URL="https://dl.google.com/android/repository"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: missing $VERSION_FILE" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ "$VERSION" != "r18b" ]]; then
  echo "ERROR: unsupported NDK version in $VERSION_FILE: $VERSION (expected r18b)" >&2
  exit 1
fi

host_prebuilt_tag() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' "darwin-x86_64" ;;
    Linux) printf '%s\n' "linux-x86_64" ;;
    MINGW*|MSYS*|CYGWIN*)
      echo "ERROR: use Windows zip manually or WSL; fetch-ndk-r18b supports Darwin/Linux only" >&2
      exit 1
      ;;
    *)
      echo "ERROR: unsupported host OS for fetch-ndk-r18b: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

ndk_host_prebuilt_ready() {
  local tag="$1"
  if [[ -d "$NDK_ROOT/toolchains/llvm/prebuilt/$tag" ]]; then
    return 0
  fi
  if [[ -d "$NDK_ROOT/toolchains/aarch64-linux-android-4.9/prebuilt/$tag" ]]; then
    return 0
  fi
  return 1
}

ndk_ready() {
  local tag
  [[ -f "$MARKER" ]] || return 1
  tag="$(host_prebuilt_tag)"
  ndk_host_prebuilt_ready "$tag"
}

if ndk_ready; then
  echo "fetch-ndk-r18b: NDK ${VERSION} already installed at $NDK_ROOT"
  echo "  ANDROID_NDK_PATH=$NDK_ROOT"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi
if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip not found" >&2
  exit 1
fi

HOST_TAG="$(host_prebuilt_tag)"
ZIP_NAME="android-ndk-${VERSION}-${HOST_TAG}.zip"
CACHE_ZIP="$CACHE_DIR/$ZIP_NAME"
URL="${BASE_URL}/${ZIP_NAME}"

mkdir -p "$CACHE_DIR"

zip_ok() {
  # `unzip -t` is the simplest cross-platform integrity check we have here.
  # If the previous download was interrupted, the file may exist but be invalid.
  unzip -tq "$1" >/dev/null 2>&1
}

download_zip() {
  echo "fetch-ndk-r18b: downloading ${URL} ..."
  echo "fetch-ndk-r18b: (large archive ~800MB; cached at $CACHE_ZIP)"
  # Resume-capable download: -C - continues partial files when possible.
  curl -fL --retry 3 --retry-delay 5 -C - -o "$CACHE_ZIP" "$URL"
}

if [[ -f "$CACHE_ZIP" ]]; then
  if zip_ok "$CACHE_ZIP"; then
    echo "fetch-ndk-r18b: using cached archive $CACHE_ZIP"
  else
    echo "fetch-ndk-r18b: cached archive is corrupt/incomplete; removing: $CACHE_ZIP" >&2
    rm -f "$CACHE_ZIP"
    download_zip
  fi
else
  download_zip
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ndk-r18b.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "fetch-ndk-r18b: extracting..."
unzip -q "$CACHE_ZIP" -d "$TMP"

NDK_SRC="$(find "$TMP" -type f -path '*/build/cmake/android.toolchain.cmake' -print -quit)"
if [[ -z "$NDK_SRC" ]]; then
  echo "ERROR: android.toolchain.cmake not found inside ${ZIP_NAME}" >&2
  exit 1
fi
NDK_SRC="$(cd "$(dirname "$NDK_SRC")/../.." && pwd)"

rm -rf "$NDK_ROOT"
mkdir -p "$VENDOR_DIR"
cp -R "$NDK_SRC/." "$NDK_ROOT"

if ! ndk_ready; then
  echo "ERROR: installed NDK is missing host prebuilts for ${HOST_TAG} under $NDK_ROOT" >&2
  exit 1
fi

printf '%s\n' "$VERSION" > "$VENDOR_DIR/installed-version.txt"
echo "fetch-ndk-r18b: installed Android NDK ${VERSION} (${HOST_TAG} host → Android arm64-v8a cross-compile)"
echo "  ANDROID_NDK_PATH=$NDK_ROOT"
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "  note: on Apple Silicon, make ai re-execs under Rosetta to use darwin-x86_64 host tools"
fi
