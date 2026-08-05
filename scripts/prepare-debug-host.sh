#!/usr/bin/env bash
# Prepare host for make debug-app / IDE custom-device: USB-SSH, registered SSH, or EMU.
# Skips USB ECM host config when IP=/registered MODE=SSH or MODE=EMU is selected.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

usb_ssh_session_load_env "$ROOT"

if ! usb_ssh_session_try_select "$ROOT"; then
	echo "HINT: no debug target.
  USB-SSH: plug OTG and re-run, or
  SSH:     enable LAN SSH on board, then: make connect <ip>
           and: IP=<ip> make debug-app   (or put IP= in .env)
  EMU:     make emulator, then: SN=SIM-EMU make debug-app
           or: IP=127.0.0.1:2222 make debug-app" >&2
	exit 1
fi

if usb_ssh_session_is_remote; then
	if is_emulator_ssh_endpoint "$TARGET_ADDR"; then
		echo "prepare-debug-host: EMU → $TARGET_USER@$TARGET_ADDR (no USB ECM setup)"
	else
		echo "prepare-debug-host: registered SSH → $TARGET_USER@$TARGET_ADDR (no USB ECM setup)"
	fi
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "${WAIT_SEC:-15}"
	exit 0
fi

echo "prepare-debug-host: USB-SSH → iface=$IFACE addr=$TARGET_ADDR"
# Ensure host ECM address; may prompt sudo on macOS.
bash "$ROOT/scripts/usb-ssh-host-setup.sh"
