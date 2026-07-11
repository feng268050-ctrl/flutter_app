#!/bin/sh
# VBUS-triggered USB ECM gadget + usb0 @ 192.168.55.1/24 + sshd on usb0 only.
set -u

GADGET_ROOT=/sys/kernel/config/usb_gadget
GADGET_NAME=lws_hmi
GADGET="$GADGET_ROOT/$GADGET_NAME"
SSHD_PID=/run/lws-hmi-usb-plug-sshd.pid
USB_ADDR=192.168.55.1/24
DWC3_GADGET_DEV=fcc00000.usb
DWC3_HOST_DEV=fd000000.usb

log() {
	echo "usb-plug-ssh-start: $*"
}

warn() {
	echo "usb-plug-ssh-start: WARN: $*" >&2
}

udc_state() {
	cat "/sys/class/udc/$1/state" 2>/dev/null || echo unknown
}

debug_udc_state() {
	local udc="$1"
	log "diag: udc state=$(udc_state "$udc")"
	log "diag: gadgets=$(ls "$GADGET_ROOT" 2>/dev/null || echo none)"
	for g in "$GADGET_ROOT"/*; do
		[ -d "$g" ] || continue
		log "diag: $(basename "$g") UDC=$(cat "$g/UDC" 2>/dev/null || echo -)"
	done
	log "diag: usb0=$(ip -br link show usb0 2>/dev/null || echo missing)"
	for role in /sys/class/usb_role/*/role; do
		[ -r "$role" ] || continue
		log "diag: $role=$(cat "$role" 2>/dev/null || echo ?)"
	done
	for mode in /sys/devices/platform/fe8a0000.usb2-phy/otg_mode \
		/sys/devices/platform/*/fe8a0000.*/otg_mode; do
		[ -r "$mode" ] || continue
		log "diag: $mode=$(cat "$mode" 2>/dev/null || echo ?)"
	done
	if [ -d /sys/bus/platform/drivers/dwc3 ]; then
		log "diag: dwc3=$(ls /sys/bus/platform/drivers/dwc3 2>/dev/null || echo -)"
	fi
	read_dwc3_usb_roles
}

