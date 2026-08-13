#!/bin/sh
# Refresh flutter-wayland-client + GStreamer video plugin from host prebuilt.
# Buildroot stamps stay clean after host FORCE rebuilds; without this, rootfs
# keeps an old libvideo_player_plugin.so that SIGSEGVs on live RTSP.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
HMI_ROOT="${DOCKER_ROOT:-/work/lws-hmi}"

read_ver() {
	if [ -f "$HMI_ROOT/overlay/buildroot/flutter-embedded-linux.version" ]; then
		tr -d '[:space:]' <"$HMI_ROOT/overlay/buildroot/flutter-embedded-linux.version"
	else
		echo "42d3d75a56"
	fi
}

VER="$(read_ver)"
PREBUILT="$HMI_ROOT/prebuilt/flutter-embedded-linux/${VER}"
CLIENT="$PREBUILT/usr/bin/flutter-wayland-client"
PLUGIN="$PREBUILT/usr/lib/libvideo_player_plugin.so"

# Skip quietly when the Weston client prebuilt is absent.
if [ ! -x "$TARGET_DIR/usr/bin/flutter-wayland-client" ] && [ ! -f "$CLIENT" ]; then
	echo "lws-hmi-sync-flutter-elinux: skip (no weston client / prebuilt)" >&2
	exit 0
fi

if [ ! -f "$PREBUILT/.lws-prebuilt" ] || [ ! -f "$PREBUILT/.lws-gstreamer-video-player" ]; then
	echo "lws-hmi-sync-flutter-elinux: ERROR missing prebuilt stamps under $PREBUILT" >&2
	echo "  Run: make build-flutter-embedded-linux" >&2
	exit 1
fi

if [ ! -x "$CLIENT" ] || [ ! -f "$PLUGIN" ]; then
	echo "lws-hmi-sync-flutter-elinux: ERROR missing $CLIENT or $PLUGIN" >&2
	exit 1
fi

# Prefer grep -a over `strings | grep` (pipefail/SIGPIPE false negatives).
_vp_has() { grep -a -F -q -- "$2" "$1" 2>/dev/null; }

# Live RTSP needs 0002+ patches; refuse to bake an unpatched plugin.
if ! _vp_has "$PLUGIN" 'Video size unknown after preroll'; then
	echo "lws-hmi-sync-flutter-elinux: ERROR $PLUGIN missing live-RTSP marker" >&2
	echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
	exit 1
fi
# MPP hardware RGBA — software videoconvert is ~1fps on RK3566.
if ! _vp_has "$PLUGIN" 'MppElementSetup: mppvideodec format=RGBA'; then
	echo "lws-hmi-sync-flutter-elinux: ERROR $PLUGIN missing MPP RGBA marker" >&2
	echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
	exit 1
fi
# Local MP4: sync=TRUE + synced handoff (1×); system clock required.
if ! _vp_has "$PLUGIN" 'VOD file sink uses clock sync'; then
	echo "lws-hmi-sync-flutter-elinux: ERROR $PLUGIN missing VOD clock-sync marker" >&2
	echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
	exit 1
fi
if ! _vp_has "$PLUGIN" 'VOD BufferProbe defers to synced handoff'; then
	echo "lws-hmi-sync-flutter-elinux: ERROR $PLUGIN missing VOD probe-defer marker" >&2
	echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
	exit 1
fi
if ! _vp_has "$PLUGIN" 'VOD pipeline uses system clock for sync'; then
	echo "lws-hmi-sync-flutter-elinux: ERROR $PLUGIN missing VOD system-clock marker" >&2
	echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
	exit 1
fi
# play() re-applies rate 1.0; vendored source skips the no-op FLUSH seek.
if ! _vp_has "$PLUGIN" 'SetPlaybackRate: skip no-op rate seek'; then
	echo "lws-hmi-sync-flutter-elinux: ERROR $PLUGIN missing no-op rate-seek skip marker" >&2
	echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
	exit 1
fi

install -d "$TARGET_DIR/usr/bin" "$TARGET_DIR/usr/lib"
install -m 0755 "$CLIENT" "$TARGET_DIR/usr/bin/flutter-wayland-client"
install -m 0755 "$PLUGIN" "$TARGET_DIR/usr/lib/libvideo_player_plugin.so"

pre_sz="$(wc -c <"$PLUGIN")"
tgt_sz="$(wc -c <"$TARGET_DIR/usr/lib/libvideo_player_plugin.so")"
if [ "$pre_sz" != "$tgt_sz" ]; then
	echo "lws-hmi-sync-flutter-elinux: ERROR plugin size mismatch after sync" >&2
	exit 1
fi
echo "lws-hmi-sync-flutter-elinux: ${VER} client+plugin synced ($tgt_sz bytes)"
