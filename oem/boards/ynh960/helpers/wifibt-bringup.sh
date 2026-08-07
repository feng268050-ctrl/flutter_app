#!/bin/sh
# Bring up ynh960 Wi-Fi+BT combo (Innohi AIC8800D80 on SDIO c8a1:0082).
# Used by wifi-stack-up / bt-stack-up. Does not enable units at boot.
set -eu

log() {
	echo "wifibt-bringup: $*" >&2
}

MODULE_DIRS="/vendor/lib/modules /system/lib/modules /lib/modules /usr/lib/modules"
BT_TTY="${LWS_BT_TTY:-}"
# Board pack root (…/boards/<id>); radio keep-set lives under radio/firmware/.
BOARD_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
OEM_RADIO_FW="${LWS_OEM_RADIO_FW:-$BOARD_DIR/radio/firmware}"
# Driver CONFIG_AIC_FW_PATH (see ynh960-wifibt.config).
AIC_FW_PATH="${LWS_AIC_FW_PATH:-/vendor/etc/firmware}"
# Transitional only: LWS_WIFIBT_ALLOW_VENDOR_FW=1 accepts pre-existing vendor dump.
ALLOW_VENDOR_FW="${LWS_WIFIBT_ALLOW_VENDOR_FW:-0}"

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

wait_hci() {
	i=0
	while [ "$i" -lt 40 ]; do
		if [ -d /sys/class/bluetooth/hci0 ] || \
			hciconfig 2>/dev/null | grep -q hci0; then
			return 0
		fi
		i=$((i + 1))
		sleep 0.25
	done
	return 1
}