find_udc() {
	local u
	for u in /sys/class/udc/*; do
		[ -e "$u" ] || continue
		basename "$u"
		return 0
	done
	return 1
}

sshd_running() {
	[ -f "$SSHD_PID" ] && kill -0 "$(cat "$SSHD_PID")" 2>/dev/null
}

gadget_bound_udc() {
	[ -f "$GADGET/UDC" ] || return 1
	cat "$GADGET/UDC" 2>/dev/null || true
}

find_holder_for_udc() {
	local udc="$1" g bound
	[ -d "$GADGET_ROOT" ] || return 1
	for g in "$GADGET_ROOT"/*; do
		[ -d "$g" ] || continue
		[ -f "$g/UDC" ] || continue
		bound="$(cat "$g/UDC" 2>/dev/null || true)"
		[ "$bound" = "$udc" ] || continue
		basename "$g"
		return 0
	done
	return 1
}

udc_is_active() {
	case "$(udc_state "$1")" in
	configured|attached|connected|addressed) return 0 ;;
	esac
	return 1
}

unbind_all_gadgets() {
	local g
	[ -d "$GADGET_ROOT" ] || return 0
	for g in "$GADGET_ROOT"/*; do
		[ -f "$g/UDC" ] || continue
		echo "" >"$g/UDC" 2>/dev/null || true
	done
}

soft_disconnect_udc() {
	local udc="$1"
	local sf="/sys/class/udc/$udc/soft_connect"
	[ -w "$sf" ] || return 0
	printf '%s\n' disconnect >"$sf" 2>/dev/null || echo 0 >"$sf" 2>/dev/null || true
}

udc_pullup_on() {
	local udc="$1"
	local sf="/sys/class/udc/$udc/soft_connect"
	[ -n "$udc" ] || return 0
	[ -w "$sf" ] || return 0
	printf '%s\n' connect >"$sf" 2>/dev/null || echo 1 >"$sf" 2>/dev/null || true
}

stop_rockchip_usbdevice() {
	if command -v systemctl >/dev/null 2>&1; then
		systemctl stop usbdevice.service 2>/dev/null || true
	fi
	if [ -x /usr/bin/usbdevice ]; then
		/usr/bin/usbdevice stop 2>/dev/null || true
	fi
}

release_dwc3_host() {
	local drv=/sys/bus/platform/drivers/dwc3 dev name
	[ -d "$drv" ] || return 0
	for dev in "$drv"/*; do
		[ -e "$dev" ] || continue
		name="$(basename "$dev")"
		case "$name" in
		fd000000.usb|usb@fd000000.usb)
			if echo "$name" >"$drv/unbind" 2>/dev/null; then
				log "unbound dwc3 host $name"
			fi
			;;
		esac
	done
}

set_otg_phy_peripheral() {
	local f role_dev
	for f in /sys/devices/platform/fe8a0000.usb2-phy/otg_mode \
		/sys/devices/platform/*/fe8a0000.*/otg_mode; do
		[ -w "$f" ] || continue
		echo peripheral >"$f" 2>/dev/null || true
	done
	for f in /sys/class/usb_role/*/role; do
		[ -w "$f" ] || continue
		role_dev="$(readlink -f "$(dirname "$(dirname "$f")")" 2>/dev/null || true)"
		case "$role_dev" in
		*fcc00000* | *usbdrd* | *fe8a0000*)
			echo device >"$f" 2>/dev/null || true
			;;
		esac
	done
}

read_dwc3_usb_roles() {
	local f role_dev role
	for f in /sys/class/usb_role/*/role; do
		[ -r "$f" ] || continue
		role_dev="$(readlink -f "$(dirname "$(dirname "$f")")" 2>/dev/null || true)"
		case "$role_dev" in
		*fcc00000* | *usbdrd* | *fe8a0000*)
			role="$(cat "$f" 2>/dev/null || echo ?)"
			log "diag: $f=$role ($role_dev)"
			;;
		esac
	done
}

reset_dwc3_peripheral() {
	local drv=/sys/bus/platform/drivers/dwc3
	[ -d "$drv" ] || return 0
	if [ -e "$drv/$DWC3_GADGET_DEV" ]; then
		log "reset dwc3 peripheral $DWC3_GADGET_DEV"
		echo "$DWC3_GADGET_DEV" >"$drv/unbind" 2>/dev/null || true
		sleep 1
	fi
	if [ ! -e "$drv/$DWC3_GADGET_DEV" ]; then
		echo "$DWC3_GADGET_DEV" >"$drv/bind" 2>/dev/null || true
		sleep 1
	fi
}

force_release_udc() {
	local udc="$1" state tries=0 holder

	soft_disconnect_udc "$udc"
	stop_rockchip_usbdevice
	unbind_all_gadgets
	sleep 0.5

	while [ "$tries" -lt 4 ]; do
		state="$(udc_state "$udc")"
		case "$state" in
		not-attached|undefined|unknown)
			return 0
			;;
		esac
		holder="$(find_holder_for_udc "$udc" 2>/dev/null || true)"
		if [ -n "$holder" ]; then
			log "unbind configfs gadget $holder (udc $state)"
			echo "" >"$GADGET_ROOT/$holder/UDC" 2>/dev/null || true
			sleep 0.5
			continue
		fi
		log "UDC stuck in $state — reset dwc3 peripheral"
		reset_dwc3_peripheral
		tries=$((tries + 1))
	done
}

prepare_udc_for_gadget() {
	stop_rockchip_usbdevice
	release_dwc3_host
	set_otg_phy_peripheral
	reset_dwc3_peripheral
	sleep 0.5
}

