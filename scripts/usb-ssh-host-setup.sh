#!/usr/bin/env bash
# Mac/Linux: find USB ECM/RNDIS gadget NIC and set host IP for plug-ssh (192.168.55.2).
set -euo pipefail

HOST_ADDR="${LWS_HMI_USB_HOST_ADDR:-192.168.55.2}"
TARGET_ADDR="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
MASK="${LWS_HMI_USB_HOST_MASK:-24}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0 [--ping-only]

Find the USB gadget ethernet interface (Mac: often en10 "RNDIS/Ethernet Gadget")
and configure host $HOST_ADDR/$MASK for board $TARGET_ADDR.

Do NOT type literal "enX" — run this script or see "Hardware Port" below.

Prereq (board, serial): /usr/libexec/hmi/usb-plug-ssh-start.sh
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0
PING_ONLY=0
[[ "${1:-}" == "--ping-only" ]] && PING_ONLY=1

find_mac_usb_gadget_iface() {
	local row iface
	row="$(bash "$(dirname "${BASH_SOURCE[0]}")/usb-ssh-devices.sh" --tsv 2>/dev/null | head -1 || true)"
	if [[ -n "$row" ]]; then
		IFS=$'\t' read -r _mode _serial _loc iface _addr _usb <<<"$row"
		if [[ -n "$iface" && "$iface" != "-" ]]; then
			echo "$iface"
			return 0
		fi
	fi
	return 1
}

find_linux_usb_gadget_iface() {
	local net usb_path
	for net in /sys/class/net/*; do
		net="$(basename "$net")"
		[[ "$net" == lo ]] && continue
		usb_path=""
		usb_path="$(readlink -f "/sys/class/net/$net/device" 2>/dev/null || true)"
		[ -n "$usb_path" ] || continue
		while [ "$usb_path" != "/" ]; do
			if [ -f "$usb_path/idVendor" ]; then
				vid="$(cat "$usb_path/idVendor" 2>/dev/null || true)"
				[[ "$vid" == "2207" ]] || break
				echo "$net"
				return 0
			fi
			usb_path="$(dirname "$usb_path")"
		done
	done
	return 1
}

find_iface() {
	case "$(uname -s)" in
	Darwin) find_mac_usb_gadget_iface ;;
	Linux) find_linux_usb_gadget_iface ;;
	*) die "unsupported OS: $(uname -s)" ;;
	esac
}

configure_host() {
	local iface="$1"
	case "$(uname -s)" in
	Darwin)
		if ifconfig "$iface" 2>/dev/null | grep -q "inet ${HOST_ADDR} "; then
			echo "Host $iface already has $HOST_ADDR"
		else
			echo "sudo ifconfig $iface ${HOST_ADDR}/${MASK} up"
			sudo ifconfig "$iface" "${HOST_ADDR}/${MASK}" up
		fi
		# Never set a default gateway on the USB gadget NIC — a Router of
		# 192.168.55.1 (board) steals the Mac default route and kills Wi‑Fi/
		# LAN internet while the board is plugged in. Prefer ifconfig (no
		# gateway). If System Settings / networksetup previously left a
		# Router on the "LWS" / RNDIS service, clear it.
		_usb_ssh_darwin_clear_gadget_gateway "$iface"
		;;
	Linux)
		if ip -4 addr show dev "$iface" 2>/dev/null | grep -q "inet ${HOST_ADDR}/"; then
			echo "Host $iface already has $HOST_ADDR"
			return 0
		fi
		echo "sudo ip addr add ${HOST_ADDR}/${MASK} dev $iface (or replace)"
		sudo ip addr add "${HOST_ADDR}/${MASK}" dev "$iface" 2>/dev/null \
			|| sudo ip addr replace "${HOST_ADDR}/${MASK}" dev "$iface"
		sudo ip link set "$iface" up
		;;
	esac
}

# Darwin: clear IPv4 Router on the hardware port that owns $iface (LWS / RNDIS).
_usb_ssh_darwin_clear_gadget_gateway() {
	local iface="$1"
	local port="" info router
	[[ "$(uname -s)" == "Darwin" ]] || return 0
	command -v networksetup >/dev/null 2>&1 || return 0
	port="$(networksetup -listallhardwareports 2>/dev/null \
		| awk -v d="$iface" '
			/^Hardware Port:/ { p=$0; sub(/^Hardware Port: /,"",p) }
			/^Device: / && $2==d { print p; exit }
		')"
	[[ -n "$port" ]] || return 0
	info="$(networksetup -getinfo "$port" 2>/dev/null || true)"
	router="$(printf '%s\n' "$info" | awk -F': ' '/^Router:/{print $2; exit}')"
	# Empty / none / 0.0.0.0 are fine.
	if [[ -z "$router" || "$router" == "none" || "$router" == "0.0.0.0" ]]; then
		return 0
	fi
	echo "WARNING: clearing bogus Router=$router on \"$port\" (was stealing default route)"
	# Keep current IP/mask if manual; force Router to 0.0.0.0.
	local ip mask
	ip="$(printf '%s\n' "$info" | awk -F': ' '/^IP address:/{print $2; exit}')"
	mask="$(printf '%s\n' "$info" | awk -F': ' '/^Subnet mask:/{print $2; exit}')"
	if [[ -n "$ip" && -n "$mask" && "$ip" != "none" ]]; then
		sudo networksetup -setmanual "$port" "$ip" "$mask" 0.0.0.0 || true
	fi
}

ping_target() {
	local iface="$1"
	case "$(uname -s)" in
	Darwin) ping -c 2 -t 2 -b "$iface" "$TARGET_ADDR" ;;
	Linux) ping -c 2 -W 2 -I "$iface" "$TARGET_ADDR" ;;
	esac
}

echo "=== USB plug-ssh host setup ==="
echo "Looking for USB gadget ethernet (not Wi‑Fi en0) ..."
IFACE="$(find_iface)" || die "No USB gadget NIC found.

Plug OTG USB into Mac, then on board run:
  /usr/libexec/hmi/usb-plug-ssh-start.sh

List ports manually:
  networksetup -listallhardwareports | grep -A1 -iE 'RNDIS|Gadget|LWS|Innohi'"

echo "Using interface: $IFACE"
[[ "$PING_ONLY" -eq 1 ]] || configure_host "$IFACE"

echo ""
echo "Ping board at $TARGET_ADDR ..."
if ping_target "$IFACE"; then
	echo ""
	sn="$(bash "$(dirname "${BASH_SOURCE[0]}")/usb-ssh-devices.sh" --tsv 2>/dev/null | head -1 | awk -F'\t' '{print $2}')"
	chip="$(bash "$(dirname "${BASH_SOURCE[0]}")/usb-ssh-devices.sh" --tsv 2>/dev/null | head -1 | awk -F'\t' '{print $3}')"
	[[ -n "$sn" && "$sn" != "-" ]] && echo "Board SN: $sn"
	[[ -n "$chip" && "$chip" != "-" && "$chip" != "$sn" ]] && echo "Board ChipID: $chip"
	echo ""
	echo "OK — try: ssh root@${TARGET_ADDR}   (password: rockchip)"
	echo "     or: make push-app"
	echo "     or: make reboot-loader   (SN not required when only one board)"
	exit 0
fi

echo ""
echo "Ping failed. Check board:"
echo "  ip -br addr show usb0    # expect 192.168.55.1/24"
echo "  ss -lntp | grep 192.168.55.1"
exit 1
