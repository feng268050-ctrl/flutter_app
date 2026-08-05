#!/usr/bin/env bash
# Discover running P3.2 QEMU guest for make devices (MODE=EMU).
# Lists only when QEMU is alive or SSH hostfwd actually answers.
# Stale ssh-endpoint (Ctrl-C / window close) is pruned — does not persist registry.
# TSV: MODE, SN, ChipID, LocationID, IFACE, IP, USB
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"

OUT="$ROOT/output/firmware/emulator"
ENDPOINT_FILE="$OUT/ssh-endpoint"
# shellcheck source=scripts/emulator-common.sh
source "$ROOT/scripts/emulator-common.sh"

EMU_MODE="EMU"
# Placeholder when QEMU is up but identity SSH has not succeeded yet.
# Also a stable SN= alias in device-target.sh (probed SN may be SIM-0001).
EMU_SN_FALLBACK="SIM-EMU"
EMU_CHIP_FALLBACK="-"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

read_endpoint_file() {
	[[ -f "$ENDPOINT_FILE" ]] || return 1
	tr -d '[:space:]' <"$ENDPOINT_FILE" | head -1
}

# Collect candidate host:port endpoints (unique, preference order).
candidate_endpoints() {
	local ep port want pid cmd
	local -a out=()
	want="${EMULATOR_SSH_PORT:-2222}"

	if ep="$(read_endpoint_file)"; then
		[[ -n "$ep" ]] && out+=("$ep")
	fi

	# Parse hostfwd from live QEMU cmdlines (handles auto-bumped ports).
	while read -r pid; do
		[[ "$pid" =~ ^[0-9]+$ ]] || continue
		cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
		[[ "$cmd" =~ hostfwd=tcp::([0-9]+)-:22 ]] || continue
		out+=("127.0.0.1:${BASH_REMATCH[1]}")
	done < <(lws_emulator_pids)

	for port in "$want" 2223 2224 2225 2226 2227 2228 2229 2230; do
		out+=("127.0.0.1:${port}")
	done

	printf '%s\n' "${out[@]}" | awk 'NF && !seen[$0]++'
}

probe_endpoint() {
	local ep="$1"
	local user="${USB_SSH_USER:-root}"
	local pass="${USB_SSH_PASS:-rockchip}"
	local -a ssh_opts=(
		-o ConnectTimeout=2
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
		-o PreferredAuthentications=password
		-o PubkeyAuthentication=no
		-o KbdInteractiveAuthentication=no
		-o NumberOfPasswordPrompts=1
	)

	parse_ssh_endpoint "$ep" || return 1
	# Skip slow SSH attempts when nothing listens.
	ssh_endpoint_reachable "$ep" || return 1
	command -v sshpass >/dev/null 2>&1 || return 1
	sshpass -p "$pass" ssh "${ssh_opts[@]}" -p "$_SSH_PORT" "$user@$_SSH_HOST" true >/dev/null 2>&1 || return 1
	remote_device_identity_via_ssh sshpass -p "$pass" ssh "${ssh_opts[@]}" -p "$_SSH_PORT" "$user@$_SSH_HOST" || true
}

emit_emu_row() {
	local sn="$1" chip="$2" ep="$3"
	[[ -n "$sn" ]] || sn="$EMU_SN_FALLBACK"
	[[ -n "$chip" ]] || chip="$EMU_CHIP_FALLBACK"
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$EMU_MODE" "$sn" "$chip" "-" "-" "$ep" "-"
}

prune_stale_endpoint() {
	rm -f "$ENDPOINT_FILE"
}

list_emulator_devices() {
	local ep live sn chip
	local best_ep="" reachable_ep=""
	local qemu_up=0

	lws_emulator_running && qemu_up=1

	# No live guest and no answering SSH → drop stale endpoint from Ctrl-C / window close.
	if [[ "$qemu_up" -eq 0 ]]; then
		if ep="$(read_endpoint_file 2>/dev/null)" && [[ -n "$ep" ]] \
			&& ssh_endpoint_reachable "$ep" 2>/dev/null; then
			: # rare: SSH still up without matching ps line — still list below
		else
			[[ -f "$ENDPOINT_FILE" ]] && prune_stale_endpoint
			return 0
		fi
	fi

	while IFS= read -r ep; do
		[[ -n "$ep" ]] || continue
		[[ -z "$best_ep" ]] && best_ep="$ep"
		if ssh_endpoint_reachable "$ep" 2>/dev/null; then
			[[ -z "$reachable_ep" ]] && reachable_ep="$ep"
		fi
		live="$(probe_endpoint "$ep" 2>/dev/null || true)"
		if [[ -n "$live" ]]; then
			IFS=$'\t' read -r sn chip <<<"$live"
			emit_emu_row "$sn" "$chip" "$ep"
			return 0
		fi
	done < <(candidate_endpoints)

	# QEMU is up (or SSH answered above) but identity probe pending.
	ep="${reachable_ep:-${best_ep:-127.0.0.1:${EMULATOR_SSH_PORT:-2222}}}"
	if ! command -v sshpass >/dev/null 2>&1; then
		echo "NOTE: EMU ${ep} — install sshpass to probe SN/ChipID (brew install sshpass)" >&2
	elif [[ -z "$reachable_ep" ]]; then
		echo "NOTE: EMU listed at ${ep} but SSH not accepting yet (guest still booting?)" >&2
	else
		echo "NOTE: EMU ${ep} reachable but identity probe failed (check root password)" >&2
	fi
	emit_emu_row "$EMU_SN_FALLBACK" "$EMU_CHIP_FALLBACK" "$ep"
}

case "${1:-}" in
list | --tsv | "")
	list_emulator_devices
	;;
-h | --help)
	echo "Usage: $0 [--tsv]"
	;;
*)
	die "usage: $0 [--tsv]"
	;;
esac
