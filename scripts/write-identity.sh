#!/usr/bin/env bash
# Provision brand/model/product SN into Rockchip Vendor Storage on the selected board.
# Usage:
#   make write-identity BRAND=LaserCyber MODEL='L1 Pro' PRODUCT_SN=LC-001
#   SN=ABC123 FORCE=1 make write-identity BRAND=… MODEL=… PRODUCT_SN=…
# Device selection: SN= / IP= (same as push-app / set-prop).
# Identity payload: BRAND= MODEL= PRODUCT_SN= (hyphens stripped). FORCE=1 overwrites SN.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage:
  make write-identity BRAND=<brand> MODEL=<model> PRODUCT_SN=<sn>
  SN=<sn> make write-identity BRAND=… MODEL=… PRODUCT_SN=… [FORCE=1]

Writes brand / model / product SN into Rockchip Vendor Storage on the board
(SSH → /usr/bin/write-identity). Does not package identity into factory.img.

Device selection (same as push-app / set-prop): SN= / IP=
Identity value: PRODUCT_SN= — [A-Za-z0-9]; "-" allowed in input but stripped
  (L1P-S-001 → L1PS001) so Rockchip U-Boot serial# / DT serial-number stay intact.
FORCE=1 required to overwrite a non-empty stored SN.

Emulator / boards without /dev/vendor_storage fail clearly (no properties.ini identity fallback).

Optional RockUSB SN-only (macOS upgrade_tool SN / RSN) is documented in README;
brand/model still require this SSH path after Linux boots.
EOF
}

# Parse MAKEOVERRIDES-style KEY=value args + process env.
BRAND="${BRAND:-}"
MODEL="${MODEL:-}"
PRODUCT_SN="${PRODUCT_SN:-}"
FORCE="${FORCE:-0}"

for o in "$@"; do
	[[ "${o}" == *=* ]] || continue
	key="${o%%=*}"
	value="${o#*=}"
	[[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
	value="${value//\\ / }"
	case "$key" in
	BRAND) BRAND="$value" ;;
	MODEL) MODEL="$value" ;;
	PRODUCT_SN) PRODUCT_SN="$value" ;;
	FORCE) FORCE="$value" ;;
	SN | CHIP_ID | IP | SERIAL) ;;
	*) ;;
	esac
done

if [[ -z "$BRAND" || -z "$MODEL" || -z "$PRODUCT_SN" ]]; then
	usage
	die "BRAND=, MODEL=, and PRODUCT_SN= are required"
fi

# Make passes spaces as "Make\ Model" in MAKEOVERRIDES; normalize any leftover backslashes.
BRAND="${BRAND//\\ / }"
MODEL="${MODEL//\\ / }"
PRODUCT_SN="${PRODUCT_SN//\\ / }"

# Strip "-" for Rockchip U-Boot serial# / DT (same rule as board write-product-identity).
raw_sn="$PRODUCT_SN"
PRODUCT_SN="${PRODUCT_SN//-/}"
if [[ "$PRODUCT_SN" != "$raw_sn" ]]; then
	echo "NOTE: stripped '-' from PRODUCT_SN: '$raw_sn' → '$PRODUCT_SN'"
fi
[[ -n "$PRODUCT_SN" ]] || die "PRODUCT_SN empty after stripping '-'"
if [[ ! "$PRODUCT_SN" =~ ^[A-Za-z0-9]+$ ]]; then
	die "PRODUCT_SN must be alphanumeric [A-Za-z0-9] after stripping '-'; got '$raw_sn' → '$PRODUCT_SN'"
fi

require_ssh_identity "$ROOT"

usb_ssh_session_prepare "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH write-identity: target=$TARGET_USER@$TARGET_ADDR"
else
	echo "USB-SSH write-identity: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
fi

# Fail early on emulator (no Vendor Storage GPT / device node).
if usb_ssh_session_run_ssh "$ROOT" "$IFACE" \
	"test -e /dev/vendor_storage" >/dev/null 2>&1; then
	:
else
	die "/dev/vendor_storage missing on target — write-identity requires real hardware with vendor0–vendor3 GPT (emulator is unsupported)"
fi

# Pass identity via env; values are shell-quoted for the remote command line.
remote_env=(
	"FORCE=$(printf '%q' "$FORCE")"
	"BRAND=$(printf '%q' "$BRAND")"
	"MODEL=$(printf '%q' "$MODEL")"
	"PRODUCT_SN=$(printf '%q' "$PRODUCT_SN")"
)
usb_ssh_session_run_ssh "$ROOT" "$IFACE" \
	"${remote_env[*]} /usr/bin/write-identity" \
	|| die "on-board write-identity failed"

echo "INFO: restarting hmi.service so App reloads identity..." >&2
usb_ssh_session_run_ssh "$ROOT" "$IFACE" "systemctl restart hmi.service" \
	|| die "failed to restart hmi.service"

echo "OK: write-identity complete (brand='$BRAND' model='$MODEL' sn='$PRODUCT_SN')"
