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
    local matches=()
    mapfile -t matches < <(compgen -G "$TARGET/$rel" || true)
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
  require_path "gstreamer" "$TARGET/usr/bin/gst-inspect-1.0"
  require_path "gstreamer" "$TARGET/usr/lib/libgstreamer-1.0.so.0.2805.0"
  require_path "gstreamer" "$TARGET/usr/lib/gstreamer-1.0/libgstrockchipmpp.so"
  # Refuse known-stale 1.22.9 tools (82944-byte gst-inspect) left in BR target
  # after a version bump — pairs with 1.28 libs as GST_CAT_DEFAULT errors.
  gst_inspect_sz="$(wc -c <"$TARGET/usr/bin/gst-inspect-1.0" | tr -d ' ')"
  if [[ "$gst_inspect_sz" == "82944" ]]; then
    die "gst-inspect-1.0 in BR target looks like stale 1.22.9 ($gst_inspect_sz bytes) — FORCE=1 make build-gstreamer with tools enabled"
  fi
  # Preview needs RGA-backed mppvideodec (format/width/height). Without it,
  # Flutter texture path falls back to CPU NV12→RGBA (~1fps on RK3566).
  if strings "$TARGET/usr/lib/gstreamer-1.0/libgstrockchipmpp.so" 2>/dev/null |
    grep -q 'RGA disabled at compile time'; then
    die "libgstrockchipmpp.so built without RGA — set BR2_PREFER_ROCKCHIP_RGA=y and FORCE=1 make build-gstreamer"
  fi
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
  # Drop leftover prior-ABI sonames from BR target (e.g. *.so.0.2209.0 after 1.28 bump).
  if [[ -d "$GST_DEST/usr/lib" ]]; then
    find "$GST_DEST/usr/lib" \( -name '*.so.*.2209.*' -o -name '*.so.0.2209.0' \) -delete
  fi
  # H4: keep only product plugin set (RTSP preview + MP4 remux + MPP + ALSA).
  # Compile-time trim is preferred; this strips leftovers still present in BR target.
  if [[ -d "$GST_DEST/usr/lib/gstreamer-1.0" ]]; then
    keep_plugins=(
      libgstalsa.so
      libgstapp.so
      libgstaudioconvert.so
      libgstaudioparsers.so
      libgstaudioresample.so
      libgstautodetect.so
      libgstcoreelements.so
      libgstcoretracers.so
      libgstfaad.so
      libgstisomp4.so
      libgstkms.so
      libgstogg.so
      libgstpbtypes.so
      libgstplayback.so
      libgstrockchipmpp.so
      libgstrtp.so
      libgstrtpmanager.so
      libgstrtsp.so
      libgstsdpelem.so
      libgsttcp.so
      libgsttypefindfunctions.so
      libgstudp.so
      libgstvideoconvertscale.so
      libgstvideoparsersbad.so
      libgstvideorate.so
      libgstvolume.so
      libgstvorbis.so
    )
    shopt -s nullglob
    for f in "$GST_DEST/usr/lib/gstreamer-1.0"/*; do
      base="$(basename "$f")"
      case "$base" in
        *.so|*.so.*) ;;
        *) continue ;;
      esac
      keep=0
      for k in "${keep_plugins[@]}"; do
        if [[ "$base" == "$k" || "$base" == "$k".* ]]; then
          keep=1
          break
        fi
      done
      if [[ "$keep" != 1 ]]; then
        rm -f "$f"
      fi
    done
    shopt -u nullglob
  fi
  prebuilt_stamp "$GST_DEST" "$GST_VER"
  did=1
fi

if [[ "${EXPORT_PLATFORM}" == "1" ]]; then
  require_path "libmodbus" "$TARGET/usr/lib/libmodbus.so*"
  require_path "yaml-cpp" "$TARGET/usr/lib/libyaml-cpp.so*"
  require_path "sqlite" "$TARGET/usr/lib/libsqlite3.so*"
  [[ -x "$TARGET/usr/sbin/avahi-daemon" ]] || die "missing $TARGET/usr/sbin/avahi-daemon"
  [[ -f "$TARGET/usr/share/dbus-1/system.d/avahi-dbus.conf" ]] || \
    die "missing $TARGET/usr/share/dbus-1/system.d/avahi-dbus.conf"
  [[ -f "$TARGET/usr/lib/systemd/system/avahi-daemon.service" ]] || \
    die "missing $TARGET/usr/lib/systemd/system/avahi-daemon.service"
  PLAT_DEST="$ROOT/prebuilt/platform-packages/target"
  rm -rf "$PLAT_DEST"
  echo "export-runtime-prebuilt: platform → $PLAT_DEST"
  # Include dbus policy + systemd units + etc/avahi so prebuilt rootfs does not
  # depend on a leftover BR2_PACKAGE_AVAHI install in buildroot/output.
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
    usr/share/avahi \
    usr/share/dbus-1/system.d/avahi-dbus.conf \
    usr/lib/systemd/system/avahi-daemon.service \
    usr/lib/systemd/system/avahi-daemon.socket \
    usr/lib/tmpfiles.d/avahi.conf \
    etc/avahi
  mkdir -p "$PLAT_DEST/etc/systemd/system/multi-user.target.wants"
  ln -sfn /usr/lib/systemd/system/avahi-daemon.service \
    "$PLAT_DEST/etc/systemd/system/multi-user.target.wants/avahi-daemon.service"
  prebuilt_stamp "$PLAT_DEST" "$PLAT_VER"
  did=1
fi

[[ "$did" -eq 1 ]] || die "nothing exported — set EXPORT_GST=1 and/or EXPORT_PLATFORM=1"

bash "$ROOT/scripts/sync-prebuilt-overlays.sh"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"

echo "export-runtime-prebuilt: done — make apply-overlay && make build-rootfs"
