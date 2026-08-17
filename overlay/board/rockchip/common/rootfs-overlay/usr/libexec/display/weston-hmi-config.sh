#!/bin/sh
# Shared Weston HMI config helpers (sourced by hmi-launch / apply-mouse-settings).
# shellcheck shell=sh

MOUSE_CONF_DEFAULT=/var/lib/hal/mouse.conf
INPUT_CONF_DEFAULT=/var/lib/hal/input.conf
DISPLAY_CONF_DEFAULT=/var/lib/hal/display.conf
BOOT_SPLASH_DEFAULT=/usr/share/hmi/boot-splash.png

mouse_conf_get() {
	# usage: mouse_conf_get <key> <default> [conf_path]
	key="$1"
	default="$2"
	conf="${3:-${MOUSE_CONF:-$MOUSE_CONF_DEFAULT}}"
	if [ ! -f "$conf" ]; then
		printf '%s\n' "$default"
		return 0
	fi
	raw="$(grep -E "^${key}=" "$conf" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
	if [ -z "$raw" ]; then
		printf '%s\n' "$default"
		return 0
	fi
	printf '%s\n' "$raw"
}

# physical_*_enabled in input.conf — missing → enabled (1).
input_policy_enabled() {
	key="$1"
	conf="${INPUT_CONF:-$INPUT_CONF_DEFAULT}"
	if [ ! -f "$conf" ]; then
		return 0
	fi
	raw="$(grep -E "^${key}=" "$conf" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
	case "$raw" in
	0 | false | FALSE | no | NO | off | OFF) return 1 ;;
	*) return 0 ;;
	esac
}

# Desktop-shell background until Flutter's first frame (logo bridge).
# Prefer the small boot-splash for cold-start KPI; operator wallpaper from
# display.conf / /var/lib/hal/wallpaper.* still wins when set. Do not use the
# full Home backdrop (home_back.png) here — Flutter paints that itself.
weston_resolve_background_image() {
	display_conf="${DISPLAY_CONF:-$DISPLAY_CONF_DEFAULT}"
	splash="${HMI_BOOT_SPLASH:-$BOOT_SPLASH_DEFAULT}"
	pref_dir="$(dirname "$display_conf")"

	stored="$(mouse_conf_get wallpaper "" "$display_conf")"
	if [ -n "$stored" ] && [ -f "$stored" ]; then
		printf '%s\n' "$stored"
		return 0
	fi

	for cand in "$pref_dir"/wallpaper.png "$pref_dir"/wallpaper.jpg \
		"$pref_dir"/wallpaper.jpeg "$pref_dir"/wallpaper.webp; do
		if [ -f "$cand" ]; then
			printf '%s\n' "$cand"
			return 0
		fi
	done

	printf '%s\n' "$splash"
}

# Compositor cursors look larger than reference density icons — keep modest.
# 0%→20px, 50%→30px, 100%→40px (clamp 16–40).
mouse_pointer_size_to_cursor_px() {
	p="$1"
	case "$p" in
	'' | *[!0-9]*) p=20 ;;
	esac
	if [ "$p" -gt 100 ]; then
		p=100
	fi
	awk -v p="$p" 'BEGIN {
		s = int(20 + (p * 20) / 100 + 0.5)
		if (s < 16) s = 16
		if (s > 40) s = 40
		print s
	}'
}

# pointer_speed 0–100 → libinput accel-speed ∈ [-1, 1]
mouse_pointer_speed_to_accel() {
	p="$1"
	case "$p" in
	'' | *[!0-9]*) p=50 ;;
	esac
	if [ "$p" -gt 100 ]; then
		p=100
	fi
	awk -v p="$p" 'BEGIN { printf "%.3f\n", (p / 100.0) * 2.0 - 1.0 	}'
}

