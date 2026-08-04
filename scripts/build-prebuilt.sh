#!/usr/bin/env bash
# Export compiled Flutter packages from Buildroot output → prebuilt/.
# Called by scripts/export-prebuilt.sh (or directly with EXPORT_RUNTIME=0).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# macOS Docker volume: artifacts live in the container, not host linux-sdk/.
if [[ "$(uname -s)" == Darwin && "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  exec bash "$ROOT/scripts/docker-run.sh" \
    env LWS_HMI_DOCKER=1 LWS_HMI_SDK_DIR=/work/sdk \
        PACK_ENGINE="${PACK_ENGINE:-1}" \
        PACK_FLUTTER_SDK="${PACK_FLUTTER_SDK:-1}" \
        FORCE="${FORCE:-0}" \
        FLUTTER_ENGINE_RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}" \
    bash /work/lws-hmi/scripts/build-prebuilt.sh
fi

source "$ROOT/scripts/prebuilt-common.sh"

SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
FORCE="${FORCE:-0}"
PACK_FLUTTER_SDK="${PACK_FLUTTER_SDK:-1}"
PACK_ENGINE="${PACK_ENGINE:-1}"

# Host Flutter SDK lives on the macOS filesystem; Docker bind-mounts it :ro.
if [[ "${LWS_HMI_DOCKER:-}" == "1" && "${PACK_FLUTTER_SDK:-1}" == "1" ]]; then
  echo "build-prebuilt: skipping flutter-sdk export inside Docker (use host: make fetch-flutter-sdk)"
  PACK_FLUTTER_SDK=0
fi
ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.41.9")"
SDK_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-sdk.version" "3.41.9")"
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
    if [[ "${PACK_ENGINE:-1}" == "1" && -f "$dir/target/usr/lib/libflutter_engine.so" ]]; then
      echo "$dir"
      return 0
    fi
  done

  echo "ERROR: no suitable Buildroot output under $out_base" >&2
  echo "  Run: make lunch && make build-flutter-engine" >&2
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
SDK_FLUTTER_ROOT="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print-root)"
SDK_PREBUILT_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"

echo "build-prebuilt: using Buildroot output $BR_OUT"

if [[ "$PACK_ENGINE" == "1" ]]; then
  require_path "flutter-engine in Buildroot output" \
    "$TARGET_DIR/usr/lib/libflutter_engine.so" \
    "$HOST_DIR/bin/flutter_gen_snapshot"
fi

ENGINE_BUILD=""
EMBEDDER_H="${STAGING_DIR}/usr/include/flutter_embedder.h"
if [[ "$PACK_ENGINE" == "1" ]]; then
  ENGINE_BUILD="$(find_engine_build_dir "$BUILD_DIR")"
  if [[ ! -f "$EMBEDDER_H" && -n "$ENGINE_BUILD" && -f "$ENGINE_BUILD/flutter_embedder.h" ]]; then
    EMBEDDER_H="$ENGINE_BUILD/flutter_embedder.h"
  fi
  require_path "flutter_embedder.h" "$EMBEDDER_H"
fi

if [[ "$FORCE" == "1" ]]; then
  if [[ "$PACK_ENGINE" == "1" ]]; then
    rm -rf "$ENGINE_PREBUILT"
  fi
  if [[ "$PACK_FLUTTER_SDK" == "1" ]]; then
    rm -rf "$SDK_PREBUILT_INSTALL"
    rm -f "$SDK_FLUTTER_ROOT/.lws-prebuilt"
  fi
fi

if [[ "$PACK_ENGINE" == "1" ]]; then
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
fi

if [[ "$PACK_FLUTTER_SDK" == "1" ]]; then
  HOST_SDK_SRC="$HOST_DIR/share/flutter/sdk"
  require_path "host Flutter SDK" "$HOST_SDK_SRC/bin/flutter"
  echo "build-prebuilt: flutter-sdk → $SDK_PREBUILT_INSTALL (large; may take a minute) ..."
  mkdir -p "$SDK_FLUTTER_ROOT"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --no-owner --no-group --no-perms --omit-dir-times \
      "$HOST_SDK_SRC/" "$SDK_PREBUILT_INSTALL/"
  else
    rm -rf "$SDK_PREBUILT_INSTALL"
    mkdir -p "$SDK_PREBUILT_INSTALL"
    cp -a "$HOST_SDK_SRC/." "$SDK_PREBUILT_INSTALL/"
  fi
  touch "$SDK_PREBUILT_INSTALL/$MARKER"
  prebuilt_stamp "$SDK_FLUTTER_ROOT" "$SDK_VER"
  bash "$ROOT/scripts/link-flutter-sdk.sh"
  du -sh "$SDK_PREBUILT_INSTALL"
else
  echo "build-prebuilt: skipping flutter-sdk (PACK_FLUTTER_SDK=0)"
fi

bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
echo "build-prebuilt: done — commit prebuilt/flutter-engine/<ver>/arm64-{release,debug}/ to skip engine recompile on clone"
echo "  engine: $ENGINE_PREBUILT"
if [[ "$PACK_FLUTTER_SDK" == "1" ]]; then
  echo "  flutter-sdk: $SDK_PREBUILT_INSTALL"
fi
