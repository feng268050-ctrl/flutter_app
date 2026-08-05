#!/usr/bin/env bash
# Cross-compile uMTP-Responder (umtprd) → prebuilt/ + rootfs-overlay /usr/bin/umtprd.
# Uses Rockchip aarch64 toolchain (Docker on macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/third-party/umtprd.version"
SRC_ROOT="$ROOT/.cache/umtprd"
OUT_DIR="$ROOT/prebuilt/umtprd/aarch64"
OVERLAY_BIN="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/bin/umtprd"
FORCE="${FORCE:-0}"
TAG="$(read_version_file "$VERSION_FILE" "umtprd-1.8.1")"
TARBALL_URL="https://github.com/viveris/uMTP-Responder/archive/refs/tags/${TAG}.tar.gz"
CACHE_TAR="$SRC_ROOT/${TAG}.tar.gz"
BUILD_DIR="$SRC_ROOT/build-${TAG}"

sync_overlay() {
  if [[ -x "$OUT_DIR/umtprd" ]]; then
    mkdir -p "$(dirname "$OVERLAY_BIN")"
    install -m 0755 "$OUT_DIR/umtprd" "$OVERLAY_BIN"
    echo "build-umtprd: synced → $OVERLAY_BIN"
  fi
}

find_cross_gcc() {
  local sdk="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
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
  # Buildroot host toolchain after lunch
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

do_build() {
  local cc="$1"
  mkdir -p "$SRC_ROOT" "$OUT_DIR"
  if [[ ! -f "$CACHE_TAR" ]]; then
    echo "build-umtprd: downloading ${TARBALL_URL} ..."
    curl -fL --retry 3 --retry-delay 2 -o "$CACHE_TAR" "$TARBALL_URL"
  fi
  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"
  tar -xzf "$CACHE_TAR" -C "$BUILD_DIR" --strip-components=1
  PATCH="$ROOT/overlay/third-party/umtprd/umtprd-no-posix-mqueue.patch"
  if [[ -f "$PATCH" ]]; then
    echo "build-umtprd: applying $(basename "$PATCH")"
    patch -d "$BUILD_DIR" -p1 <"$PATCH"
  fi
  echo "build-umtprd: CC=$cc"
  make -C "$BUILD_DIR" clean >/dev/null 2>&1 || true
  make -C "$BUILD_DIR" -j"${BUILD_JOBS:-8}" CC="$cc" CFLAGS="-O2 -Wall -I./inc" LDFLAGS="-static -lpthread -lrt"
  [[ -x "$BUILD_DIR/umtprd" ]] || {
    echo "ERROR: umtprd binary missing after build" >&2
    exit 1
  }
  install -m 0755 "$BUILD_DIR/umtprd" "$OUT_DIR/umtprd"
  prebuilt_stamp "$OUT_DIR" "${TAG}-aarch64-static"
  sync_overlay
  bash "$ROOT/scripts/sync-prebuilt-manifest.sh" 2>/dev/null || true
  file "$OUT_DIR/umtprd" || true
  echo "build-umtprd: done → $OUT_DIR/umtprd (${TAG})"
}

if prebuilt_ready "$OUT_DIR" && [[ -x "$OUT_DIR/umtprd" && -x "$OVERLAY_BIN" ]] && [[ "$FORCE" != "1" ]]; then
  echo "build-umtprd: prebuilt ready at $OUT_DIR"
  sync_overlay
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$OUT_DIR" "$BUILD_DIR"
  rm -f "$OVERLAY_BIN"
fi

# macOS: compile inside builder (linux/amd64) with SDK toolchain.
if [[ "$(uname -s)" == Darwin ]] && [[ "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  exec env LWS_HMI_SKIP_OVERLAY=1 FORCE="$FORCE" \
    bash "$ROOT/scripts/docker-run.sh" \
    bash /work/lws-hmi/scripts/build-umtprd.sh
fi

CC="$(find_cross_gcc)" || {
  echo "ERROR: aarch64 cross gcc not found (SDK prebuilts or Buildroot host)" >&2
  exit 1
}
do_build "$CC"