# USB / by-id pointer HID (excludes virtio tablet — touch bridge owns pointer path).
emulator_usb_pointer_present() {
	for pattern in /dev/input/by-id/*-mouse /dev/input/by-id/*event-mouse*; do
		# shellcheck disable=SC2086
		for f in $pattern; do
			[ -e "$f" ] || continue
			return 0
		done
	done
	for pattern in /dev/input/by-path/*-mouse /dev/input/by-path/*event-mouse*; do
		# shellcheck disable=SC2086
		for f in $pattern; do
			[ -e "$f" ] || continue
			case "$f" in *usb*) return 0 ;; esac
		done
	done
	return 1
}

# LWS uinput touch from emulator-tablet-to-touch (or board Goodix).
emulator_touch_input_present() {
	if grep -q 'Name="LWS Emulator Touch"' /proc/bus/input/devices 2>/dev/null; then
		return 0
	fi
	for pattern in /dev/input/by-id/*-touch* /dev/input/by-path/*-touch*; do
		# shellcheck disable=SC2086
		for f in $pattern; do
			[ -e "$f" ] && return 0
		done
	done
	return 1
}

# Write runtime weston.ini for HMI (DRM + splash bridge + mouse prefs).
# desktop-shell (not kiosk): kiosk only has solid background-color; we need
# background-image so the product logo survives until Flutter's first frame
# (legacy DRM stacks kept kernel drm_logo).
# Splash PNG is icon-sized (make build-boot-logo); pad + black centers on output.
# usage: weston_write_hmi_ini <out_path> <transform>
weston_write_hmi_ini() {
	out="$1"
	transform="${2:-rotate-270}"
	conf="${MOUSE_CONF:-$MOUSE_CONF_DEFAULT}"
	# System wallpaper (Flutter + Weston). Falls back to boot-splash.png.
	splash="$(weston_resolve_background_image)"

	pointer_size="$(mouse_conf_get pointer_size 20 "$conf")"
	pointer_speed="$(mouse_conf_get pointer_speed 50 "$conf")"
	natural="$(mouse_conf_get natural_scroll 0 "$conf")"
	primary="$(mouse_conf_get primary_button left "$conf")"

	cursor_px="$(mouse_pointer_size_to_cursor_px "$pointer_size")"
	accel="$(mouse_pointer_speed_to_accel "$pointer_speed")"

	emulator_touch_only=0
	if [ "${BOARD_ID:-}" = "sim" ] || grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null; then
		if emulator_touch_input_present && ! emulator_usb_pointer_present; then
			emulator_touch_only=1
			cursor_px=0
		fi
	fi

	if ! input_policy_enabled physical_mouse_enabled; then
		cursor_px=0
	fi

	case "$natural" in
	1 | true | TRUE | yes | YES) natural_ini=true ;;
	*) natural_ini=false ;;
	esac

	case "$primary" in
	right) left_handed=true ;;
	*) left_handed=false ;;
	esac

	output_name="DSI-1"
	output_mode="800x1280"
	# P3.2 QEMU / sim: virtio-gpu is Virtual-1 (not DSI); size from OEM screen.env.
	if [ "${BOARD_ID:-}" = "sim" ] || grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null; then
		output_name="Virtual-1"
		# Emulator virtio-gpu: default 1536×960 (matches run-emulator.sh + screens/virt).
		output_mode="1536x960"
		if [ -f "${RUN_HMI:-/run/hmi}/screen.env" ]; then
			# shellcheck source=/dev/null
			. "${RUN_HMI:-/run/hmi}/screen.env"
			if [ -n "${SCREEN_WIDTH:-}" ] && [ -n "${SCREEN_HEIGHT:-}" ]; then
				output_mode="${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
			fi
		fi
		# Prefer the first connected non-writeback connector if present.
		for card in /sys/class/drm/card*-*; do
			[ -e "$card/status" ] || continue
			case "$card" in
			*Writeback* | *writeback*) continue ;;
			esac
			[ "$(cat "$card/status" 2>/dev/null || true)" = "connected" ] || continue
			output_name="$(basename "$card" | sed 's/^card[0-9]*-//')"
			# virtio-gpu modes sysfs can be empty/stale on first boot after cold
			# start. Falling back to 1920x1080 widens the host QEMU window until
			# the next restart — trust OEM/QEMU xres/yres instead.
			modes_file="$card/modes"
			if [ -f "$modes_file" ] && ! grep -qx "${output_mode}" "$modes_file" 2>/dev/null; then
				echo "weston-hmi-config: emulator — keeping mode $output_mode (EDID/sysfs not ready: $(tr '\n' ' ' <"$modes_file" 2>/dev/null | sed 's/ $//'))" >&2
			fi
			break
		done
	fi

	mkdir -p "$(dirname "$out")"
	cat >"$out" <<EOF
[core]
backend=drm-backend.so
shell=desktop-shell.so
idle-time=0

[shell]
locking=false
animation=none
startup-animation=none
panel-position=none
background-image=$splash
background-type=pad
background-color=0xff000000
cursor-size=$cursor_px

[libinput]
natural-scroll=$natural_ini
left-handed=$left_handed
accel-profile=adaptive
accel-speed=$accel

[keyboard]
# Advertised to Wayland clients via wl_keyboard.repeat_info (client must
# implement repeat; flutter-elinux historically ignored this — CyberIME
# synthesizes hold-repeat until the embedder is fixed).
repeat-rate=25
repeat-delay=500

# Product soft IME is CyberIME. Empty path= still falls back to
# @libexecdir@/weston-keyboard on Weston 14.0.1 — use a non-executable
# sentinel so the client is never started (~23 MB RSS saved).
[input-method]
path=/bin/false

[output]
name=$output_name
mode=$output_mode
transform=$transform
EOF
	export XCURSOR_SIZE="$cursor_px"
	if [ "$emulator_touch_only" -eq 1 ]; then
		echo "weston-hmi-config: emulator touch-only — cursor hidden (no USB pointer HID)" >&2
	fi
	echo "weston-hmi-config: output=$output_name mode=$output_mode transform=$transform shell=desktop-shell splash=$splash cursor-size=$cursor_px pointer_size=${pointer_size}% accel=$accel natural=$natural_ini left_handed=$left_handed" >&2
}
