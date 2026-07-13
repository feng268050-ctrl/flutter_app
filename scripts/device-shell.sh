#!/usr/bin/env bash
# Open an interactive shell on the target over USB ECM SSH (make shell).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"
SERIAL="${SERIAL:-${LWS_HMI_SERIAL:-}}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

sel=()
while IFS= read -r line; do
	sel+=("$line")
done < <(SERIAL="$SERIAL" bash "$ROOT/scripts/usb-ssh-devices.sh" --select)
[[ ${#sel[@]} -eq 3 ]] || die "could not select USB-SSH device"
IFACE="${sel[1]}"
[[ "$IFACE" != "-" && -n "$IFACE" ]] || die "no host interface for USB-SSH device (wait for ECM link)"

echo "Opening shell on ${LWS_HMI_USB_SSH_USER:-root}@${LWS_HMI_USB_SSH_ADDR:-192.168.55.1} via $IFACE..."
usb_ssh_run "$IFACE"
