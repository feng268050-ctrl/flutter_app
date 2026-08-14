#!/bin/sh
# Persist display orientation for hmi-launch.sh (portrait|landscape).
# Writes /var/lib/hal/display.conf key orientation= (upsert).
# Usage: change-orientation <portrait|landscape>
# Does not restart HMI; callers restart when needed.
set -eu

. /usr/libexec/board/paths.sh 2>/dev/null || true
PREF_DIR="${VAR_HAL:-/var/lib/hal}"
CONF="$PREF_DIR/display.conf"

MODE="${1:-}"
case "$MODE" in
portrait|landscape) ;;
*)
	echo "usage: $0 <portrait|landscape>" >&2
	exit 2
	;;
esac

mkdir -p "$PREF_DIR"
tmp="$(mktemp "$CONF.XXXXXX")"
if [ -f "$CONF" ]; then
	grep -vE '^orientation=' "$CONF" >"$tmp" 2>/dev/null || true
else
	: >"$tmp"
fi
printf 'orientation=%s\n' "$MODE" >>"$tmp"
mv -f "$tmp" "$CONF"
# Drop legacy standalone file if present.
rm -f "$PREF_DIR/display-orientation" /var/lib/hmi/display-orientation
echo "change-orientation: $MODE; persisted $CONF (orientation=)"
