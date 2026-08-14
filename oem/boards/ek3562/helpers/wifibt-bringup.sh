#!/bin/sh
# ek3562 onboard RTL8821CU on SoC USB host (soldered module; enumerates like USB).
# Driver: mainline rtw88 (rtw_8821cu). Firmware: /lib/firmware/rtw88/ (linux-firmware).
set -eu

log() {
	echo "wifibt-bringup: $*" >&2
}

MODULE_DIRS="/vendor/lib/modules /system/lib/modules /lib/modules /usr/lib/modules"
BOARD_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OEM_RADIO_FW="${LWS_OEM_RADIO_FW:-$BOARD_DIR/radio/firmware}"

wait_wlan() {
	i=0
	while [ "$i" -lt 80 ]; do
		for d in /sys/class/net/*; do
			[ -e "$d" ] || continue
			if [ -d "$d/wireless" ] || [ -d "$d/phy80211" ]; then
				basename "$d"
				return 0
			fi
		done
		i=$((i + 1))
		sleep 0.25
	done
	return 1
}

is_rtl8821cu_usb() {
	for d in /sys/bus/usb/devices/*; do
		[ -f "$d/idVendor" ] || continue
		v="$(cat "$d/idVendor" 2>/dev/null || true)"
		p="$(cat "$d/idProduct" 2>/dev/null || true)"
		case "$v:$p" in
		0bda:c811|0bda:c82b|0bda:c82c|0bda:b82b|0bda:c820) return 0 ;;
		esac
	done
	return 1
}

wait_rtl8821cu_usb() {
	i=0
	while [ "$i" -lt 80 ]; do
		if is_rtl8821cu_usb; then
			return 0
		fi
		i=$((i + 1))
		sleep 0.25
	done
	return 1
}

resolve_module() {
	name="$1"
	for dir in $MODULE_DIRS; do
		[ -d "$dir" ] || continue
		if [ -f "$dir/$name.ko" ]; then
			echo "$dir/$name.ko"
			return 0
		fi
		found="$(find "$dir" -maxdepth 3 -name "$name.ko" 2>/dev/null | head -n 1 || true)"
		if [ -n "$found" ]; then
			echo "$found"
			return 0
		fi
	done
	return 1
}

load_rtw8821cu() {
	if modprobe rtw_8821cu 2>/dev/null; then
		log "modprobe rtw_8821cu"
		return 0
	fi
	ko="$(resolve_module rtw_8821cu || true)"
	if [ -n "$ko" ]; then
		log "insmod $ko"
		insmod "$ko" && return 0
	fi
	log "ERROR: rtw_8821cu unavailable (ek3562-wifibt.config + FORCE_KERNEL_IMAGE=1 make build-kernel)"
	return 1
}

if command -v rfkill >/dev/null 2>&1; then
	rfkill unblock wifi 2>/dev/null || true
	rfkill unblock wlan 2>/dev/null || true
fi

# Optional vendor-specific blobs (mainline rtw88 normally uses /lib/firmware/rtw88/).
if ls "$OEM_RADIO_FW"/* >/dev/null 2>&1; then
	mkdir -p /vendor/etc/firmware/rtw88 /lib/firmware/rtw88
	for f in "$OEM_RADIO_FW"/*; do
		[ -f "$f" ] || continue
		base="$(basename "$f")"
		ln -sfn "$f" "/vendor/etc/firmware/rtw88/$base"
		ln -sfn "$f" "/lib/firmware/rtw88/$base"
	done
	log "linked optional OEM radio firmware into rtw88 paths"
fi

if [ ! -f /lib/firmware/rtw88/rtw8821c_fw.bin ] && \
	[ ! -f /vendor/etc/firmware/rtw88/rtw8821c_fw.bin ]; then
	log "WARN: rtw8821c_fw.bin missing — enable BR2_PACKAGE_LINUX_FIRMWARE_RTL_RTW88 and rebuild rootfs"
fi

for d in /sys/class/net/*; do
	[ -e "$d" ] || continue
	if [ -d "$d/wireless" ] || [ -d "$d/phy80211" ]; then
		log "wlan already up: $(basename "$d")"
		exit 0
	fi
done

if ! is_rtl8821cu_usb; then
	log "waiting for onboard RTL8821CU USB enumeration (SoC USB host)…"
	wait_rtl8821cu_usb || log "WARN: 0bda:c811 not visible — trying modprobe anyway (power/DT pending?)"
fi

load_rtw8821cu || exit 1

if iface="$(wait_wlan)"; then
	log "wlan up: $iface"
else
	lsmod 2>/dev/null | grep -iE 'rtw|8821' >&2 || log "no rtw modules loaded"
	log "ERROR: no wireless netdev after rtw_8821cu load"
	exit 1
fi
