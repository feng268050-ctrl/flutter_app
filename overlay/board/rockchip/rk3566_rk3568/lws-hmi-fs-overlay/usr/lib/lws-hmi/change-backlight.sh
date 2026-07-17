#!/bin/sh
# Apply backlight percent (0–100) to sysfs and persist for boot restore.
# Usage: change-backlight <percent>
set -eu

PCT="${1:-}"
case "$PCT" in
''|*[!0-9]*)
	echo "usage: $0 <0-100>" >&2
	exit 2
	;;
esac
if [ "$PCT" -gt 100 ]; then
	PCT=100
fi

CLASS=/sys/class/backlight
pick=
for name in backlight backlight1 backlight2; do
	if [ -f "$CLASS/$name/brightness" ]; then
		pick="$CLASS/$name"
		break
	fi
done
if [ -z "$pick" ]; then
	for d in "$CLASS"/*; do
		[ -d "$d" ] || continue
		base="$(basename "$d")"
		case "$base" in
		led-*|led_*) continue ;;
		esac
		[ -f "$d/brightness" ] || continue
		pick="$d"
		break
	done
fi
if [ -z "$pick" ] || [ ! -f "$pick/brightness" ]; then
	echo "change-backlight: no backlight device" >&2
	exit 1
fi

max=255
if [ -f "$pick/max_brightness" ]; then
	max="$(tr -d '[:space:]' <"$pick/max_brightness")"
	[ -n "$max" ] && [ "$max" -gt 0 ] 2>/dev/null || max=255
fi
# percent → device value
val=$((PCT * max / 100))
printf '%s\n' "$val" >"$pick/brightness"

# Same path as LinuxSysfsBacklight / restore-settings.sh (userdata via bind-prefs).
PREF_DIR=/var/lib/lws-hmi
PREF="$PREF_DIR/backlight-brightness"
mkdir -p "$PREF_DIR"
printf '%s\n' "$PCT" >"$PREF"

echo "change-backlight: $PCT% → $val/$max ($pick); persisted $PREF"
