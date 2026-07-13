#!/usr/bin/env bash
# Copy compiled runtime artifacts from Buildroot target/ → prebuilt/*/target/.
# Called by build-gstreamer / build-platform-packages (before build-rootfs), not after.
#
# Env:
#   EXPORT_GST=1|0       — gstreamer + MPP (default: 1 when argv empty or "all")
#   EXPORT_PLATFORM=1|0  — platform libs (default: 1 when argv empty or "all")
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" == Darwin && "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  exec bash "$ROOT/scripts/docker-run.sh" \
    bash -c 'export LWS_HMI_DOCKER=1 LWS_HMI_SDK_DIR=/work/sdk; exec bash /work/lws-hmi/scripts/export-runtime-prebuilt.sh "$@"' \
    _ "$@"
fi

source "$ROOT/scripts/prebuilt-common.sh"

MODE="${1:-all}"
case "$MODE" in
  gstreamer) EXPORT_GST=1; EXPORT_PLATFORM=0 ;;
  platform|platform-packages) EXPORT_GST=0; EXPORT_PLATFORM=1 ;;
  all) EXPORT_GST="${EXPORT_GST:-1}"; EXPORT_PLATFORM="${EXPORT_PLATFORM:-1}" ;;
  *) echo "usage: export-runtime-prebuilt.sh [all|gstreamer|platform]" >&2; exit 1 ;;
esac

SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
PROFILE="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
TARGET="$SDK/buildroot/output/${PROFILE}/target"
GST_VER="$(read_version_file "$ROOT/overlay/third-party/gstreamer.version" "rockchip-mpp-gst-rtsp")"
PLAT_VER="$(read_version_file "$ROOT/overlay/third-party/platform.version" "1")"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -d "$TARGET/usr" ]] || die "missing $TARGET — run: make lunch && make build-gstreamer (or build-platform-packages)"

require_path() {
  local label="$1" path="$2"
  if ! compgen -G "$path" >/dev/null 2>&1; then
    die "$label not found under target: $path (run the matching build-* step first)"
  fi
}

copy_globs() {
  local dest_root="$1"
  shift
  local rel dest_dir
  mkdir -p "$dest_root"
  for rel in "$@"; do
    shopt -s nullglob
    local matches=( "$TARGET/$rel" )
    shopt -u nullglob
    if [[ ${#matches[@]} -eq 0 ]]; then
      echo "WARNING: export skip (no match): $rel" >&2
      continue
    fi
    for src in "${matches[@]}"; do
      rel="${src#"$TARGET/"}"
      dest_dir="$dest_root/$(dirname "$rel")"
      mkdir -p "$dest_dir"
      if [[ -d "$src" ]]; then
        if command -v rsync >/dev/null 2>&1; then
          rsync -a "$src/" "$dest_root/$rel/"
        else
          mkdir -p "$dest_root/$rel"
          cp -a "$src/." "$dest_root/$rel/"
        fi
      else
        cp -a "$src" "$dest_root/$rel"
      fi
    done
  done
}

did=0

if [[ "${EXPORT_GST}" == "1" ]]; then
  require_path "gstreamer" "$TARGET/usr/bin/gst-launch-1.0"
  GST_DEST="$ROOT/prebuilt/gstreamer/target"
  rm -rf "$GST_DEST"
  echo "export-runtime-prebuilt: gstreamer → $GST_DEST"
  copy_globs "$GST_DEST" \
    usr/bin/gst-launch-1.0 \
    usr/bin/gst-inspect-1.0 \
    usr/lib/libgstreamer-1.0.so* \
    usr/lib/libgst*.so* \
    usr/lib/gstreamer-1.0 \
    usr/libexec/gstreamer-1.0 \
    usr/lib/librockchip_mpp.so* \
    usr/lib/librga.so* \
    usr/lib/libgstallocators-1.0.so* \
    usr/lib/libgstapp-1.0.so* \
    usr/lib/libgstvideo-1.0.so* \
    usr/lib/libgstaudio-1.0.so* \
    usr/lib/libgstpbutils-1.0.so* \
    usr/lib/libgstrtp-1.0.so* \
    usr/lib/libgstrtsp-1.0.so* \
    usr/lib/libgstsdp-1.0.so* \
    usr/lib/libgsttag-1.0.so* \
    usr/lib/libgstbase-1.0.so* \
    usr/lib/libgstcodecparsers-1.0.so* \
    usr/share/gstreamer-1.0
  prebuilt_stamp "$GST_DEST" "$GST_VER"
  did=1
fi

if [[ "${EXPORT_PLATFORM}" == "1" ]]; then
  require_path "libmodbus" "$TARGET/usr/lib/libmodbus.so*"
  require_path "yaml-cpp" "$TARGET/usr/lib/libyaml-cpp.so*"
  require_path "sqlite" "$TARGET/usr/lib/libsqlite3.so*"
  [[ -x "$TARGET/usr/sbin/avahi-daemon" ]] || die "missing $TARGET/usr/sbin/avahi-daemon"
  PLAT_DEST="$ROOT/prebuilt/platform-packages/target"
  rm -rf "$PLAT_DEST"
  echo "export-runtime-prebuilt: platform → $PLAT_DEST"
  copy_globs "$PLAT_DEST" \
    usr/lib/libmodbus.so* \
    usr/lib/libyaml-cpp.so* \
    usr/lib/libsqlite3.so* \
    usr/sbin/avahi-daemon \
    usr/lib/avahi \
    usr/lib/libavahi-client.so* \
    usr/lib/libavahi-common.so* \
    usr/lib/libavahi-core.so* \
    usr/lib/libavahi-glib.so* \
    usr/lib/libdnsfile.so* \
    usr/lib/libdaemon.so* \
    usr/share/avahi
  prebuilt_stamp "$PLAT_DEST" "$PLAT_VER"
  did=1
fi

[[ "$did" -eq 1 ]] || die "nothing exported — set EXPORT_GST=1 and/or EXPORT_PLATFORM=1"

bash "$ROOT/scripts/sync-prebuilt-overlays.sh"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"

echo "export-runtime-prebuilt: done — make apply-overlay && make build-rootfs"
