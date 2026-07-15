#!/usr/bin/env bash
# Host registry for remote SSH boards (make connect / disconnect / devices SSH rows).
# Registry: .cache/lws-hmi/ssh-devices.tsv — IP<TAB>SERIAL
# Output TSV: MODE, SERIAL, LocationID, IFACE, IP, USB
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
Usage: $0 {connect|disconnect|list|--tsv|--select} [ip]

  connect <ip>       Verify SSH, persist registration (MODE=SSH)
  disconnect <ip>    Remove registration (board need not be online)
  list / --tsv       Print registry rows as device-table TSV
  --select           Print: loc, iface (-), addr  (IP= or SERIAL=)

Env:
  IP / LWS_HMI_IP              address for connect/disconnect/select
  SERIAL / LWS_HMI_SERIAL      select among registered SSH devices
  LWS_HMI_USB_SSH_USER/PASS    same credentials as USB-SSH (default root/rockchip)
EOF
}

normalize_ip() {
	local ip="$1"
	[[ -n "$ip" ]] || return 1
	# Basic IPv4 check (hostname allowlisted via same path if it has a dot or is localhost)
	if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		printf '%s\n' "$ip"
		return 0
	fi
	if [[ "$ip" =~ ^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$ ]]; then
		printf '%s\n' "$ip"
		return 0
	fi
	return 1
}

resolve_ip_arg() {
	local arg="${1:-}"
	local ip="${arg:-${IP:-${LWS_HMI_IP:-}}}"
	ip="$(normalize_ip "$ip" 2>/dev/null || true)"
	[[ -n "$ip" ]] || die "IP required (make connect <ip> or IP=<ip>)"
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

ssh_row() {
	local serial="$1" addr="$2"
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$SSH_MODE" "$serial" "-" "-" "$addr" "-"
}

remote_ssh_opts() {
	local -a opts=(
		-o ConnectTimeout=5
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
		-o PreferredAuthentications=password
		-o PubkeyAuthentication=no
		-o KbdInteractiveAuthentication=no
		-o NumberOfPasswordPrompts=1
	)
	printf '%s\n' "${opts[@]}"
}

fetch_serial_via_ssh() {
	local addr="$1"
	local user="${LWS_HMI_USB_SSH_USER:-root}"
	local pass="${LWS_HMI_USB_SSH_PASS:-rockchip}"
	local -a ssh_opts=()
	local opt

	require_sshpass
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(remote_ssh_opts)
	sshpass -p "$pass" ssh "${ssh_opts[@]}" "$user@$addr" \
		'/usr/lib/lws-hmi/read-device-serial.sh' 2>/dev/null || true
}

list_ssh_devices() {
	local ip serial
	ensure_registry
	[[ -s "$REGISTRY_FILE" ]] || return 0
	while IFS=$'\t' read -r ip serial || [[ -n "${ip:-}" ]]; do
		[[ -n "${ip:-}" ]] || continue
		[[ -n "${serial:-}" ]] || serial="-"
		ssh_row "$serial" "$ip"
	done <"$REGISTRY_FILE"
}

cmd_connect() {
	local ip serial user pass
	ip="$(resolve_ip_arg "${1:-}")"
	user="${LWS_HMI_USB_SSH_USER:-root}"
	pass="${LWS_HMI_USB_SSH_PASS:-rockchip}"
	local -a ssh_opts=()
	local opt

	require_sshpass
	echo "SSH connect: probing $user@$ip ..."
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(remote_ssh_opts)
	if ! sshpass -p "$pass" ssh "${ssh_opts[@]}" "$user@$ip" true >/dev/null 2>&1; then
		die "cannot SSH to $user@$ip (reachable? password? sshd listening?)"
	fi
	serial="$(fetch_serial_via_ssh "$ip")"
	[[ -n "$serial" ]] || serial="-"
	registry_write_row "$ip" "$serial"
	echo "Registered SSH device: IP=$ip SERIAL=$serial"
	echo "  make devices | IP=$ip make shell | IP=$ip make push-app"
}

cmd_disconnect() {
	local ip
	ip="$(resolve_ip_arg "${1:-}")"
	registry_remove "$ip"
	echo "Disconnected SSH device: IP=$ip"
}

select_ssh_device() {
	local serial="${SERIAL:-${LWS_HMI_SERIAL:-}}"
	local pick_ip="${IP:-${LWS_HMI_IP:-}}"
	local -a rows=()
	local row mode s loc iface addr usb

	while IFS="$SSH_FS" read -r mode s loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		rows+=("${mode}${SSH_FS}${s}${SSH_FS}${loc}${SSH_FS}${iface}${SSH_FS}${addr}${SSH_FS}${usb}")
	done < <(list_ssh_devices)

	if [[ ${#rows[@]} -eq 0 ]]; then
		return 1
	fi

	if [[ -n "$pick_ip" ]]; then
		pick_ip="$(normalize_ip "$pick_ip" || die "invalid IP=$pick_ip")"
		for row in "${rows[@]}"; do
			IFS="$SSH_FS" read -r mode s loc iface addr usb <<<"$row"
			[[ "$addr" == "$pick_ip" ]] || continue
			printf '%s\n' "$loc" "$iface" "$addr"
			return 0
		done
		die "IP=$pick_ip not registered (make connect $pick_ip)"
	fi

	if [[ -n "$serial" && "$serial" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$SSH_FS" read -r mode s loc iface addr usb <<<"$row"
			[[ "$s" == "$serial" ]] || continue
			printf '%s\n' "$loc" "$iface" "$addr"
			return 0
		done
		die "SERIAL=$serial not found in SSH devices (make devices / make connect)"
	fi

	if [[ ${#rows[@]} -gt 1 ]]; then
		die "${#rows[@]} SSH devices — set IP= or SERIAL= (see make devices)"
	fi

	IFS="$SSH_FS" read -r mode s loc iface addr usb <<<"${rows[0]}"
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
	die "usage: $0 {connect|disconnect|list|--tsv|--select} [ip]"
	;;
esac
