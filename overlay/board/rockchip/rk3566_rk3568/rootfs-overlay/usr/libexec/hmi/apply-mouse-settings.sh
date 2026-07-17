#!/bin/sh
# Write flutter-pi mouse.conf and persist under /var/lib/hmi.
# Usage:
#   apply-mouse-settings < conf-from-stdin
#   apply-mouse-settings --file <path>
#   apply-mouse-settings natural_scroll=0 scroll_speed=50 ...
set -eu

PREF_DIR=/var/lib/hmi
PREF="$PREF_DIR/mouse.conf"
TMP="$PREF.tmp.$$"
mkdir -p "$PREF_DIR"

write_and_commit() {
	# Normalize: ensure trailing newline
	if [ ! -s "$TMP" ]; then
		echo "apply-mouse-settings: empty config" >&2
		rm -f "$TMP"
		exit 1
	fi
	# Require at least one known key
	if ! grep -qE '^(natural_scroll|scroll_speed|pointer_speed|pointer_size|primary_button|pointer_axes)=' "$TMP"; then
		echo "apply-mouse-settings: no recognized keys" >&2
		rm -f "$TMP"
		exit 1
	fi
	mv -f "$TMP" "$PREF"
	echo "apply-mouse-settings: persisted $PREF"
}

if [ "${1:-}" = "--file" ]; then
	src="${2:-}"
	[ -n "$src" ] && [ -f "$src" ] || {
		echo "usage: $0 --file <path>" >&2
		exit 2
	}
	cp "$src" "$TMP"
	write_and_commit
	exit 0
fi

if [ "$#" -gt 0 ]; then
	: >"$TMP"
	for kv in "$@"; do
		case "$kv" in
		*=*) printf '%s\n' "$kv" >>"$TMP" ;;
		*)
			echo "apply-mouse-settings: bad arg (want key=value): $kv" >&2
			rm -f "$TMP"
			exit 2
			;;
		esac
	done
	write_and_commit
	exit 0
fi

cat >"$TMP"
write_and_commit
