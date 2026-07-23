#!/bin/sh
# Mode-aware HMI launcher: Weston + eLinux (default) or flutter-pi (alternate).
set -eu

. /usr/libexec/hmi/paths.sh 2>/dev/null || true

BUNDLE=/opt/hmi
MODE_FILE="$BUNDLE/runtime-mode.json"
MODE=release
DISPLAY_CONF="${VAR_HAL:-/var/lib/hal}/display.conf"
LEGACY_ORIENTATION_FILE=/var/lib/hmi/display-orientation
LEGACY_ORIENTATION_HAL=/var/lib/hal/display-orientation
ETC_STACK="${ETC_DISPLAY_STACK:-/etc/display-stack}"
RUN_STACK="${RUN_DISPLAY_STACK:-/run/display-stack}"
ELINUX_CLIENT=/usr/bin/flutter-wayland-client

# Default matches ynh960 production (lcd0_rotation=90 → landscape_left).
FLUTTER_PI_ORIENTATION=landscape_left

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

# curl/OpenSSL tools. Dart HttpClient loads the same path explicitly in-app —
# flutter-pi default SecurityContext does not reliably honor SSL_CERT_* alone.
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

# Resolve orientation from display.conf; one-shot import legacy standalone file.
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
case "$token" in
portrait)
	FLUTTER_PI_ORIENTATION=portrait_up
	;;
landscape | "")
	FLUTTER_PI_ORIENTATION=landscape_left
	;;
*)
	echo "hmi-launch: unknown orientation '$token'; using landscape_left" >&2
	FLUTTER_PI_ORIENTATION=landscape_left
	;;
esac

if [ -f "$MODE_FILE" ]; then
	MODE="$(read_json_field "$MODE_FILE" mode)"
	MODE="${MODE:-release}"
fi

# Image embedder (baked by post-build): weston XOR flutter-pi — never mixed.
# Override: HMI_DISPLAY_STACK=weston|flutter-pi (debug only).
DISPLAY_STACK=weston
if [ -n "${HMI_DISPLAY_STACK:-}" ]; then
	DISPLAY_STACK="$(printf '%s' "$HMI_DISPLAY_STACK" | tr '[:upper:]' '[:lower:]')"
elif [ -f "$ETC_STACK" ]; then
	DISPLAY_STACK="$(tr -d '[:space:]' <"$ETC_STACK" | tr '[:upper:]' '[:lower:]')"
elif [ -f /etc/hmi/display-stack ]; then
	# Legacy image stamp fallback (partial upgrade).
	DISPLAY_STACK="$(tr -d '[:space:]' </etc/hmi/display-stack | tr '[:upper:]' '[:lower:]')"
fi

write_runtime_stack() {
	mkdir -p "$(dirname "$RUN_STACK")"
	printf '%s\n' "$1" >"$RUN_STACK"
}

# --- Weston + flutter-embedded-linux (default rootfs) ---
if [ "$DISPLAY_STACK" = weston ] || [ "$DISPLAY_STACK" = wayland ] || \
	[ "$DISPLAY_STACK" = elinux ]; then
	if [ ! -x /usr/bin/weston ] || [ ! -x "$ELINUX_CLIENT" ]; then
		echo "hmi-launch: display-stack=$DISPLAY_STACK but weston/client missing" >&2
		exit 1
	fi
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
	case "$FLUTTER_PI_ORIENTATION" in
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

	# HAL DisplayStackProbe reads this (Settings feature gates).
	write_runtime_stack weston

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
	# frame is composited black. Visual DPR parity with flutter-pi is done in
	# Dart (LwsHmiApp MediaQuery + Transform.scale) instead.
	set +e
	"$ELINUX_CLIENT" --bundle="$BUNDLE" --fullscreen
	status=$?
	set -e
	kill "$WESTON_PID" 2>/dev/null || true
	wait "$WESTON_PID" 2>/dev/null || true
	exit "$status"
fi

# --- flutter-pi (alternate rootfs) ---
if [ ! -x /usr/bin/flutter-pi ]; then
	echo "hmi-launch: display-stack=$DISPLAY_STACK but /usr/bin/flutter-pi missing" >&2
	exit 1
fi

if [ "$MODE" = "debug" ]; then
	VER="$(read_json_field "$MODE_FILE" engine_version)"
	RT="/var/lib/hmi/debug-runtime/${VER}"
	if [ -f "$RT/libflutter_engine.so" ] && [ -f "$RT/icudtl.dat" ]; then
		if [ ! -f "$BUNDLE/data/flutter_assets/kernel_blob.bin" ]; then
			echo "hmi-launch: missing debug kernel $BUNDLE/data/flutter_assets/kernel_blob.bin" >&2
			exit 1
		fi
		export FLUTTER_EMBEDDER_ICU_DATA_PATH="$RT/icudtl.dat"
		write_runtime_stack flutter-pi
		exec env LD_LIBRARY_PATH="$RT" /usr/bin/flutter-pi -o "$FLUTTER_PI_ORIENTATION" "$BUNDLE"
	fi
	echo "hmi-launch: debug runtime missing at $RT; falling back to release engine" >&2
	MODE=release
fi

if [ ! -f "$BUNDLE/lib/libapp.so" ]; then
	echo "hmi-launch: missing release AOT $BUNDLE/lib/libapp.so" >&2
	exit 1
fi

# Release path must match pre-P1.5 hmi.service: no LD_LIBRARY_PATH / ICU overrides.
write_runtime_stack flutter-pi
exec /usr/bin/flutter-pi --release -o "$FLUTTER_PI_ORIENTATION" "$BUNDLE"
