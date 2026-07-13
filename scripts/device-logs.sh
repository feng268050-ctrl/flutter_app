#!/usr/bin/env bash
# Stream live device logs over USB-SSH (make logs). No boot-time / serial history.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"
SERIAL="${SERIAL:-${LWS_HMI_SERIAL:-}}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

logs_env() {
	# Prefer LOGS_*; allow short names on the make command line (UNIT=, GREP=, ...).
	case "$1" in
	LOGS_UNIT) printf '%s' "${LOGS_UNIT:-${UNIT:-}}" ;;
	LOGS_TAG) printf '%s' "${LOGS_TAG:-${TAG:-}}" ;;
	LOGS_GREP) printf '%s' "${LOGS_GREP:-${GREP:-}}" ;;
	LOGS_PRIORITY) printf '%s' "${LOGS_PRIORITY:-${PRIORITY:-}}" ;;
	LOGS_KERNEL) printf '%s' "${LOGS_KERNEL:-${KERNEL:-}}" ;;
	esac
}

validate_unit() {
	local unit="$1"
	[[ "$unit" =~ ^[A-Za-z0-9@._+-]+$ ]] || die "invalid UNIT: $unit"
}

validate_tag() {
	local tag="$1"
	[[ "$tag" =~ ^[A-Za-z0-9@._+-]+$ ]] || die "invalid TAG: $tag"
}

validate_priority() {
	local pri="$1"
	[[ "$pri" =~ ^(emerg|alert|crit|err|warning|notice|info|debug|[0-7])$ ]] || \
		die "invalid PRIORITY: $pri (use emerg|alert|crit|err|warning|notice|info|debug or 0-7)"
}

build_journal_args() {
	local units tag grep_pat priority kernel
	units="$(logs_env LOGS_UNIT)"
	tag="$(logs_env LOGS_TAG)"
	grep_pat="$(logs_env LOGS_GREP)"
	priority="$(logs_env LOGS_PRIORITY)"
	kernel="$(logs_env LOGS_KERNEL)"

	journal_args=(-f -n 0 -o short-precise --no-pager)
	filter_parts=()

	if [[ -n "$units" ]]; then
		local unit
		IFS=',' read -ra unit_list <<<"$units"
		for unit in "${unit_list[@]}"; do
			unit="${unit#"${unit%%[![:space:]]*}"}"
			unit="${unit%"${unit##*[![:space:]]}"}"
			[[ -n "$unit" ]] || continue
			validate_unit "$unit"
			journal_args+=(-u "$unit")
			filter_parts+=("unit=$unit")
		done
	fi

	if [[ -n "$tag" ]]; then
		validate_tag "$tag"
		journal_args+=(-t "$tag")
		filter_parts+=("tag=$tag")
	fi

	if [[ -n "$grep_pat" ]]; then
		journal_args+=("--grep=$grep_pat")
		filter_parts+=("grep=$grep_pat")
	fi

	if [[ -n "$priority" ]]; then
		validate_priority "$priority"
		journal_args+=(-p "$priority")
		filter_parts+=("priority=$priority")
	fi

	if [[ -n "$kernel" && "$kernel" != "0" ]]; then
		journal_args+=(-k)
		filter_parts+=("kernel")
	fi
}

usage() {
	cat <<EOF
Usage: make logs [filters]

Follow live journal output from the board over USB-SSH (no buffered history).
Quit: Ctrl+C

Device selection:
  SERIAL / LWS_HMI_SERIAL        select board when multiple USB-SSH devices

Filters (optional; combine as needed):
  UNIT / LOGS_UNIT               systemd unit, comma-separated (e.g. hmi.service)
  TAG / LOGS_TAG                 syslog identifier (logger -t, script prefix)
  GREP / LOGS_GREP               journalctl --grep pattern
  PRIORITY / LOGS_PRIORITY       emerg|alert|crit|err|warning|notice|info|debug
  KERNEL / LOGS_KERNEL=1         kernel messages only

Examples:
  make logs UNIT=hmi.service
  make logs TAG=usb-plug-ssh-start
  make logs GREP=flutter
  make logs PRIORITY=err
  make logs KERNEL=1
  make logs UNIT=hmi.service GREP=flutter

Early boot and serial-only output (before USB-SSH is up) are not included.
Use make serial-console for UART bring-up.
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

build_journal_args

sel=()
while IFS= read -r line; do
	sel+=("$line")
done < <(SERIAL="$SERIAL" bash "$ROOT/scripts/usb-ssh-devices.sh" --select)
[[ ${#sel[@]} -eq 3 ]] || die "could not select USB-SSH device"
IFACE="${sel[1]}"
[[ "$IFACE" != "-" && -n "$IFACE" ]] || die "no host interface for USB-SSH device (wait for ECM link)"

require_sshpass
configure_usb_ssh_host_addr "$IFACE"

target_addr="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
target_user="${LWS_HMI_USB_SSH_USER:-root}"
ssh_pass="${LWS_HMI_USB_SSH_PASS:-rockchip}"

if ((${#filter_parts[@]} > 0)); then
	echo "Streaming live logs from ${target_user}@${target_addr} via $IFACE"
	echo "  filters: ${filter_parts[*]}"
else
	echo "Streaming live logs from ${target_user}@${target_addr} via $IFACE (all journal sources)"
fi
echo "  quit: Ctrl+C"

ssh_opts=(
	-t
	-o ConnectTimeout=5
	-o StrictHostKeyChecking=accept-new
	-o UserKnownHostsFile=/dev/null
	-o LogLevel=ERROR
)
while IFS= read -r opt; do
	[[ -n "$opt" ]] && ssh_opts+=("$opt")
done < <(usb_ssh_bind_pair "$IFACE")

exec sshpass -p "$ssh_pass" ssh "${ssh_opts[@]}" "$target_user@$target_addr" journalctl "${journal_args[@]}"
