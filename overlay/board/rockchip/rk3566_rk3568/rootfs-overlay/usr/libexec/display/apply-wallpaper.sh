#!/bin/sh
# Install a packaged wallpaper preset as the active system wallpaper.
# Copies /usr/share/hal/wallpapers/<id>.* → /var/lib/hal/wallpaper.<ext>
# and upserts display.conf wallpaper=<absolute path>.
# Does not restart UI; HAL callers restart the seat when needed.
# Usage: apply-wallpaper <preset-id>
set -eu

. /usr/libexec/board/paths.sh 2>/dev/null || true
PREF_DIR="${VAR_HAL:-/var/lib/hal}"
CONF="$PREF_DIR/display.conf"
PRESETS="${HAL_WALLPAPER_PRESETS:-/usr/share/hal/wallpapers}"

ID="${1:-}"
if [ -z "$ID" ]; then
	echo "usage: $0 <preset-id>" >&2
	exit 2
fi

# Reject path tricks.
case "$ID" in
*/*|*\\*|*".."*)
	echo "apply-wallpaper: invalid preset id: $ID" >&2
	exit 2
	;;
esac

SRC=""
for ext in png jpg jpeg webp PNG JPG JPEG WEBP; do
	cand="$PRESETS/$ID.$ext"
	if [ -f "$cand" ]; then
		SRC="$cand"
		break
	fi
done

if [ -z "$SRC" ]; then
	echo "apply-wallpaper: preset not found: $ID (under $PRESETS)" >&2
	exit 1
fi

# Keep extension on the active file so Weston/Flutter decode correctly.
ext="${SRC##*.}"
ACTIVE="$PREF_DIR/wallpaper.$ext"

mkdir -p "$PREF_DIR"
cp -f "$SRC" "$ACTIVE"
chmod 644 "$ACTIVE" 2>/dev/null || true

tmp="$(mktemp "$CONF.XXXXXX")"
if [ -f "$CONF" ]; then
	grep -vE '^wallpaper=' "$CONF" >"$tmp" 2>/dev/null || true
else
	: >"$tmp"
fi
printf 'wallpaper=%s\n' "$ACTIVE" >>"$tmp"
mv -f "$tmp" "$CONF"

echo "apply-wallpaper: $ID → $ACTIVE (persisted $CONF)"
