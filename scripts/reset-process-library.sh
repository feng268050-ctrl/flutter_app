#!/usr/bin/env bash
# Clear process-library DB via running HMI (no restart), then force re-import
# bundled ship assets (lws-ui `make reset-process-library` intent; Linux uses
# cmd watcher like upgrade-process-library / upgrade-control-board).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

CMD_PATH="/run/hmi/reset-process-library.cmd"

usage() {
	cat <<EOF
Usage: make reset-process-library

Writes $CMD_PATH so the running HMI clears process_presets +
process_library_meta (including user rows) and force-reimports the bundled
process library. Does not restart hmi.service.

Prereq: HMI app is running (hmi.service) with the process-library command watcher.
EOF
}

die() {
	echo "ERROR: $*" >&2
	exit 1
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: writing reset command: $CMD_PATH"
remote "mkdir -p /run/hmi && printf 'reset\\n' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "OK: process-library reset command sent (no HMI restart)"
echo "INFO: filter device logs with: make logs GREP=ResetProcessLibrary"