setup_usb0() {
	[ -d /sys/class/net/usb0 ] || return 1
	ip link set usb0 up 2>/dev/null || true
	ip addr flush dev usb0 2>/dev/null || true
	ip addr add "$USB_ADDR" dev usb0 2>/dev/null || true
	return 0
}

start_sshd() {
	if sshd_running; then
		return 0
	fi
	if ! /usr/lib/lws-hmi/ensure-sshd-hostkeys.sh; then
		log "failed to ensure ssh host keys"
		return 1
	fi
	mkdir -p /run/sshd
	chmod 0755 /run/sshd 2>/dev/null || true
	if ! /usr/sbin/sshd \
		-f /etc/ssh/sshd_config \
		-o "ListenAddress=192.168.55.1" \
		-o "PasswordAuthentication=yes" \
		-o "PermitRootLogin=yes" \
		-o "PidFile=$SSHD_PID"; then
		log "sshd failed to start"
		return 1
	fi
	log "sshd listening on 192.168.55.1 (pid $(cat "$SSHD_PID" 2>/dev/null || echo ?))"
	return 0
}

finish_if_usb0_ready() {
	local udc="$1"
	if ! setup_usb0; then
		return 1
	fi
	if ! start_sshd; then
		return 1
	fi
	log "ready on usb0 $USB_ADDR (udc=$(gadget_bound_udc || echo ?) state=$(udc_state "$udc"))"
	exit 0
}

create_gadget() {
	local serial="$1"
	local serial_hash h1 h2 h3 h4

	mkdir -p "$GADGET"
	echo 0x2207 >"$GADGET/idVendor"
	echo 0x0019 >"$GADGET/idProduct"
	echo 0x0100 >"$GADGET/bcdDevice"
	echo 0x0200 >"$GADGET/bcdUSB"

	mkdir -p "$GADGET/strings/0x409"
	echo "Innohi" >"$GADGET/strings/0x409/manufacturer"
	echo "LWS HMI" >"$GADGET/strings/0x409/product"
	echo "$serial" >"$GADGET/strings/0x409/serialnumber"

	mkdir -p "$GADGET/configs/c.1/strings/0x409"
	echo "ECM" >"$GADGET/configs/c.1/strings/0x409/configuration"
	echo 250 >"$GADGET/configs/c.1/MaxPower"

	mkdir -p "$GADGET/functions/ecm.usb0"
	serial_hash="$(printf '%s' "$serial" | md5sum | awk '{print $1}')"
	h1="$(printf '%d' "0x${serial_hash:0:2}")"
	h2="$(printf '%d' "0x${serial_hash:2:2}")"
	h3="$(printf '%d' "0x${serial_hash:4:2}")"
	h4="$(printf '%d' "0x${serial_hash:6:2}")"
	printf '02:12:%02x:%02x:%02x:%02x\n' "$h1" "$h2" "$h3" "$h4" \
		>"$GADGET/functions/ecm.usb0/host_addr"
	printf '02:13:%02x:%02x:%02x:%02x\n' "$h1" "$h2" "$h3" "$h4" \
		>"$GADGET/functions/ecm.usb0/dev_addr"
	ln -sf "$GADGET/functions/ecm.usb0" "$GADGET/configs/c.1/"
}

