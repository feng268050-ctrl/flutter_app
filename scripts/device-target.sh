#!/usr/bin/env bash
# Unified Linux SSH target selection: USB-SSH gadgets + registered remote SSH (MODE=SSH).
# --select output (4 lines): TRANSPORT, LocationID, IFACE, IP
# TRANSPORT is usb-ssh or ssh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

FS=$'\t'

collect_rows() {
	local mode sn chip loc iface addr usb
	while IFS=$'\t' read -r mode sn chip loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		printf '%s\n' "${mode}${FS}${sn}${FS}${chip}${FS}${loc}${FS}${iface}${FS}${addr}${FS}${usb}"
	done < <(bash "$ROOT/scripts/usb-ssh-devices.sh" --tsv 2>/dev/null || true)
	while IFS=$'\t' read -r mode sn chip loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		printf '%s\n' "${mode}${FS}${sn}${FS}${chip}${FS}${loc}${FS}${iface}${FS}${addr}${FS}${usb}"
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
	local sn_sel chip_sel pick_ip pick_iface
	local -a rows=()
	local row mode sn chip loc iface addr usb
	local -a matches=()

	sn_sel="$(device_select_sn)"
	chip_sel="$(device_select_chipid)"
	pick_ip="${IP:-${LWS_HMI_IP:-}}"
	pick_iface="${IFACE:-${LWS_HMI_USB_IFACE:-}}"

	while IFS= read -r row; do
		[[ -n "$row" ]] && rows+=("$row")
	done < <(collect_rows)

	if [[ ${#rows[@]} -eq 0 ]]; then
		die "No USB-SSH or SSH device (plug OTG or: make connect <ip>; see make devices)"
	fi

	# IP= selects MODE=SSH only (never USB-SSH).
	if [[ -n "$pick_ip" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			[[ "$mode" == "SSH" && "$addr" == "$pick_ip" ]] || continue
			emit_selection "$mode" "$loc" "$iface" "$addr"
			return 0
		done
		die "IP=$pick_ip not registered (make connect $pick_ip)"
	fi

	# IFACE= is USB-SSH only.
	if [[ -n "$pick_iface" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			[[ "$mode" == "USB-SSH" && "$iface" == "$pick_iface" ]] || continue
			emit_selection "$mode" "$loc" "$iface" "$addr"
			return 0
		done
		die "IFACE=$pick_iface not found (make devices)"
	fi

	# CHIPID= matches ChipID column only.
	if [[ -n "$chip_sel" && "$chip_sel" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			[[ "$chip" == "$chip_sel" ]] || continue
			matches+=("$row")
		done
		if [[ ${#matches[@]} -eq 0 ]]; then
			die "CHIPID=$chip_sel not found (make devices)"
		fi
		if [[ ${#matches[@]} -gt 1 ]]; then
			die "CHIPID=$chip_sel matches ${#matches[@]} devices — set IP= for SSH or IFACE= for USB-SSH"
		fi
		IFS="$FS" read -r mode sn chip loc iface addr usb <<<"${matches[0]}"
		emit_selection "$mode" "$loc" "$iface" "$addr"
		return 0
	fi

	# SN= (SERIAL= deprecated) matches SN or ChipID.
	if [[ -n "$sn_sel" && "$sn_sel" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			[[ "$sn" == "$sn_sel" || "$chip" == "$sn_sel" ]] || continue
			matches+=("$row")
		done
		if [[ ${#matches[@]} -eq 0 ]]; then
			die "SN=$sn_sel not found (make devices)"
		fi
		if [[ ${#matches[@]} -gt 1 ]]; then
			die "SN=$sn_sel matches ${#matches[@]} devices — set IP= for SSH or IFACE= for USB-SSH"
		fi
		IFS="$FS" read -r mode sn chip loc iface addr usb <<<"${matches[0]}"
		emit_selection "$mode" "$loc" "$iface" "$addr"
		return 0
	fi

	if [[ ${#rows[@]} -gt 1 ]]; then
		die "${#rows[@]} devices — set SN= or IP= (see make devices)"
	fi

	IFS="$FS" read -r mode sn chip loc iface addr usb <<<"${rows[0]}"
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
