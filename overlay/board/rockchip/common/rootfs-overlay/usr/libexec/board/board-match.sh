#!/bin/sh
# Exit 0 if the active OEM board_id equals $1 (e.g. board-match ynh960).
set -eu
want="${1:?usage: board-match <board_id>}"
got="$(/usr/libexec/board/board-id.sh)" || exit 1
[ "$got" = "$want" ]
