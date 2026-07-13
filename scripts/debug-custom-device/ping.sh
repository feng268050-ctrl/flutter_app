#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
usb_ssh_session_load_env "$ROOT"
if ! usb_ssh_session_select "$ROOT" 2>/dev/null; then
	exit 1
fi
configure_usb_ssh_host_addr "$IFACE"
ping_usb_ssh_target "$IFACE"
