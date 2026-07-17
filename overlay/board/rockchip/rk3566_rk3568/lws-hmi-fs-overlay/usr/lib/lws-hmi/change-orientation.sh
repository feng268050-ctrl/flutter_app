#!/bin/sh
# Persist display orientation for hmi-launch.sh (portrait|landscape).
# Usage: change-orientation <portrait|landscape>
# Does not restart HMI; callers (Demo) restart when needed.
set -eu

MODE="${1:-}"
case "$MODE" in
portrait|landscape) ;;
*)
	echo "usage: $0 <portrait|landscape>" >&2
	exit 2
	;;
esac

PREF_DIR=/var/lib/lws-hmi
PREF="$PREF_DIR/display-orientation"
mkdir -p "$PREF_DIR"
printf '%s\n' "$MODE" >"$PREF"
echo "change-orientation: $MODE; persisted $PREF"
