#!/bin/sh
# Shared Weston HMI config helpers (sourced by hmi-launch / apply-mouse-settings).
# shellcheck shell=sh

MOUSE_CONF_DEFAULT=/var/lib/hal/mouse.conf

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
	awk -v p="$p" 'BEGIN { printf "%.3f\n", (p / 100.0) * 2.0 - 1.0 }'
}

# Write runtime weston.ini for ynh960 HMI (DRM + splash bridge + mouse prefs).
# desktop-shell (not kiosk): kiosk only has solid background-color; we need
# background-image so the product logo survives until Flutter's first frame
# (legacy DRM stacks kept kernel drm_logo).
# usage: weston_write_hmi_ini <out_path> <transform>
weston_write_hmi_ini() {
	out="$1"
	transform="${2:-rotate-270}"
	conf="${MOUSE_CONF:-$MOUSE_CONF_DEFAULT}"
	splash="${HMI_BOOT_SPLASH:-/usr/share/hmi/boot-splash.png}"

	pointer_size="$(mouse_conf_get pointer_size 20 "$conf")"
	pointer_speed="$(mouse_conf_get pointer_speed 50 "$conf")"
	natural="$(mouse_conf_get natural_scroll 0 "$conf")"
	primary="$(mouse_conf_get primary_button left "$conf")"

	cursor_px="$(mouse_pointer_size_to_cursor_px "$pointer_size")"
	accel="$(mouse_pointer_speed_to_accel "$pointer_speed")"

	case "$natural" in
	1 | true | TRUE | yes | YES) natural_ini=true ;;
	*) natural_ini=false ;;
	esac

	case "$primary" in
	right) left_handed=true ;;
	*) left_handed=false ;;
	esac

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
background-type=scale
background-color=0xffffffff
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

[output]
name=DSI-1
mode=800x1280
transform=$transform
EOF
	export XCURSOR_SIZE="$cursor_px"
	echo "weston-hmi-config: shell=desktop-shell splash=$splash cursor-size=$cursor_px pointer_size=${pointer_size}% accel=$accel natural=$natural_ini left_handed=$left_handed" >&2
}
