#!/bin/sh
# Apply make push-app staging payload while HMI runs, then restart it.
# Host invokes this via setsid/nohup so the SSH channel need not survive hmi
# stop (Wi-Fi lives in wlan-wpa / wlan-dhcp, not the hmi cgroup).
set -eu

STAGE=/var/lib/hmi/push-app-staging
LIB="$STAGE/lib/libapp.so"
ASSETS="$STAGE/data/flutter_assets"
STAGE_BIN="$STAGE/bin"
NEXT_LIB=/opt/hmi/lib/.libapp.so.push-next
ASSETS_DIR=/opt/hmi/data/flutter_assets
NEXT_ASSETS=/opt/hmi/data/.flutter_assets.push-next
OLD_ASSETS=/opt/hmi/data/.flutter_assets.push-old
STATUS=/var/lib/hmi/push-app-apply.status
MAX_START_ATTEMPTS=3

log() {
	echo "push-app: $*"
}

set_status() {
	printf '%s\n' "$1" >"$STATUS"
	sync
}

fail() {
	log "$1"
	set_status fail
	exit 1
}

# True when the HMI embedder process is up (wayland client or DRM runner).
hmi_embedder_running() {
	pidof flutter-wayland-client >/dev/null 2>&1 && return 0
	return 1
}

mkdir -p /var/lib/hmi
set_status running

[ -f "$LIB" ] || fail "missing $LIB"
[ -d "$ASSETS" ] || fail "missing $ASSETS"

log "installing libapp.so and flutter_assets before restart"
rm -f /var/lib/hmi/debug-app.pid /var/lib/hmi/debug-app.vm-service
mkdir -p /opt/hmi/lib /opt/hmi/bin /opt/hmi/data/flutter_assets
rm -rf "$NEXT_LIB" "$NEXT_ASSETS" "$OLD_ASSETS"
install -D -m 0644 "$LIB" "$NEXT_LIB"
mkdir -p "$NEXT_ASSETS"
cp -a "$ASSETS/." "$NEXT_ASSETS/"
# Product binaries / shared libs from the same build-app tree (MediaMTX, AI, OpenCV…).
if [ -d "$STAGE_BIN" ]; then
	log "installing /opt/hmi/bin companions"
	cp -a "$STAGE_BIN/." /opt/hmi/bin/
	chmod 0755 /opt/hmi/bin/* 2>/dev/null || true
fi
# Covers/AI samples use rootfs extract-video-frame — drop retired App ffmpeg.
rm -f /opt/hmi/bin/ffmpeg
# Copy every staged lib except the AOT payload (installed atomically below).
if [ -d "$STAGE/lib" ]; then
	log "installing /opt/hmi/lib companions"
	for f in "$STAGE/lib"/*; do
		[ -e "$f" ] || continue
		base="$(basename "$f")"
		[ "$base" = "libapp.so" ] && continue
		cp -a "$f" /opt/hmi/lib/
	done
fi
# System RKNN lives in /usr/lib; drop any legacy App-bundled copy so
# LD_LIBRARY_PATH=/opt/hmi/lib cannot shadow it.
rm -f /opt/hmi/lib/librknnrt.so*
sync

mv -f "$NEXT_LIB" /opt/hmi/lib/libapp.so
if [ -d "$ASSETS_DIR" ]; then
	mv "$ASSETS_DIR" "$OLD_ASSETS"
fi
if ! mv "$NEXT_ASSETS" "$ASSETS_DIR"; then
	[ ! -d "$OLD_ASSETS" ] || mv "$OLD_ASSETS" "$ASSETS_DIR"
	fail "failed to activate flutter_assets"
fi
rm -rf "$OLD_ASSETS"

ENGINE_VER="$(cat /usr/share/flutter/flutter-engine.version 2>/dev/null \
	|| cat /etc/hmi/flutter-engine.version 2>/dev/null \
	|| echo 3.41.9)"
printf '%s\n' "{\"mode\":\"release\",\"engine_version\":\"${ENGINE_VER}\"}" >/opt/hmi/runtime-mode.json
sync

log "stopping hmi.service for restart"
/usr/libexec/hmi/hmi-stop-and-wait.sh

attempt=1
while [ "$attempt" -le "$MAX_START_ATTEMPTS" ]; do
	log "restart attempt $attempt/$MAX_START_ATTEMPTS"
	systemctl reset-failed hmi.service
	systemctl start hmi.service || true
	# Allow compositor + client (or DRM runner) to come up before probing.
	sleep 2
	if systemctl is-active --quiet hmi.service && hmi_embedder_running; then
		log "restart complete"
		set_status ok
		exit 0
	fi
	attempt=$((attempt + 1))
done

log "hmi.service did not recover after $MAX_START_ATTEMPTS attempts"
systemctl status hmi.service --no-pager -l || true
set_status fail
exit 1
