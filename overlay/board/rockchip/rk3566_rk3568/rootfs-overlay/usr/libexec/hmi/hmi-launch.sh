#!/bin/sh
# Mode-aware HMI launcher: Weston + flutter-wayland-client (eLinux).
set -eu

# Match systemd IgnoreSIGPIPE=yes. Outside hmi.service (make debug-app via
# start-stop-daemon) a SIGPIPE from Wayland/DBus/helper teardown would exit
# the embedder with code 141 and tear down Weston.
trap '' PIPE

. /usr/libexec/hmi/paths.sh 2>/dev/null || true

BUNDLE=/opt/hmi
MODE_FILE="$BUNDLE/runtime-mode.json"
MODE=release
DISPLAY_CONF="${VAR_HAL:-/var/lib/hal}/display.conf"
LEGACY_ORIENTATION_FILE=/var/lib/hmi/display-orientation
LEGACY_ORIENTATION_HAL=/var/lib/hal/display-orientation
ELINUX_CLIENT=/usr/bin/flutter-wayland-client

# Last-resort removed: orientation MUST come from display.conf or OEM screen.env.
HMI_ORIENTATION=
SCREEN_ENV="${RUN_HMI:-/run/hmi}/screen.env"

# RK809 speaker path (ParamUpdate also sets this; re-assert before HMI audio smoke).
if command -v amixer >/dev/null 2>&1; then
	amixer -q sset 'Playback Path' 'RING_SPK_HP' 2>/dev/null || true
fi

# Align lock LEDs with a fresh xkb_state (all clear) before embedder opens input.
# Stale LED-on + Mod2-off looks like an inverted keypad.
for led in /sys/class/leds/input*::numlock /sys/class/leds/input*::capslock \
	/sys/class/leds/input*::scrolllock; do
	[ -w "$led/brightness" ] || continue
	echo 0 >"$led/brightness" 2>/dev/null || true
done

# curl/OpenSSL tools. Dart HttpClient loads the same path explicitly in-app.
if [ -s /etc/ssl/certs/ca-certificates.crt ]; then
	export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
	export SSL_CERT_DIR=/etc/ssl/certs
fi

read_json_field() {
	file="$1"
	key="$2"
	grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
		| sed 's/.*"\([^"]*\)"$/\1/' \
		| head -1
}

conf_get() {
	# usage: conf_get <file> <key>
	file="$1"
	key="$2"
	[ -f "$file" ] || return 0
	grep -E "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]'
}

upsert_conf_key() {
	conf="$1"
	key="$2"
	value="$3"
	mkdir -p "$(dirname "$conf")"
	tmp="$(mktemp "${conf}.XXXXXX")"
	if [ -f "$conf" ]; then
		grep -vE "^${key}=" "$conf" >"$tmp" 2>/dev/null || true
	else
		: >"$tmp"
	fi
	printf '%s=%s\n' "$key" "$value" >>"$tmp"
	mv -f "$tmp" "$conf"
}

# Resolve orientation: operator display.conf → OEM screen.env (no silent default).
token="$(conf_get "$DISPLAY_CONF" orientation | tr '[:upper:]' '[:lower:]')"
if [ -z "$token" ]; then
	for legacy in "$LEGACY_ORIENTATION_HAL" "$LEGACY_ORIENTATION_FILE"; do
		if [ -f "$legacy" ]; then
			token="$(tr -d '[:space:]' <"$legacy" | tr '[:upper:]' '[:lower:]')"
			case "$token" in
			portrait | landscape)
				upsert_conf_key "$DISPLAY_CONF" orientation "$token"
				rm -f "$legacy"
				;;
			*)
				token=""
				;;
			esac
			break
		fi
	done
fi
orient_src=display.conf
if [ -z "$token" ]; then
	[ -f "$SCREEN_ENV" ] || {
		echo "hmi-launch: missing $SCREEN_ENV — oem-compose must succeed first" >&2
		exit 1
	}
	# shellcheck source=/dev/null
	. "$SCREEN_ENV"
	token="$(printf '%s' "${SCREEN_DEFAULT_ORIENTATION:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
	orient_src="$SCREEN_ENV"
fi
[ -n "$token" ] || {
	echo "hmi-launch: empty orientation (display.conf and SCREEN_DEFAULT_ORIENTATION) — fix OEM screen.json" >&2
	exit 1
}
case "$token" in
portrait | portrait_up)
	HMI_ORIENTATION=portrait_up
	;;
landscape | landscape_left)
	HMI_ORIENTATION=landscape_left
	;;
landscape_right)
	HMI_ORIENTATION=landscape_right
	;;
portrait_down)
	HMI_ORIENTATION=portrait_down
	;;
*)
	echo "hmi-launch: unknown orientation '$token' from $orient_src" >&2
	exit 1
	;;
esac
echo "hmi-launch: orientation=$HMI_ORIENTATION (from $orient_src)" >&2

