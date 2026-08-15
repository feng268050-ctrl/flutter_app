#!/bin/sh
# ek3562 USB-C OTG mode: debug | mtp | host
#
#   debug → peripheral + plug-ssh (g_ether) on VBUS
#   mtp   → peripheral + MTP gadget on /userdata/storage
#   host  → host role; tear down gadgets on the OTG Type-C
#
# PHY path from vendor Linux lab (2026-08-15): ff740000.usb2-phy
# (NOT ynh960 fe8a0000). UDC: fe500000.usb. Extcon0 under same phy.
#
# Preference (persisted): /var/lib/hal/usb-otg.conf  (mode=debug|mtp|host)
# Board policy (rootfs):  /etc/usb-otg.ini
#   debug_only=true|false          — force debug; no mode UI choices
#   auto_host_support=true|false   — ID/CC may silent-select host at apply
#
# Boot / extcon apply:
#   auto_host_support + USB-HOST → host role (runtime only; conf unchanged)
#   else debug_only → debug (persist)
#   else restore conf (default debug)
set -eu

. /usr/libexec/board/paths.sh 2>/dev/null || true
# shellcheck source=/dev/null
. /usr/libexec/usb/usb-otg-paths.sh 2>/dev/null || true

PHY_OTG_MODE="${PHY_OTG_MODE:-/sys/devices/platform/ff740000.usb2-phy/otg_mode}"
CONF="${VAR_HAL:-/var/lib/hal}/usb-otg.conf"
LOCK_DIR="${RUN_USB_OTG_MODE_LOCK:-/run/usb-otg-mode.lock}"
INI="${ETC_USB_OTG_INI:-/etc/usb-otg.ini}"
# Drop legacy session stamp if present.
rm -f /run/usb-otg.mode 2>/dev/null || true

usage() {
	echo "usage: $0 {debug|mtp|host|status|attached|apply|help}" >&2
	exit 2
}

normalize_bool() {
	case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' \n')" in
	1 | true | yes | on) echo true ;;
	*) echo false ;;
	esac
}

ini_get() {
	local key="$1" def="$2" line val
	[ -r "$INI" ] || {
		echo "$def"
		return 0
	}
	line="$(grep -E "^${key}=" "$INI" 2>/dev/null | head -n1 || true)"
	[ -n "$line" ] || {
		echo "$def"
		return 0
	}
	val="$(printf '%s' "${line#*=}" | tr -d ' \n')"
	normalize_bool "$val"
}

debug_only_on() {
	[ "$(ini_get debug_only false)" = "true" ]
}

auto_host_on() {
	[ "$(ini_get auto_host_support false)" = "true" ]
}

# Persist preference; missing → debug.
read_mode() {
	if [ -r "$CONF" ]; then
		mode="$(grep -E '^mode=' "$CONF" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d ' \n' | tr '[:upper:]' '[:lower:]')"
		case "$mode" in
		debug | mtp | host)
			echo "$mode"
			return 0
			;;
		usb-debug)
			echo debug
			return 0
			;;
		esac
	fi
	echo debug
}

write_mode() {
	mkdir -p "$(dirname "$CONF")"
	printf 'mode=%s\n' "$1" >"$CONF"
}

otg_set_mode() {
	local want="$1" cur
	[ -w "$PHY_OTG_MODE" ] || return 0
	cur="$(tr -d ' \n' <"$PHY_OTG_MODE" 2>/dev/null || true)"
	[ "$cur" = "$want" ] && return 0
	echo "$want" >"$PHY_OTG_MODE"
}