bind_gadget_udc() {
	local udc="$1" cur err tries=0 state holder

	cur="$(gadget_bound_udc)"
	if [ "$cur" = "$udc" ]; then
		udc_pullup_on "$udc"
		return 0
	fi

	state="$(udc_state "$udc")"
	case "$state" in
	configured|attached|connected|addressed)
		holder="$(find_holder_for_udc "$udc" 2>/dev/null || true)"
		if [ "$holder" = "$GADGET_NAME" ]; then
			log "UDC already $state for $GADGET_NAME"
			udc_pullup_on "$udc"
			return 0
		fi
		log "UDC busy ($state holder=${holder:-none}) — release before bind"
		force_release_udc "$udc"
		;;
	esac

	prepare_udc_for_gadget

	while [ "$tries" -lt 6 ]; do
		state="$(udc_state "$udc")"
		case "$state" in
		configured|attached|connected|addressed)
			holder="$(find_holder_for_udc "$udc" 2>/dev/null || true)"
			if [ "$holder" = "$GADGET_NAME" ]; then
				udc_pullup_on "$udc"
				return 0
			fi
			force_release_udc "$udc"
			;;
		esac

		if echo "$udc" >"$GADGET/UDC" 2>/tmp/lws-hmi-udc-bind.err; then
			udc_pullup_on "$udc"
			return 0
		fi

		cur="$(gadget_bound_udc)"
		if [ "$cur" = "$udc" ]; then
			udc_pullup_on "$udc"
			return 0
		fi

		err="$(cat /tmp/lws-hmi-udc-bind.err 2>/dev/null || true)"
		log "UDC bind try $((tries + 1)): ${err:-unknown} (state=$(udc_state "$udc"))"
		force_release_udc "$udc"
		prepare_udc_for_gadget
		tries=$((tries + 1))
		sleep 1
	done
	debug_udc_state "$udc"
	return 1
}

# Fast path: already up.
if [ -n "$(gadget_bound_udc)" ] && sshd_running && setup_usb0; then
	exit 0
fi

SERIAL="$(/usr/lib/lws-hmi/read-device-serial.sh)"
UDC="$(find_udc)" || {
	log "no UDC under /sys/class/udc"
	exit 1
}

modprobe libcomposite 2>/dev/null || true
modprobe usb_f_ecm 2>/dev/null || true

if ! mountpoint -q /sys/kernel/config 2>/dev/null; then
	mount -t configfs none /sys/kernel/config 2>/dev/null || {
		log "failed to mount configfs"
		exit 1
	}
fi

# UDC already enumerated by host — bring up usb0/sshd without rebinding.
if udc_is_active "$UDC" && [ -d /sys/class/net/usb0 ]; then
	log "UDC $(udc_state "$UDC") with usb0 — skip bind"
	finish_if_usb0_ready "$UDC"
fi

prepare_udc_for_gadget

if udc_is_active "$UDC"; then
	holder="$(find_holder_for_udc "$UDC" 2>/dev/null || true)"
	if [ "$holder" = "$GADGET_NAME" ] && [ -d /sys/class/net/usb0 ]; then
		finish_if_usb0_ready "$UDC"
	fi
	log "UDC active ($(udc_state "$UDC")) — force release"
	force_release_udc "$UDC"
fi

if [ -d "$GADGET" ]; then
	if [ -z "$(gadget_bound_udc)" ]; then
		/usr/lib/lws-hmi/usb-plug-ssh-stop.sh 2>/dev/null || true
		force_release_udc "$UDC"
	fi
fi

prepare_udc_for_gadget

if [ ! -d "$GADGET" ]; then
	create_gadget "$SERIAL"
fi

if [ "$(gadget_bound_udc)" != "$UDC" ]; then
	if ! bind_gadget_udc "$UDC"; then
		# Bind failed but host may have enumerated anyway.
		if [ -d /sys/class/net/usb0 ]; then
			warn "bind failed but usb0 exists — continuing"
		else
			log "could not bind $UDC"
			exit 1
		fi
	fi
else
	udc_pullup_on "$UDC"
fi

i=0
while [ "$i" -lt 25 ]; do
	if [ -d /sys/class/net/usb0 ]; then
		break
	fi
	i=$((i + 1))
	sleep 0.2
done

if ! setup_usb0; then
	warn "usb0 not present after gadget bind"
	debug_udc_state "$UDC"
	exit 1
fi

if ! start_sshd; then
	exit 1
fi

log "ready on usb0 $USB_ADDR (udc=$(gadget_bound_udc || echo ?) state=$(udc_state "$UDC"))"
exit 0
