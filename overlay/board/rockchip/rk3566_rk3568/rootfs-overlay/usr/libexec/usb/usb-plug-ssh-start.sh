#!/bin/sh
# VBUS-triggered g_ether + usb0 @ 192.168.55.1/24 + sshd on usb0 only.
set -eu

SSHD_PID=/run/usb-plug-sshd.pid
USB_ADDR=192.168.55.1/24

log() {
	echo "usb-plug-ssh-start: $*"
}

sshd_running() {
	[ -f "$SSHD_PID" ] && kill -0 "$(cat "$SSHD_PID")" 2>/dev/null
}

mac_addresses() {
	local serial="$1" hash h1 h2 h3 h4
	hash="$(printf '%s' "$serial" | md5sum | awk '{print $1}')"
	h1="$(printf '%d' "0x$(printf '%s' "$hash" | cut -c1-2)")"
	h2="$(printf '%d' "0x$(printf '%s' "$hash" | cut -c3-4)")"
	h3="$(printf '%d' "0x$(printf '%s' "$hash" | cut -c5-6)")"
	h4="$(printf '%d' "0x$(printf '%s' "$hash" | cut -c7-8)")"
	printf '02:12:%02x:%02x:%02x:%02x\n' "$h1" "$h2" "$h3" "$h4"
	printf '02:13:%02x:%02x:%02x:%02x\n' "$h1" "$h2" "$h3" "$h4"
}

unload_g_ether() {
	if [ -d /sys/class/net/usb0 ]; then
		ip addr flush dev usb0 2>/dev/null || true
		ip link set usb0 down 2>/dev/null || true
	fi
	# Soft-disconnect so the host drops the device before rmmod.
	for udc in /sys/class/udc/*; do
		[ -e "$udc" ] || continue
		sf="$udc/soft_connect"
		[ -w "$sf" ] || continue
		printf '%s\n' disconnect >"$sf" 2>/dev/null || echo 0 >"$sf" 2>/dev/null || true
	done
	sleep 0.2
	if [ -d /sys/module/g_ether ]; then
		modprobe -r g_ether 2>/dev/null || rmmod g_ether 2>/dev/null || return 1
	fi
	return 0
}

load_g_ether() {
	local serial="$1" host_mac dev_mac

	# After unplug/replug, g_ether may still be loaded (failed stop or sticky
	# UDC). Staying put skips USB re-enumeration — host then sees nothing.
	if [ -d /sys/module/g_ether ]; then
		log "g_ether already loaded — forcing reload for clean attach"
		if ! unload_g_ether; then
			log "WARN: could not unload sticky g_ether"
			return 1
		fi
		sleep 0.3
	fi

	set -- $(mac_addresses "$serial")
	host_mac="$1"
	dev_mac="$2"
	log "loading g_ether serial=$serial host=$host_mac device=$dev_mac"
	set -- \
		idVendor=0x2207 \
		idProduct=0x0019 \
		iManufacturer=Innohi \
		iProduct="LWS HMI" \
		iSerialNumber="$serial" \
		host_addr="$host_mac" \
		dev_addr="$dev_mac"
	if [ -f /system/lib/modules/g_ether.ko ]; then
		insmod /system/lib/modules/g_ether.ko "$@"
		return 0
	fi
	if modprobe g_ether "$@"; then
		return 0
	fi
	log "g_ether module not found"
	return 1
}

setup_usb0() {
	local i=0
	while [ "$i" -lt 25 ]; do
		[ -d /sys/class/net/usb0 ] && break
		i=$((i + 1))
		sleep 0.2
	done
	[ -d /sys/class/net/usb0 ] || {
		log "usb0 missing after loading g_ether"
		return 1
	}
	ip link set usb0 up
	ip addr flush dev usb0
	ip addr add "$USB_ADDR" dev usb0
}

start_sshd() {
	if sshd_running; then
		return 0
	fi
	# Always bind usb0-only — LAN debug listens on eth0/wlan0 IPs separately.
	/usr/libexec/ssh/ensure-sshd-hostkeys.sh
	mkdir -p /run/sshd
	chmod 0755 /run/sshd 2>/dev/null || true
	/usr/sbin/sshd \
		-f /etc/ssh/sshd_config \
		-o "ListenAddress=192.168.55.1" \
		-o "PasswordAuthentication=yes" \
		-o "PermitRootLogin=yes" \
		-o "PidFile=$SSHD_PID"
}

SERIAL="$(/usr/libexec/board/read-device-serial.sh)"
load_g_ether "$SERIAL"
setup_usb0
start_sshd

log "ready on usb0 $USB_ADDR (g_ether, serial=$SERIAL)"