otg_extcon_state() {
	if [ "${USB_OTG_PATHS_LOADED:-}" = 1 ]; then
		usb_otg_read_extcon_state
		return $?
	fi
	local state dir dev
	for state in /sys/class/extcon/extcon*/state; do
		[ -r "$state" ] || continue
		dir="$(dirname "$state")"
		dev="$(readlink -f "$dir" 2>/dev/null || true)"
		case "$dev" in
		*ff740000* | *.usb2-phy | *.usb2-phy/* | *usb2phy*)
			cat "$state"
			return 0
			;;
		esac
	done
	return 1
}

peer_host() {
	local state
	state="$(otg_extcon_state)" || return 1
	echo "$state" | grep -qE '(^|[[:space:]])USB-HOST=1([[:space:]]|$)'
}

peer_gadget() {
	local state
	state="$(otg_extcon_state)" || return 1
	echo "$state" | grep -qE '(^|[[:space:]])USB-HOST=1([[:space:]]|$)' && return 1
	echo "$state" | grep -qE '(^|[[:space:]])USB=1([[:space:]]|$)'
}

# Attach/detach product detection abandoned (ynh960 PHY sticky). `attached`
# remains a no-op diagnostic. Cleanup leftover attach-watch if present.
stop_attach_watch() {
	local pidfile="${RUN_USB_OTG_ATTACH_WATCH_PID:-/run/usb-otg-attach-watch.pid}"
	local pid cache="${RUN_USB_OTG_ATTACH_CACHE:-/run/usb-otg-attach-cache}"
	local p
	if [ -f "$pidfile" ]; then
		pid="$(cat "$pidfile" 2>/dev/null || true)"
		if [ -n "$pid" ]; then
			kill "$pid" 2>/dev/null || true
			sleep 0.05
			kill -9 "$pid" 2>/dev/null || true
		fi
		rm -f "$pidfile" 2>/dev/null || true
	fi
	for p in $(ps 2>/dev/null | grep '[u]sb-otg-attach-watch' | awk '{print $1}'); do
		kill -9 "$p" 2>/dev/null || true
	done
	rmdir "${RUN_USB_OTG_ATTACH_LOCK:-/run/usb-otg-attach.lock}" 2>/dev/null || true
	rmdir /run/usb-otg-attach-watch.instance 2>/dev/null || true
	rm -f "$cache" 2>/dev/null || true
}

# Seed Android-style USB_STATE file after gadget bind (udev handles live edges).
seed_usb_gadget_state() {
	if [ -x /usr/libexec/usb/usb-gadget-usb-state.sh ]; then
		/usr/libexec/usb/usb-gadget-usb-state.sh seed || true
	fi
}

android_state_summary() {
	local st state
	for st in /sys/class/android_usb/*/state; do
		[ -r "$st" ] || continue
		state="$(tr -d ' \n' <"$st" 2>/dev/null || true)"
		[ -n "$state" ] && {
			echo "$state"
			return 0
		}
	done
	echo none
}

udc_state_summary() {
	local st state out=""
	for st in /sys/class/udc/*/state; do
		[ -r "$st" ] || continue
		state="$(tr -d ' \n' <"$st" 2>/dev/null || true)"
		[ -n "$state" ] || continue
		if [ -n "$out" ]; then
			out="$out,"
		fi
		out="${out}${state}"
	done
	[ -n "$out" ] && echo "$out" || echo none
}

stop_gadgets() {
	stop_attach_watch
	systemctl stop ssh-debug-usb.service 2>/dev/null || true
	if [ -x /usr/libexec/usb/usb-mtp-stop.sh ]; then
		/usr/libexec/usb/usb-mtp-stop.sh >/dev/null 2>&1 || true
	fi
}

# True when MTP responder is up and configfs UDC is bound.
mtp_healthy() {
	local pid bound
	[ -f /run/usb-mtp.pid ] || return 1
	pid="$(cat /run/usb-mtp.pid 2>/dev/null || true)"
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
	[ -d /sys/kernel/config/usb_gadget/lws-mtp ] || return 1
	bound="$(tr -d ' \n' </sys/kernel/config/usb_gadget/lws-mtp/UDC 2>/dev/null || true)"
	[ -n "$bound" ]
}

# After host→peripheral, DWC3/UDC may disappear briefly.
wait_peripheral_udc() {
	local i=0
	while [ "$i" -lt 40 ]; do
		if ls /sys/class/udc/*/state >/dev/null 2>&1; then
			return 0
		fi
		sleep 0.1
		i=$((i + 1))
	done
	return 1
}

suppress_apply_storm() {
	# Extcon storms after otg_mode flips; skip apply for a short window.
	mkdir -p /run
	date +%s >/run/usb-otg-suppress-apply
}

apply_suppressed() {
	local stamp now t
	stamp="$(cat /run/usb-otg-suppress-apply 2>/dev/null || true)"
	[ -n "$stamp" ] || return 1
	now="$(date +%s)"
	t=$((now - stamp))
	# Cover mode-switch / extcon settle after otg_mode flips.
	[ "$t" -ge 0 ] && [ "$t" -lt 3 ]
}

go_debug() {
	stop_attach_watch
	if [ -x /usr/libexec/usb/usb-mtp-stop.sh ]; then
		/usr/libexec/usb/usb-mtp-stop.sh >/dev/null 2>&1 || true
	fi
	suppress_apply_storm
	write_mode debug
	otg_set_mode peripheral
	wait_peripheral_udc || true
	rm -f "${RUN_USB_OTG_USB0_RX:-/run/usb-otg-usb0-rx}" 2>/dev/null || true
	rm -f "${RUN_USB_OTG_USB0_PEER:-/run/usb-otg-usb0-peer}" 2>/dev/null || true
	rm -f "${RUN_USB_OTG_DEBUG_ATTACH:-/run/usb-otg-debug-attach}" 2>/dev/null || true
	rm -f "${RUN_USB_OTG_DEBUG_RECONCILE:-/run/usb-otg-debug-reconcile}" 2>/dev/null || true
	# Controlled restart so re-enum is clean after mode switch.
	systemctl stop ssh-debug-usb.service 2>/dev/null || true
	/usr/libexec/usb/usb-plug-ssh-vbus-check.sh >/dev/null 2>&1 || true
	stop_attach_watch
	rm -f "${RUN_USB_GADGET_USB_STATE:-/run/usb-gadget-usb-state}" 2>/dev/null || true
}

