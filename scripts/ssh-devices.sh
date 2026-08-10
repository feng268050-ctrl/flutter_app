#!/usr/bin/env bash
# Host registry for remote SSH boards (make connect / disconnect / devices SSH rows).
# Registry: .cache/lws-hmi/ssh-devices.tsv — IP<TAB>SN
# Output TSV: MODE, SN, LocationID, IFACE, IP, USB
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"

SSH_MODE="SSH"
SSH_FS=$'\t'
REGISTRY_DIR="$ROOT/.cache/lws-hmi"
REGISTRY_FILE="$REGISTRY_DIR/ssh-devices.tsv"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0 {connect|disconnect|dismiss-target|list|--tsv|--select} [args]

  connect <ip>       Verify SSH, persist registration (MODE=SSH)
  disconnect <ip>    Remove registration (board need not be online)
  dismiss-target <transport> <iface> <addr>
                     Quietly remove a rebooting board's SSH registration
  list / --tsv       Print registry rows as device-table TSV
  --select           Print: loc, iface (-), addr  (IP= or SN=)

Env:
  IP=<addr>                  address for connect/disconnect/select
  SN                         select among registered SSH devices (SERIAL= deprecated)
  LWS_SSH_IDENTITY           team SSH private key (default keys/ssh/id_ed25519)
  USB_SSH_USER               SSH login user (default root)
EOF
}

normalize_ip() {
	local ip="$1"
	[[ -n "$ip" ]] || return 1
	normalize_ssh_endpoint "$ip"
}

resolve_ip_arg() {
	local arg="${1:-}"
	local ip="${arg:-${IP:-}}"
	ip="$(normalize_ip "$ip" 2>/dev/null || true)"
	[[ -n "$ip" ]] || die "IP required (make connect <ip> or IP=<ip>; host:port OK for emulator)"
	printf '%s\n' "$ip"
}

ensure_registry() {
	mkdir -p "$REGISTRY_DIR"
	[[ -f "$REGISTRY_FILE" ]] || : >"$REGISTRY_FILE"
}

registry_has() {
	local ip="$1"
	[[ -f "$REGISTRY_FILE" ]] || return 1
	awk -F'\t' -v ip="$ip" '$1==ip {found=1} END{exit found?0:1}' "$REGISTRY_FILE"
}

registry_write_row() {
	local ip="$1" serial="${2:--}"
	local tmp other
	ensure_registry
	tmp="$(mktemp)"
	other="$(awk -F'\t' -v ip="$ip" '$1!=ip {print}' "$REGISTRY_FILE" 2>/dev/null || true)"
	{
		[[ -n "$other" ]] && printf '%s\n' "$other"
		printf '%s\t%s\n' "$ip" "$serial"
	} >"$tmp"
	mv "$tmp" "$REGISTRY_FILE"
}

registry_remove() {
	local ip="$1" tmp
	ensure_registry
	registry_has "$ip" || die "IP=$ip is not registered (make devices / make connect)"
	tmp="$(mktemp)"
	awk -F'\t' -v ip="$ip" '$1!=ip {print}' "$REGISTRY_FILE" >"$tmp"
	mv "$tmp" "$REGISTRY_FILE"
}

registry_dismiss_matching() {
	local ip="$1" serial="$2" tmp before after
	ensure_registry
	before="$(wc -l <"$REGISTRY_FILE" | tr -d ' ')"
	tmp="$(mktemp)"
	awk -F'\t' -v ip="$ip" -v serial="$serial" '
		!((ip != "" && $1 == ip) || (serial != "" && serial != "-" && $2 == serial))
	' "$REGISTRY_FILE" >"$tmp"
	after="$(wc -l <"$tmp" | tr -d ' ')"
	mv "$tmp" "$REGISTRY_FILE"
	if [[ "$after" -lt "$before" ]]; then
		echo "Removed rebooting device from SSH registry."
	fi
}

ssh_row() {
	local sn="$1" addr="$2"
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$SSH_MODE" "$sn" "-" "-" "$addr" "-"
}

remote_ssh_opts() {
	local -a opts=(
		-o ConnectTimeout=5
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
	)
	printf '%s\n' "${opts[@]}"
}

fetch_identity_via_ssh() {
	local addr="$1"
	local user="${USB_SSH_USER:-root}"
	local -a ssh_opts=()
	local opt

	require_ssh_identity "$ROOT"
	parse_ssh_endpoint "$addr" || return 1
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(remote_ssh_opts)
	ssh_opts+=(-p "$_SSH_PORT")
	remote_device_identity_via_ssh lws_ssh_with_opts "$ROOT" "${ssh_opts[@]}" "$user@$_SSH_HOST" || true
}

