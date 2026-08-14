#!/bin/sh
# Persist mouse.conf (stdin) and apply to Weston when present.
# Weston needs ini rewrite + active Flutter seat restart
# only when the generated weston.ini content actually changes.
set -eu

. /usr/libexec/board/paths.sh 2>/dev/null || true
PREF_DIR="${VAR_HAL:-/var/lib/hal}"
PREF="$PREF_DIR/mouse.conf"
WESTON_CFG=/usr/libexec/display/weston-hmi-config.sh
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"
WESTON_INI="$RUNTIME_DIR/weston.ini"

if [ -f /usr/libexec/display/weston-hmi-config.sh ]; then
	# shellcheck source=/dev/null
	. /usr/libexec/display/weston-hmi-config.sh
	if ! input_policy_enabled physical_mouse_enabled; then
		echo "apply-mouse-settings: physical mouse disabled — skip" >&2
		cat >/dev/null
		exit 0
	fi
fi

mkdir -p "$PREF_DIR"
tmp="$PREF.tmp.$$"
cat >"$tmp"
mv -f "$tmp" "$PREF"
chmod 644 "$PREF" 2>/dev/null || true
echo "apply-mouse-settings: wrote $PREF" >&2

if [ ! -x /usr/bin/weston ]; then
	exit 0
fi

if [ ! -f "$WESTON_CFG" ]; then
	exit 0
fi

transform=rotate-270
if [ -f "$WESTON_INI" ]; then
	t="$(grep -E '^transform=' "$WESTON_INI" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
	if [ -n "$t" ]; then
		transform="$t"
	fi
fi

export MOUSE_CONF="$PREF"
BOARD_ID=""
if [ -f "${RUN_HMI:-/run/hmi}/oem.env" ]; then
	# shellcheck disable=SC1090
	. "${RUN_HMI:-/run/hmi}/oem.env" 2>/dev/null || true
	BOARD_ID="${BOARD_ID:-}"
fi
export BOARD_ID
# shellcheck source=/dev/null
. "$WESTON_CFG"

ini_tmp="$WESTON_INI.apply.$$"
weston_write_hmi_ini "$ini_tmp" "$transform"

ini_changed=1
if [ -f "$WESTON_INI" ] && cmp -s "$ini_tmp" "$WESTON_INI"; then
	ini_changed=0
fi
mv -f "$ini_tmp" "$WESTON_INI"

if [ "$ini_changed" -eq 0 ]; then
	echo "apply-mouse-settings: weston.ini unchanged → skip restart" >&2
	exit 0
fi

# Avoid start-limit-hit loops (e.g. boot restore re-touching conf).
if [ -f /run/lws-mouse-seat-restart ]; then
	age=$(($(date +%s) - $(date -r /run/lws-mouse-seat-restart +%s 2>/dev/null || echo 0)))
	if [ "$age" -ge 0 ] && [ "$age" -lt 15 ]; then
		echo "apply-mouse-settings: restart suppressed (debounced ${age}s)" >&2
		exit 0
	fi
fi

if pidof weston >/dev/null 2>&1; then
	echo "apply-mouse-settings: weston.ini changed → restarting active Flutter seat" >&2
	date +%s >/run/lws-mouse-seat-restart 2>/dev/null || true
	if [ -x /usr/libexec/hmi/restart-flutter-seat.sh ]; then
		/usr/libexec/hmi/restart-flutter-seat.sh
	fi
fi

exit 0
