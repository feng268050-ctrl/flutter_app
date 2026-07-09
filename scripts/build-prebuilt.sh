#!/usr/bin/env bash
# Extract Flutter stack from Buildroot output into git-tracked prebuilt/.
#
# Reads buildroot/output/<profile>/ after make build-rootfs (engine + flutter-pi
# must have been built at least once). On macOS with Docker volume, runs inside
# the container against /work/sdk automatically.
#
# Usage:
#   make build-prebuilt
#   FORCE=1 make build-prebuilt
#   PACK_FLUTTER_SDK=0 make build-prebuilt   # engine + flutter-pi only (~50 MB)
#   BR_OUTPUT=rockchip_rk3566_rk3568_lws_hmi make build-prebuilt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# macOS Docker volume: artifacts live in the container, not host sdk/ symlink.
if [[ "$(uname -s)" == Darwin && "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  exec bash "$ROOT/scripts/docker-run.sh" \
    bash -c 'export LWS_HMI_DOCKER=1 LWS_HMI_SDK_DIR=/work/sdk; exec bash /work/lws-hmi/scripts/build-prebuilt.sh'
fi

source "$ROOT/scripts/prebuilt-common.sh"

SDK="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print)}"
FORCE="${FORCE:-0}"
PACK_FLUTTER_SDK="${PACK_FLUTTER_SDK:-1}"
ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.24.4")"
SDK_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-sdk.version" "3.24.4")"
PI_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-pi.version" "")"
RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"
MARKER=".lws-precache-done"

resolve_br_out() {
  local sdk="$1"
  local out_base="$sdk/buildroot/output"
  local candidate dir

  if [[ -n "${BR_OUTPUT:-}" ]]; then
    candidate="$out_base/$BR_OUTPUT"
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
    echo "ERROR: BR_OUTPUT=$BR_OUTPUT not found under $out_base" >&2
    exit 1
  fi

  for dir in \
    "$out_base/rockchip_rk3566_rk3568_lws_hmi" \
    "$out_base/latest" \
    "$out_base"/rockchip_rk3566_*; do
    [[ -d "$dir" ]] || continue
    if [[ -f "$dir/target/usr/lib/libflutter_engine.so" ]]; then
      echo "$dir"
      return 0
    fi
  done

  echo "ERROR: no Buildroot output with libflutter_engine.so under $out_base" >&2
  echo "  Run: make lunch && make build-rootfs (flutter-engine + flutter-pi)" >&2
  echo "  Or set BR_OUTPUT=<profile> if output dir name differs" >&2
  exit 1
}

require_path() {
  local label="$1"
  shift
  for p in "$@"; do
    if [[ ! -e "$p" ]]; then
      echo "ERROR: $label missing: $p" >&2
      exit 1
    fi
  done
}

find_engine_build_dir() {
  local build_dir="$1"
  local base="$build_dir/flutter-engine-${ENGINE_VER}"
  if [[ ! -d "$base" ]]; then
    base="$(find "$build_dir" -maxdepth 1 -type d -name 'flutter-engine-*' 2>/dev/null | head -1)"
  fi
  if [[ -z "$base" || ! -d "$base" ]]; then
    echo ""
    return 0
  fi
  local d
  for d in "$base"/out/linux_"${RUNTIME_MODE}"_arm64 \
           "$base"/out/linux_"${RUNTIME_MODE}"_arm64/clang_x64; do
    if [[ -d "$base/out/linux_${RUNTIME_MODE}_arm64" ]]; then
      echo "$base/out/linux_${RUNTIME_MODE}_arm64"
      return 0
    fi
  done
  echo ""
}

BR_OUT="$(resolve_br_out "$SDK")"
HOST_DIR="$BR_OUT/host"
STAGING_DIR="$BR_OUT/staging"
TARGET_DIR="$BR_OUT/target"
BUILD_DIR="$BR_OUT/build"

ENGINE_PREBUILT="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}"
PI_PREBUILT="$ROOT/prebuilt/flutter-pi/${PI_VER}"
SDK_PREBUILT_ROOT="$ROOT/prebuilt/flutter-sdk"
SDK_PREBUILT_INSTALL="$SDK_PREBUILT_ROOT/install"

echo "build-prebuilt: using Buildroot output $BR_OUT"

require_path "Buildroot output" \
  "$TARGET_DIR/usr/lib/libflutter_engine.so" \
  "$TARGET_DIR/usr/bin/flutter-pi" \
  "$HOST_DIR/bin/flutter_gen_snapshot"

ENGINE_BUILD="$(find_engine_build_dir "$BUILD_DIR")"
EMBEDDER_H="${STAGING_DIR}/usr/include/flutter_embedder.h"
if [[ ! -f "$EMBEDDER_H" && -n "$ENGINE_BUILD" && -f "$ENGINE_BUILD/flutter_embedder.h" ]]; then
  EMBEDDER_H="$ENGINE_BUILD/flutter_embedder.h"
fi
require_path "flutter_embedder.h" "$EMBEDDER_H"

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$ENGINE_PREBUILT" "$PI_PREBUILT"
  if [[ "$PACK_FLUTTER_SDK" == "1" ]]; then
    rm -rf "$SDK_PREBUILT_INSTALL"
    rm -f "$SDK_PREBUILT_ROOT/.lws-prebuilt"
  fi
fi

echo "build-prebuilt: flutter-engine → $ENGINE_PREBUILT"
rm -rf "$ENGINE_PREBUILT"
mkdir -p "$ENGINE_PREBUILT/target/usr/lib" \
  "$ENGINE_PREBUILT/target/usr/share/flutter/${RUNTIME_MODE}/data" \
  "$ENGINE_PREBUILT/staging/usr/lib" \
  "$ENGINE_PREBUILT/staging/usr/include" \
  "$ENGINE_PREBUILT/staging/usr/share/flutter/${RUNTIME_MODE}/data" \
  "$ENGINE_PREBUILT/host/bin"

install -m 0755 "$TARGET_DIR/usr/lib/libflutter_engine.so" \
  "$ENGINE_PREBUILT/target/usr/lib/libflutter_engine.so"
install -m 0644 "$TARGET_DIR/usr/share/flutter/${RUNTIME_MODE}/data/icudtl.dat" \
  "$ENGINE_PREBUILT/target/usr/share/flutter/${RUNTIME_MODE}/data/icudtl.dat"

install -m 0755 "$STAGING_DIR/usr/lib/libflutter_engine.so" \
  "$ENGINE_PREBUILT/staging/usr/lib/libflutter_engine.so"
install -m 0644 "$STAGING_DIR/usr/share/flutter/${RUNTIME_MODE}/data/icudtl.dat" \
  "$ENGINE_PREBUILT/staging/usr/share/flutter/${RUNTIME_MODE}/data/icudtl.dat"
install -m 0644 "$EMBEDDER_H" "$ENGINE_PREBUILT/staging/usr/include/flutter_embedder.h"
install -m 0755 "$HOST_DIR/bin/flutter_gen_snapshot" \
  "$ENGINE_PREBUILT/host/bin/gen_snapshot"

prebuilt_stamp "$ENGINE_PREBUILT" "${ENGINE_VER}-arm64-${RUNTIME_MODE}"

echo "build-prebuilt: flutter-pi → $PI_PREBUILT"
mkdir -p "$PI_PREBUILT/usr/bin"
install -m 0755 "$TARGET_DIR/usr/bin/flutter-pi" "$PI_PREBUILT/usr/bin/flutter-pi"
prebuilt_stamp "$PI_PREBUILT" "$PI_VER"

if [[ "$PACK_FLUTTER_SDK" == "1" ]]; then
  HOST_SDK_SRC="$HOST_DIR/share/flutter/sdk"
  require_path "host Flutter SDK" "$HOST_SDK_SRC/bin/flutter"
  echo "build-prebuilt: flutter-sdk → $SDK_PREBUILT_INSTALL (large; may take a minute) ..."
  mkdir -p "$SDK_PREBUILT_ROOT"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$HOST_SDK_SRC/" "$SDK_PREBUILT_INSTALL/"
  else
    rm -rf "$SDK_PREBUILT_INSTALL"
    mkdir -p "$SDK_PREBUILT_INSTALL"
    cp -a "$HOST_SDK_SRC/." "$SDK_PREBUILT_INSTALL/"
  fi
  touch "$SDK_PREBUILT_INSTALL/$MARKER"
  prebuilt_stamp "$SDK_PREBUILT_ROOT" "$SDK_VER"
  du -sh "$SDK_PREBUILT_INSTALL"
else
  echo "build-prebuilt: skipping flutter-sdk (PACK_FLUTTER_SDK=0)"
fi

bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
echo "build-prebuilt: done — commit prebuilt/ to skip Flutter recompile on clone"
echo "  engine: $ENGINE_PREBUILT"
echo "  flutter-pi: $PI_PREBUILT"
if [[ "$PACK_FLUTTER_SDK" == "1" ]]; then
  echo "  flutter-sdk: $SDK_PREBUILT_INSTALL"
fi
