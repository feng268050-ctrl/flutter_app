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
	while IFS=$'\t' read -r mode sn chip loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		printf '%s\n' "${mode}${FS}${sn}${FS}${chip}${FS}${loc}${FS}${iface}${FS}${addr}${FS}${usb}"
	done < <(bash "$ROOT/scripts/emulator-devices.sh" --tsv 2>/dev/null || true)
}

transport_for_mode() {
	case "$1" in
	USB-SSH) printf '%s\n' "usb-ssh" ;;
	SSH | EMU) printf '%s\n' "ssh" ;;
	*) return 1 ;;
	esac
}

is_ssh_selectable() {
	case "$1" in
	USB-SSH | SSH | EMU) return 0 ;;
	*) return 1 ;;
	esac
}

mtp_hint() {
	echo "OTG is in MTP mode (not USB-SSH). Switch Settings → USB OTG → Debug, or: make connect <lan-ip>" >&2
}

emit_selection() {
	local mode="$1" loc="$2" iface="$3" addr="$4" transport
	if [[ "$mode" == "USB-MTP" ]]; then
		mtp_hint
		die "SN/device is USB-MTP — no SSH transport"
	fi
	transport="$(transport_for_mode "$mode")" || die "unsupported MODE=$mode"
	printf '%s\n' "$transport" "$loc" "$iface" "$addr"
}

select_device() {
	local sn_sel chip_sel pick_ip pick_iface
	local -a rows=() selectable=()
	local row mode sn chip loc iface addr usb
	local -a matches=() mtp_matches=()

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

	for row in "${rows[@]}"; do
		IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
		is_ssh_selectable "$mode" && selectable+=("$row")
	done

	# IP= selects MODE=SSH or MODE=EMU (never USB-SSH / USB-MTP).
	if [[ -n "$pick_ip" ]]; then
		pick_ip="$(normalize_ssh_endpoint "$pick_ip" 2>/dev/null || die "invalid IP=$pick_ip")"
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			[[ "$mode" == "SSH" || "$mode" == "EMU" ]] || continue
			[[ "$addr" == "$pick_ip" ]] || continue
			emit_selection "$mode" "$loc" "$iface" "$addr"
			return 0
		done
		die "IP=$pick_ip not found (make connect $pick_ip / make emulator; see make devices)"
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

	# CHIPID= matches ChipID column only (SSH-selectable rows).
	if [[ -n "$chip_sel" && "$chip_sel" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			[[ "$chip" == "$chip_sel" ]] || continue
			if [[ "$mode" == "USB-MTP" ]]; then
				mtp_matches+=("$row")
				continue
			fi
			is_ssh_selectable "$mode" || continue
			matches+=("$row")
		done
		if [[ ${#matches[@]} -eq 0 ]]; then
			if [[ ${#mtp_matches[@]} -gt 0 ]]; then
				mtp_hint
				die "CHIPID=$chip_sel is USB-MTP only (make devices)"
			fi
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
	# SIM-EMU / EMU are stable aliases for MODE=EMU (probed SN is product.ini, e.g. SIM-0001).
	if [[ -n "$sn_sel" && "$sn_sel" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			if [[ "$sn" != "$sn_sel" && "$chip" != "$sn_sel" ]]; then
				if [[ "$mode" == "EMU" && ( "$sn_sel" == "SIM-EMU" || "$sn_sel" == "EMU" ) ]]; then
					:
				else
					continue
				fi
			fi
			if [[ "$mode" == "USB-MTP" ]]; then
				mtp_matches+=("$row")
				continue
			fi
			is_ssh_selectable "$mode" || continue
			matches+=("$row")
		done
		if [[ ${#matches[@]} -eq 0 ]]; then
			if [[ ${#mtp_matches[@]} -gt 0 ]]; then
				mtp_hint
				die "SN=$sn_sel is USB-MTP only (make devices)"
			fi
			die "SN=$sn_sel not found (make devices)"
		fi
		if [[ ${#matches[@]} -gt 1 ]]; then
			die "SN=$sn_sel matches ${#matches[@]} devices — set IP= for SSH or IFACE= for USB-SSH"
		fi
		IFS="$FS" read -r mode sn chip loc iface addr usb <<<"${matches[0]}"
		emit_selection "$mode" "$loc" "$iface" "$addr"
		return 0
	fi

	if [[ ${#selectable[@]} -eq 0 ]]; then
		for row in "${rows[@]}"; do
			IFS="$FS" read -r mode sn chip loc iface addr usb <<<"$row"
			[[ "$mode" == "USB-MTP" ]] || continue
			mtp_hint
			die "Only USB-MTP connected — no SSH target (make devices)"
		done
		die "No USB-SSH or SSH device (plug OTG or: make connect <ip>; see make devices)"
	fi

	if [[ ${#selectable[@]} -gt 1 ]]; then
		die "${#selectable[@]} devices — set SN= or IP= (see make devices)"
	fi

	IFS="$FS" read -r mode sn chip loc iface addr usb <<<"${selectable[0]}"
	case "$mode" in
	USB-SSH | SSH | EMU) ;;
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
