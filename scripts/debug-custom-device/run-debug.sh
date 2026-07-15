#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

if ! usb_ssh_session_run_ssh "$ROOT" "$IFACE" "test -x /usr/lib/lws-hmi/debug-app-run.sh"; then
	echo "ERROR: /usr/lib/lws-hmi/debug-app-run.sh not found on board" >&2
	exit 1
fi

usb_ssh_session_run_ssh "$ROOT" "$IFACE" /usr/lib/lws-hmi/debug-app-run.sh
