#!/usr/bin/env bash
# Unified Linux SSH target selection: USB-SSH gadgets + registered remote SSH (MODE=SSH).
# --select output (4 lines): TRANSPORT, LocationID, IFACE, IP
# TRANSPORT is usb-ssh or ssh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

FS=$'\t'

collect_rows() {
	local mode s loc iface addr usb
	while IFS=$'\t' read -r mode s loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		printf '%s\n' "${mode}${FS}${s}${FS}${loc}${FS}${iface}${FS}${addr}${FS}${usb}"
	done < <(bash "$ROOT/scripts/usb-ssh-devices.sh" --tsv 2>/dev/null || true)
	while IFS=$'\t' read -r mode s loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		printf '%s\n' "${mode}${FS}${s}${FS}${loc}${FS}${iface}${FS}${addr}${FS}${usb}"
	done < <(bash "$ROOT/scripts/ssh-devices.sh" --tsv 2>/dev/null || true)
}

transport_for_mode() {
	case "$1" in
	USB-SSH) printf '%s\n' "usb-ssh" ;;
	SSH) printf '%s\n' "ssh" ;;
	*) return 1 ;;
	esac
}

emit_selection() {
	local mode="$1" loc="$2" iface="$3" addr="$4" transport
	transport="$(transport_for_mode "$mode")" || die "unsupported MODE=$mode"
	printf '%s\n' "$transport" "$loc" "$iface" "$addr"
}

select_device() {
	local serial="${SERIAL:-${LWS_HMI_SERIAL:-}}"
	local pick_ip="${IP:-${LWS_HMI_IP:-}}"
	local pick_iface="${IFACE:-${LWS_HMI_USB_IFACE:-}}"
	local -a rows=()
	local row mode s loc iface addr usb
	local -a matches=()

	while IFS= read -r row; do
		[[ -n "$row" ]] && rows+=("$row")
	done < <(collect_rows)

	if [[ ${#rows[@]} -eq 0 ]]; then
		die "No USB-SSH or SSH device (plug OTG or: make connect <ip>; see make devices)"
	fi

	# IP= selects MODE=SSH only (never USB-SSH).
	if [[ -n "$pick_ip" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode s loc iface addr usb <<<"$row"
			[[ "$mode" == "SSH" && "$addr" == "$pick_ip" ]] || continue
			emit_selection "$mode" "$loc" "$iface" "$addr"
			return 0
		done
		die "IP=$pick_ip not registered (make connect $pick_ip)"
	fi

	# IFACE= is USB-SSH only.
	if [[ -n "$pick_iface" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode s loc iface addr usb <<<"$row"
			[[ "$mode" == "USB-SSH" && "$iface" == "$pick_iface" ]] || continue
			emit_selection "$mode" "$loc" "$iface" "$addr"
			return 0
		done
		die "IFACE=$pick_iface not found (make devices)"
	fi

	if [[ -n "$serial" && "$serial" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode s loc iface addr usb <<<"$row"
			[[ "$s" == "$serial" ]] || continue
			matches+=("$row")
		done
		if [[ ${#matches[@]} -eq 0 ]]; then
			die "SERIAL=$serial not found (make devices)"
		fi
		if [[ ${#matches[@]} -gt 1 ]]; then
			die "SERIAL=$serial matches ${#matches[@]} devices — set IP= for SSH or IFACE= for USB-SSH"
		fi
		IFS="$FS" read -r mode s loc iface addr usb <<<"${matches[0]}"
		emit_selection "$mode" "$loc" "$iface" "$addr"
		return 0
	fi

	if [[ ${#rows[@]} -gt 1 ]]; then
		die "${#rows[@]} devices — set SERIAL= or IP= (see make devices)"
	fi

	IFS="$FS" read -r mode s loc iface addr usb <<<"${rows[0]}"
	case "$mode" in
	USB-SSH | SSH) ;;
	*) die "No Linux SSH target (make devices)" ;;
	esac
	if [[ "$mode" == "USB-SSH" && ( "$iface" == "-" || -z "$iface" ) ]]; then
		die "USB-SSH: no host IFACE (plug USB OTG; board: /usr/libexec/hmi/usb-plug-ssh-start.sh)"
	fi
	emit_selection "$mode" "$loc" "$iface" "$addr"
}

case "${1:-}" in
--select)
	select_device
	;;
-h | --help)
	echo "Usage: $0 --select"
	;;
*)
	die "usage: $0 --select"
	;;
esac