list_ssh_devices() {
	local ip serial live sn chip
	ensure_registry
	[[ -s "$REGISTRY_FILE" ]] || return 0
	while IFS=$'\t' read -r ip serial || [[ -n "${ip:-}" ]]; do
		[[ -n "${ip:-}" ]] || continue
		[[ -n "${serial:-}" ]] || serial="-"
		sn="$serial"
		# Refresh SN from the board when reachable (chip used only for SN fallback).
		live="$(fetch_identity_via_ssh "$ip" 2>/dev/null || true)"
		if [[ -n "$live" ]]; then
			IFS=$'\t' read -r sn chip <<<"$live"
			[[ -n "$sn" ]] || sn="-"
			if [[ "$sn" != "$serial" ]]; then
				registry_write_row "$ip" "$sn"
			fi
		fi
		ssh_row "$sn" "$ip"
	done <"$REGISTRY_FILE"
}

cmd_connect() {
	local ip serial user sn chip live
	ip="$(resolve_ip_arg "${1:-}")"
	user="${USB_SSH_USER:-root}"
	local -a ssh_opts=()
	local opt

	require_ssh_identity "$ROOT"
	parse_ssh_endpoint "$ip" || die "invalid IP=$ip"
	echo "SSH connect: probing $user@${_SSH_HOST}:${_SSH_PORT} ..."
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(remote_ssh_opts)
	ssh_opts+=(-p "$_SSH_PORT")
	if ! lws_ssh_with_opts "$ROOT" "${ssh_opts[@]}" "$user@$_SSH_HOST" true >/dev/null 2>&1; then
		die "cannot SSH to $user@${_SSH_HOST}:${_SSH_PORT} (reachable? team key? sshd listening?)"
	fi
	live="$(fetch_identity_via_ssh "$ip")"
	IFS=$'\t' read -r sn chip <<<"${live:-}"
	[[ -n "$sn" ]] || sn="-"
	registry_write_row "$ip" "$sn"
	echo "Registered SSH device: IP=$ip SN=$sn"
	echo "  make devices | IP=$ip make shell | IP=$ip make push-app"
}

cmd_disconnect() {
	local ip
	ip="$(resolve_ip_arg "${1:-}")"
	registry_remove "$ip"
	echo "Disconnected SSH device: IP=$ip"
}

cmd_dismiss_target() {
	local transport="${1:-}" iface="${2:-}" addr="${3:-}" serial="${4:-}"
	case "$transport" in
	ssh)
		[[ -n "$addr" && "$addr" != "-" ]] || return 0
		registry_dismiss_matching "$addr" ""
		;;
	usb-ssh)
		[[ -n "$iface" && "$iface" != "-" ]] || return 0
		if [[ -z "$serial" || "$serial" == "-" ]]; then
			serial="$(
				bash "$ROOT/scripts/usb-ssh-devices.sh" --tsv 2>/dev/null |
					awk -F'\t' -v iface="$iface" \
						'$1 == "USB-SSH" && $4 == iface {print $2; exit}' ||
					true
			)"
		fi
		[[ -n "$serial" && "$serial" != "-" ]] || return 0
		registry_dismiss_matching "" "$serial"
		;;
	esac
}

select_ssh_device() {
	local sn_sel pick_ip
	local -a rows=()
	local row mode sn loc iface addr usb

	sn_sel="$(device_select_sn)"
	pick_ip="${IP:-}"

	while IFS="$SSH_FS" read -r mode sn loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		rows+=("${mode}${SSH_FS}${sn}${SSH_FS}${loc}${SSH_FS}${iface}${SSH_FS}${addr}${SSH_FS}${usb}")
	done < <(list_ssh_devices)

	if [[ ${#rows[@]} -eq 0 ]]; then
		return 1
	fi

	if [[ -n "$pick_ip" ]]; then
		pick_ip="$(normalize_ip "$pick_ip" || die "invalid IP=$pick_ip")"
		for row in "${rows[@]}"; do
			IFS="$SSH_FS" read -r mode sn loc iface addr usb <<<"$row"
			[[ "$addr" == "$pick_ip" ]] || continue
			printf '%s\n' "$loc" "$iface" "$addr"
			return 0
		done
		die "IP=$pick_ip not registered (make connect $pick_ip)"
	fi

	if [[ -n "$sn_sel" && "$sn_sel" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$SSH_FS" read -r mode sn loc iface addr usb <<<"$row"
			[[ "$sn" == "$sn_sel" ]] || continue
			printf '%s\n' "$loc" "$iface" "$addr"
			return 0
		done
		die "SN=$sn_sel not found in SSH devices (make devices / make connect)"
	fi

	if [[ ${#rows[@]} -gt 1 ]]; then
		die "${#rows[@]} SSH devices — set IP= or SN= (see make devices)"
	fi

	IFS="$SSH_FS" read -r mode sn loc iface addr usb <<<"${rows[0]}"
	printf '%s\n' "$loc" "$iface" "$addr"
}

case "${1:-}" in
connect)
	shift
	cmd_connect "${1:-}"
	;;
disconnect)
	shift
	cmd_disconnect "${1:-}"
	;;
dismiss-target)
	shift
	cmd_dismiss_target "${1:-}" "${2:-}" "${3:-}" "${4:-}"
	;;
list | --tsv | "")
	list_ssh_devices
	;;
--select)
	select_ssh_device
	;;
-h | --help)
	usage
	;;
*)
	die "usage: $0 {connect|disconnect|dismiss-target|list|--tsv|--select} [args]"
	;;
esac
