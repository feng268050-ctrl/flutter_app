#!/usr/bin/env bash
# Open an interactive shell on the target over USB-SSH or registered remote SSH (make shell).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
require_sshpass

if usb_ssh_session_is_remote; then
	echo "Opening shell on ${TARGET_USER}@${TARGET_ADDR} (SSH)..."
	remote_ssh_run "$TARGET_ADDR"
else
	echo "Opening shell on ${TARGET_USER}@${TARGET_ADDR} via $IFACE..."
	usb_ssh_run "$IFACE"
fi