dump_sdio() {
	log "sdio devices:"
	for d in /sys/bus/sdio/devices/*; do
		[ -e "$d" ] || continue
		v="$(cat "$d/vendor" 2>/dev/null || true)"
		p="$(cat "$d/device" 2>/dev/null || true)"
		log "  $(basename "$d") vendor=$v device=$p"
	done
}

# Innohi rk_wifi_init: AIC8800 / AIC8800DC / AIC8800D80 → c8a1:*
is_aic_sdio() {
	for d in /sys/bus/sdio/devices/*; do
		[ -e "$d/vendor" ] || continue
		v="$(cat "$d/vendor" 2>/dev/null || true)"
		case "$v" in
			0xc8a1|c8a1) return 0 ;;
		esac
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
		# Flattened copy from post-wifibt `find kernel -name '*.ko'`
		found="$(find "$dir" -maxdepth 3 -name "$name.ko" 2>/dev/null | head -n 1 || true)"
		if [ -n "$found" ]; then
			echo "$found"
			return 0
		fi
	done
	return 1
}

insmod_one() {
	name="$1"
	shift
	if lsmod 2>/dev/null | grep -wq "$name"; then
		log "$name already loaded"
		return 0
	fi
	ko="$(resolve_module "$name")" || {
		log "missing $name.ko under:$MODULE_DIRS"
		return 1
	}
	log "insmod $ko $*"
	insmod "$ko" "$@" || {
		log "insmod failed: $ko"
		return 1
	}
	return 0
}

ensure_firmware_links() {
	# Prefer OEM radio pack (authoritative). Symlink keep-set into AIC_FW_PATH
	# so CONFIG_AIC_FW_PATH / historical /lib/firmware expectations resolve.
	if [ -f "$OEM_RADIO_FW/fmacfw_8800d80_u02.bin" ]; then
		mkdir -p "$AIC_FW_PATH"
		for f in "$OEM_RADIO_FW"/*; do
			[ -e "$f" ] || continue
			ln -sfn "$f" "$AIC_FW_PATH/$(basename "$f")" 2>/dev/null || \
				cp -f "$f" "$AIC_FW_PATH/$(basename "$f")" 2>/dev/null || true
		done
		mkdir -p /system/etc
		[ -e /system/etc/firmware ] || \
			ln -sfn "$AIC_FW_PATH" /system/etc/firmware 2>/dev/null || true
		# /lib/firmware may already be a real dir (Buildroot); prefer symlink when absent.
		if [ ! -e /lib/firmware ]; then
			ln -sfn "$AIC_FW_PATH" /lib/firmware 2>/dev/null || true
		elif [ -d /lib/firmware ] && [ ! -L /lib/firmware ]; then
			for f in "$OEM_RADIO_FW"/*; do
				[ -e "$f" ] || continue
				base="$(basename "$f")"
				[ -e "/lib/firmware/$base" ] || \
					ln -sfn "$f" "/lib/firmware/$base" 2>/dev/null || true
			done
		fi
		log "OEM radio firmware linked from $OEM_RADIO_FW → $AIC_FW_PATH"
		return 0
	fi

	log "OEM radio firmware missing under $OEM_RADIO_FW"
	if [ "$ALLOW_VENDOR_FW" = "1" ]; then
		log "LWS_WIFIBT_ALLOW_VENDOR_FW=1 — trying vendor dump fallback"
		if [ -d /vendor/etc/firmware ]; then
			mkdir -p /system/etc
			[ -e /system/etc/firmware ] || \
				ln -sfn /vendor/etc/firmware /system/etc/firmware 2>/dev/null || true
			[ -e /lib/firmware ] || \
				ln -sfn /vendor/etc/firmware /lib/firmware 2>/dev/null || true
		fi
		for cand in /vendor/etc/firmware /system/etc/firmware /lib/firmware; do
			[ -d "$cand" ] || continue
			if [ -f "$cand/fmacfw_8800d80_u02.bin" ]; then
				log "AIC8800D80 firmware present under $cand (vendor fallback)"
				return 0
			fi
		done
	fi
	return 1
}

bt_tty() {
	if [ -n "$BT_TTY" ] && [ -e "$BT_TTY" ]; then
		echo "$BT_TTY"
		return 0
	fi
	if command -v wifibt-util.sh >/dev/null 2>&1; then
		t="$(wifibt-util.sh tty 2>/dev/null || true)"
		if [ -n "$t" ] && [ -e "$t" ]; then
			echo "$t"
			return 0
		fi
	fi
	# Innohi default for ynh960 Combo BT UART
	if [ -e /dev/ttyS1 ]; then
		echo /dev/ttyS1
		return 0
	fi
	return 1
}

start_aic_bt() {
	if [ -d /sys/class/bluetooth/hci0 ] || \
		hciconfig 2>/dev/null | grep -q hci0; then
		log "hci0 already present"
		return 0
	fi
	tty="$(bt_tty)" || {
		log "no BT UART tty"
		return 1
	}
	log "AIC BT tty=$tty"
	# Match Innohi rk_wifi_init: hciattach -s 1500000 <tty> any 1500000 flow nosleep
	if command -v hciattach >/dev/null 2>&1; then
		killall -q -9 hciattach 2>/dev/null || true
		hciattach -s 1500000 "$tty" any 1500000 flow nosleep &
		wait_hci && log "hci0 ready" && return 0
		log "hciattach did not produce hci0"
	else
		log "hciattach missing"
	fi
	return 1
}

# AIC SDIO can stay enumerated but stop answering CMD52/53 (driver probe → -110 /
# "No such device"). rockchip wifi_power/carddetect often no-op without
# WIFI,poweren_gpio; mmc-pwrseq reset runs again only if the host is rebound.
unload_aic_modules() {
	killall -q -9 rk_wifi_init 2>/dev/null || true
	# Reverse of Innohi load order; ignore errors when not loaded.
	rmmod aic8800_fdrv 2>/dev/null || true
	rmmod aic8800_btlpm 2>/dev/null || true
	rmmod aic8800_bsp 2>/dev/null || true
}

rescan_aic_sdio() {
	plat=""
	for card in /sys/bus/mmc/devices/*; do
		[ -e "$card/type" ] || continue
		[ "$(cat "$card/type" 2>/dev/null || true)" = "SDIO" ] || continue
		# .../platform/<dev>.mmc/mmc_host/mmcN/mmcN:XXXX
		plat="$(dirname "$(dirname "$(dirname "$(readlink -f "$card")")")")"
		break
	done
	if [ -z "$plat" ] || [ ! -d "$plat" ]; then
		log "no SDIO mmc platform device to rescan"
		return 1
	fi
	dev="$(basename "$plat")"
	if [ ! -e "$plat/driver" ]; then
		log "$dev has no driver link"
		return 1
	fi
	drv="$(basename "$(readlink -f "$plat/driver")")"
	drv_dir="/sys/bus/platform/drivers/$drv"
	if [ ! -w "$drv_dir/unbind" ] || [ ! -w "$drv_dir/bind" ]; then
		log "cannot unbind/bind $drv ($dev)"
		return 1
	fi
	log "rescan SDIO via $drv unbind/bind $dev (mmc-pwrseq reset)"
	unload_aic_modules
	echo "$dev" >"$drv_dir/unbind" 2>/dev/null || true
	sleep 1
	echo "$dev" >"$drv_dir/bind" 2>/dev/null || {
		log "bind $dev failed"
		return 1
	}
	i=0
	while [ "$i" -lt 40 ]; do
		if is_aic_sdio; then
			log "AIC SDIO reappeared after rescan"
			return 0
		fi
		i=$((i + 1))
		sleep 0.25
	done
	log "AIC SDIO did not return after rescan"
	return 1
}

bringup_aic_once() {
	# Prefer vendor rk_wifi_init when present (same binary as Innohi rootfs).
	# Run under timeout in foreground — a background job can segfault and leave
	# bsp/fdrv half-initialized, which then hangs a later insmod.
	if [ -x /usr/bin/rk_wifi_init ]; then
		tty="$(bt_tty 2>/dev/null || echo /dev/ttyS1)"
		log "rk_wifi_init $tty"
		if command -v timeout >/dev/null 2>&1; then
			timeout 20 /usr/bin/rk_wifi_init "$tty" >/dev/null 2>&1 || true
		else
			/usr/bin/rk_wifi_init "$tty" >/dev/null 2>&1 || true
		fi
		if iface="$(wait_wlan)"; then
			log "wlan ready via rk_wifi_init: $iface"
			start_aic_bt || true
			return 0
		fi
		log "rk_wifi_init did not bring wlan; falling back to manual insmod"
		unload_aic_modules
	fi

	# Innohi order: bsp → fdrv → btlpm
	# custregd=0: use cfg80211 regulatory.db (not AIC permissive test domain)
	insmod_one aic8800_bsp || return 1
	insmod_one aic8800_fdrv custregd=0 || return 1
	insmod_one aic8800_btlpm || log "aic8800_btlpm optional / missing — continue"

	if iface="$(wait_wlan)"; then
		log "wlan ready: $iface"
		start_aic_bt || true
		return 0
	fi
	log "wlan not ready after aic8800 insmod"
	return 1
}

bringup_aic() {
	log "detected AIC SDIO (c8a1) — Innohi AIC8800D80 path"
	# SDIO can remain enumerated while the combo ignores CMD52/53 (probe -110 /
	# "No such device"). Reset via mmc-pwrseq by rebinding the host first.
	rescan_aic_sdio || log "SDIO rescan skipped/failed — trying bringup anyway"
	if bringup_aic_once; then
		return 0
	fi
	log "AIC bringup failed; one more SDIO host rescan + retry"
	rescan_aic_sdio || return 1
	bringup_aic_once
}

if command -v rfkill >/dev/null 2>&1; then
	rfkill unblock wifi 2>/dev/null || true
	rfkill unblock wlan 2>/dev/null || true
	rfkill unblock bluetooth 2>/dev/null || true
fi

if ! ensure_firmware_links; then
	log "soft-fail: no OEM radio firmware (Wi-Fi/BT unavailable; HMI continues)"
	exit 1
fi
dump_sdio

# Wi‑Fi often comes up at boot before deferred BT. Do not skip HCI attach.
for d in /sys/class/net/*; do
	[ -e "$d" ] || continue
	if [ -d "$d/wireless" ] || [ -d "$d/phy80211" ]; then
		log "wlan already up: $(basename "$d")"
		if is_aic_sdio; then
			start_aic_bt || log "AIC BT attach soft-fail (wlan already up)"
		fi
		exit 0
	fi
done

if is_aic_sdio; then
	if bringup_aic; then
		exit 0
	fi
	dump_sdio
	lsmod 2>/dev/null | grep -iE 'aic8800|bcmdhd|dhd|rtl' >&2 || log "no wifi ko loaded"
	log "failed to bring up AIC wlan — need aic8800_*.ko (kernel + post-wifibt vendor/lib/modules)"
	exit 1
fi

# Non-AIC fallback: Rockchip wifibt-init (Broadcom / Realtek tables).
log "no AIC SDIO id; trying Rockchip wifibt-init"
if command -v systemctl >/dev/null 2>&1; then
	systemctl start wifibt-init.service 2>/dev/null || true
fi
if command -v wifibt-init.sh >/dev/null 2>&1; then
	wifibt-init.sh start 2>&1 | while read -r line; do log "$line"; done || true
elif [ -x /usr/bin/wifibt-init.sh ]; then
	/usr/bin/wifibt-init.sh start 2>&1 | while read -r line; do log "$line"; done || true
fi

if iface="$(wait_wlan)"; then
	log "wlan ready: $iface"
	exit 0
fi

dump_sdio
lsmod 2>/dev/null | grep -iE 'aic8800|bcmdhd|dhd|rtl' >&2 || log "no wifi ko loaded"
log "failed to bring up wlan"
exit 1
