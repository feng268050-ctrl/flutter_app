#!/bin/sh
# Print the active OEM board_id (ynh960, ek3562, sim, …).
# Source of truth: oem-compose stamps, then /run/hmi/oem.env, then /oem/manifest.json.
set -eu

id=""
if [ -f /run/hmi/board_id ]; then
	id="$(tr -d '[:space:]' </run/hmi/board_id)"
elif [ -f /run/hmi/oem.env ]; then
	# shellcheck disable=SC1091
	. /run/hmi/oem.env
	id="${BOARD_ID:-}"
elif [ -f /oem/manifest.json ]; then
	id="$(sed -n 's/.*"board_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
fi

if [ -z "$id" ]; then
	echo "board-id: unknown (oem-compose has not run /oem missing)" >&2
	exit 1
fi
printf '%s\n' "$id"