if [ -f "$MODE_FILE" ]; then
	MODE="$(read_json_field "$MODE_FILE" mode)"
	MODE="${MODE:-release}"
fi

if [ ! -x /usr/bin/weston ] || [ ! -x "$ELINUX_CLIENT" ]; then
	echo "hmi-launch: weston or flutter-wayland-client missing" >&2
	exit 1
fi

# Debug: same client binary + cached debug engine via LD_LIBRARY_PATH (Sony).
# Fail closed — never fall back to AOT libapp.so against a JIT-only tree.
ELINUX_LD_LIBRARY_PATH=
if [ "$MODE" = "debug" ]; then
	VER="$(read_json_field "$MODE_FILE" engine_version)"
	RT="/var/lib/hmi/debug-runtime/${VER}"
	if [ -z "$VER" ]; then
		echo "hmi-launch: debug mode missing engine_version in $MODE_FILE" >&2
		exit 1
	fi
	if [ ! -f "$RT/libflutter_engine.so" ] || [ ! -f "$RT/icudtl.dat" ]; then
		echo "hmi-launch: debug runtime incomplete at $RT" >&2
		echo "hmi-launch: need libflutter_engine.so and icudtl.dat (make debug-app)" >&2
		exit 1
	fi
	if [ ! -f "$BUNDLE/data/flutter_assets/kernel_blob.bin" ]; then
		echo "hmi-launch: missing debug kernel $BUNDLE/data/flutter_assets/kernel_blob.bin" >&2
		exit 1
	fi
	# eLinux DartProject expects ICU at <bundle>/data/icudtl.dat.
	if [ ! -e "$BUNDLE/data/icudtl.dat" ]; then
		mkdir -p "$BUNDLE/data"
		cp -L "$RT/icudtl.dat" "$BUNDLE/data/icudtl.dat" 2>/dev/null || {
			echo "hmi-launch: failed to install $BUNDLE/data/icudtl.dat from $RT" >&2
			exit 1
		}
	fi
	ELINUX_LD_LIBRARY_PATH="$RT"
else
	if [ ! -f "$BUNDLE/lib/libapp.so" ]; then
		echo "hmi-launch: missing release AOT $BUNDLE/lib/libapp.so" >&2
		exit 1
	fi
	# eLinux looks for ICU next to the bundle.
	if [ ! -e "$BUNDLE/data/icudtl.dat" ]; then
		for icu in \
			/usr/share/flutter/release/data/icudtl.dat \
			/usr/share/flutter/icudtl.dat; do
			if [ -e "$icu" ]; then
				mkdir -p "$BUNDLE/data"
				cp -L "$icu" "$BUNDLE/data/icudtl.dat" 2>/dev/null || true
				break
			fi
		done
	fi
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/0}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

# GStreamer (Sony video_player) expects a writable cache for the plugin
# registry. systemd does not set HOME for hmi.service.
export HOME="${HOME:-/root}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$XDG_CACHE_HOME"

# Rockchip post-hook 10-weston overwrites /etc/xdg/weston/weston.ini.
# Own config via --config under XDG_RUNTIME_DIR (transform + mouse prefs).
case "$HMI_ORIENTATION" in
portrait_up)
	WESTON_TRANSFORM=normal
	;;
*)
	WESTON_TRANSFORM=rotate-270
	;;
esac

# shellcheck source=/dev/null
. /usr/libexec/hmi/weston-hmi-config.sh
WESTON_INI="$XDG_RUNTIME_DIR/weston.ini"
weston_write_hmi_ini "$WESTON_INI" "$WESTON_TRANSFORM"

# desktop-shell.so: paints boot-splash.png until Flutter covers it.
# (kiosk-shell cannot show a background image — only a solid color.)
weston --config="$WESTON_INI" --backend=drm-backend.so \
	--shell=desktop-shell.so --idle-time=0 &
WESTON_PID=$!
i=0
while [ "$i" -lt 50 ]; do
	if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
		break
	fi
	# BusyBox may lack fractional sleep; fall back to 1s.
	sleep 0.1 2>/dev/null || sleep 1
	i=$((i + 1))
done
if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
	echo "hmi-launch: weston Wayland socket missing at $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" >&2
	kill "$WESTON_PID" 2>/dev/null || true
	exit 1
fi

# Keep shell as main PID so we can stop Weston when the client exits.
# Do NOT use --force-scale-factor: on this board it presents FPS but the
# frame is composited black. Visual DPR is done in Dart (LwsHmiApp).
set +e
if [ -n "$ELINUX_LD_LIBRARY_PATH" ]; then
	env LD_LIBRARY_PATH="$ELINUX_LD_LIBRARY_PATH" \
		"$ELINUX_CLIENT" --bundle="$BUNDLE" --fullscreen
else
	"$ELINUX_CLIENT" --bundle="$BUNDLE" --fullscreen
fi
status=$?
set -e
kill "$WESTON_PID" 2>/dev/null || true
wait "$WESTON_PID" 2>/dev/null || true
exit "$status"
