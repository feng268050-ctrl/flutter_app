#!/usr/bin/env bash
# Stream live device logs over USB-SSH or registered remote SSH (make logs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
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
	units="${UNIT:-}"
	tag="${TAG:-}"
	grep_pat="${GREP:-}"
	priority="${PRIORITY:-}"
	kernel="${KERNEL_ONLY:-}"

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

Follow live journal output from the board over USB-SSH or registered SSH (no buffered history).
Quit: Ctrl+C

Device selection:
  SN                         select board when multiple devices
  IP                         registered SSH only (make connect <ip>)

Filters (optional; combine as needed):
  UNIT                           systemd unit, comma-separated (e.g. hmi.service)
  TAG                            syslog identifier (logger -t, script prefix)
  GREP                           journalctl --grep pattern
  PRIORITY                       emerg|alert|crit|err|warning|notice|info|debug
  KERNEL_ONLY=1                  kernel messages only

Examples:
  make logs UNIT=hmi.service
  make logs TAG=usb-plug-ssh-start
  make logs GREP=flutter
  make logs PRIORITY=err
  make logs KERNEL_ONLY=1
  make logs UNIT=hmi.service GREP=flutter
  IP=192.168.1.50 make logs

Early boot and serial-only output (before SSH is up) are not included.
Use make serial-console for UART bring-up.
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

build_journal_args

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
require_sshpass

if ((${#filter_parts[@]} > 0)); then
	if usb_ssh_session_is_remote; then
		echo "Streaming live logs from ${TARGET_USER}@${TARGET_ADDR} (SSH)"
	else
		echo "Streaming live logs from ${TARGET_USER}@${TARGET_ADDR} via $IFACE"
	fi
	echo "  filters: ${filter_parts[*]}"
else
	if usb_ssh_session_is_remote; then
		echo "Streaming live logs from ${TARGET_USER}@${TARGET_ADDR} (SSH; all journal sources)"
	else
		echo "Streaming live logs from ${TARGET_USER}@${TARGET_ADDR} via $IFACE (all journal sources)"
	fi
fi
echo "  quit: Ctrl+C"

ssh_opts=(
	-t
	-o ConnectTimeout=5
	-o StrictHostKeyChecking=accept-new
	-o UserKnownHostsFile=/dev/null
	-o LogLevel=ERROR
)
if ! usb_ssh_session_is_remote; then
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(usb_ssh_bind_pair "$IFACE")
fi

exec sshpass -p "$SSH_PASS" ssh "${ssh_opts[@]}" "$TARGET_USER@$TARGET_ADDR" journalctl "${journal_args[@]}"
