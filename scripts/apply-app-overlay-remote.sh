#!/usr/bin/env bash
# Bootstrap / recovery: install OVERLAY_APP into /opt/hmi over SSH, then restart
# hmi.service. Uses BusyBox cp/mv (ETXTBSY-safe) — not the in-app installer.
#
# Use when the on-device HMI installer is broken/stale and cannot finish
# make upgrade-app. After one successful apply, signed upgrade-app works again.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: make apply-app-overlay | bash scripts/apply-app-overlay-remote.sh

Prereq: APP=\$APP make build-app
Env: APP= / SN= / IP=
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

[[ -d "$OVERLAY_APP" ]] || die "missing overlay app tree: $OVERLAY_APP (run: make build-app)"
[[ -f "$OVERLAY_APP/lib/libapp.so" ]] || die "missing $OVERLAY_APP/lib/libapp.so"
[[ -d "$OVERLAY_APP/data/flutter_assets" ]] || die "missing $OVERLAY_APP/data/flutter_assets"

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

STAGE=/var/lib/hmi/upgrade-app-staging
echo "INFO: streaming $OVERLAY_APP → $STAGE on device..."
remote "rm -rf '$STAGE' && mkdir -p '$STAGE'"
# Avoid macOS AppleDouble in the stream.
export COPYFILE_DISABLE=1
tar --exclude='._*' --exclude='.DS_Store' -C "$OVERLAY_APP" -cf - . \
	| usb_ssh_session_run_ssh "$ROOT" "$IFACE" "tar -C '$STAGE' -xf -"

echo "INFO: applying staging → /opt/hmi (shell)..."
remote "sh -s" <<'APPLY'
set -eu
STAGE=/var/lib/hmi/upgrade-app-staging
LIB="$STAGE/lib/libapp.so"
ASSETS="$STAGE/data/flutter_assets"
STAGE_BIN="$STAGE/bin"
NEXT_LIB=/opt/hmi/lib/.libapp.so.push-next
ASSETS_DIR=/opt/hmi/data/flutter_assets
NEXT_ASSETS=/opt/hmi/data/.flutter_assets.push-next
OLD_ASSETS=/opt/hmi/data/.flutter_assets.push-old

[ -f "$LIB" ] || { echo "missing $LIB" >&2; exit 1; }
[ -d "$ASSETS" ] || { echo "missing $ASSETS" >&2; exit 1; }

rm -f /var/lib/hmi/debug-app.pid /var/lib/hmi/debug-app.vm-service
mkdir -p /opt/hmi/lib /opt/hmi/bin /opt/hmi/data
rm -rf "$NEXT_LIB" "$NEXT_ASSETS" "$OLD_ASSETS"

install -D -m 0644 "$LIB" "$NEXT_LIB"
mkdir -p "$NEXT_ASSETS"
cp -a "$ASSETS/." "$NEXT_ASSETS/"

if [ -d "$STAGE_BIN" ]; then
	# Temp + mv so running MediaMTX/AI binaries do not ETXTBSY.
	for f in "$STAGE_BIN"/*; do
		[ -e "$f" ] || continue
		base="$(basename "$f")"
		[ "$base" = "ffmpeg" ] && continue
		tmp="/opt/hmi/bin/${base}.push-next"
		rm -f "$tmp"
		cp -a "$f" "$tmp"
		chmod 0755 "$tmp"
		mv -f "$tmp" "/opt/hmi/bin/$base"
	done
fi
rm -f /opt/hmi/bin/ffmpeg

if [ -d "$STAGE/lib" ]; then
	for f in "$STAGE/lib"/*; do
		[ -e "$f" ] || continue
		base="$(basename "$f")"
		[ "$base" = "libapp.so" ] && continue
		case "$base" in
			librknnrt.so*) continue ;;
			._*) continue ;;
		esac
		tmp="/opt/hmi/lib/${base}.push-next"
		rm -f "$tmp"
		cp -a "$f" "$tmp"
		mv -f "$tmp" "/opt/hmi/lib/$base"
	done
fi
rm -f /opt/hmi/lib/librknnrt.so* /opt/hmi/lib/*.push-next
sync

mv -f "$NEXT_LIB" /opt/hmi/lib/libapp.so
if [ -d "$ASSETS_DIR" ]; then
	mv "$ASSETS_DIR" "$OLD_ASSETS"
fi
if ! mv "$NEXT_ASSETS" "$ASSETS_DIR"; then
	[ ! -d "$OLD_ASSETS" ] || mv "$OLD_ASSETS" "$ASSETS_DIR"
	echo "failed to activate flutter_assets" >&2
	exit 1
fi
rm -rf "$OLD_ASSETS"

ENGINE_VER="$(cat /usr/share/flutter/flutter-engine.version 2>/dev/null \
	|| cat /etc/hmi/flutter-engine.version 2>/dev/null \
	|| echo 3.41.9)"
printf '%s\n' "{\"mode\":\"release\",\"engine_version\":\"${ENGINE_VER}\"}" >/opt/hmi/runtime-mode.json
sync

echo "INFO: restarting hmi.service..."
systemd-run --unit=hmi-restart-after-apply.service --collect \
	/bin/sh -c 'systemctl reset-failed hmi.service; systemctl restart hmi.service'
echo "OK: apply armed"
APPLY

echo "OK: overlay applied; hmi restart requested"
echo "INFO: filter logs with: make logs GREP=hmi"