go_mtp() {
	# Do not always run usb-plug-ssh-stop (soft_connect disconnect races with
	# live MTP when udev re-enters apply). Only stop if g_ether is present.
	if systemctl is-active --quiet ssh-debug-usb.service 2>/dev/null ||
		[ -d /sys/module/g_ether ] || [ -d /sys/class/net/usb0 ]; then
		systemctl stop ssh-debug-usb.service 2>/dev/null || true
		if [ -x /usr/libexec/usb/usb-plug-ssh-stop.sh ]; then
			/usr/libexec/usb/usb-plug-ssh-stop.sh >/dev/null 2>&1 || true
		fi
	fi
	suppress_apply_storm
	write_mode mtp
	otg_set_mode peripheral
	wait_peripheral_udc || true
	# Brief settle after host role teardown before binding FunctionFS.
	sleep 0.3
	if [ -x /usr/libexec/usb/usb-mtp-start.sh ]; then
		/usr/libexec/usb/usb-mtp-start.sh
	else
		echo "usb-otg-mode: usb-mtp-start.sh missing" >&2
		return 1
	fi
	stop_attach_watch
	seed_usb_gadget_state
}

go_host() {
	stop_gadgets
	suppress_apply_storm
	write_mode host
	otg_set_mode host
}

# Runtime host for ID/CC auto path — does not change persisted preference.
go_host_runtime() {
	stop_gadgets
	suppress_apply_storm
	otg_set_mode host
}

cmd_status() {
	local mode phy plug mtp d a usb udc andr
	mode="$(read_mode)"
	phy="$(tr -d ' \n' <"$PHY_OTG_MODE" 2>/dev/null || echo unknown)"
	plug="$(systemctl is-active ssh-debug-usb.service 2>/dev/null || true)"
	[ -n "$plug" ] || plug=inactive
	if systemctl is-active --quiet usb-mtp.service 2>/dev/null; then
		mtp=active
	elif [ -f /run/usb-mtp.pid ] && kill -0 "$(cat /run/usb-mtp.pid 2>/dev/null)" 2>/dev/null; then
		mtp=active
	else
		mtp=inactive
	fi
	d="$(ini_get debug_only false)"
	a="$(ini_get auto_host_support false)"
	if peer_gadget; then
		usb=1
	elif peer_host; then
		usb=host
	else
		usb=0
	fi
	udc="$(udc_state_summary)"
	andr="$(android_state_summary)"
	# attached=0 always — product attach detection abandoned.
	echo "mode=$mode otg_mode=$phy plug-ssh=$plug mtp=$mtp attached=0 usb=$usb udc=$udc android=$andr debug_only=$d auto_host_support=$a"
	[ "$mode" = debug ]
}

cmd_attached() {
	# No-op diagnostic (not a product signal).
	echo "attached=0"
	return 0
}

acquire() {
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		echo $$ >"$LOCK_DIR/pid"
		return 0
	fi
	if [ -f "$LOCK_DIR/pid" ]; then
		old="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
		if [ -n "$old" ] && ! kill -0 "$old" 2>/dev/null; then
			rm -rf "$LOCK_DIR"
			mkdir "$LOCK_DIR" 2>/dev/null || return 1
			echo $$ >"$LOCK_DIR/pid"
			return 0
		fi
	fi
	return 1
}

cmd="${1:-}"
case "$cmd" in
status)
	cmd_status
	exit $?
	;;
attached)
	cmd_attached
	exit $?
	;;
help | -h | --help)
	usage
	;;
esac

if ! acquire; then
	exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT HUP INT TERM

case "$cmd" in
debug | on | enable)
	go_debug
	;;
mtp)
	go_mtp
	;;
host | off | disable)
	go_host
	;;
apply)
	# Skip while a mode switch is in flight (extcon storms after otg_mode flip).
	if apply_suppressed; then
		exit 0
	fi
	if auto_host_on && peer_host; then
		go_host_runtime
	elif debug_only_on; then
		go_debug
	else
		case "$(read_mode)" in
		mtp)
			# Idempotent: do not soft_connect/restart a healthy MTP session.
			if mtp_healthy; then
				otg_set_mode peripheral
				seed_usb_gadget_state
			else
				go_mtp
			fi
			;;
		host)
			# Keep host; avoid teardown/re-apply loops.
			otg_set_mode host
			stop_attach_watch
			rm -f "${RUN_USB_GADGET_USB_STATE:-/run/usb-gadget-usb-state}" 2>/dev/null || true
			;;
		*)
			go_debug
			;;
		esac
	fi
	;;
*)
	usage
	;;
esac
