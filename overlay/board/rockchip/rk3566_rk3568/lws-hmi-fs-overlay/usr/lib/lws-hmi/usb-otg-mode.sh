#!/bin/sh
# Micro-USB OTG mode for ynh960 when ID pin is unused / unreliable.
#
#   debug (USB Debug ON)  → otg_mode=peripheral; VBUS starts plug-ssh
#   host  (USB Debug OFF) → otg_mode=host; stop plug-ssh (keyboard on Micro-USB)
#
# Preference: /var/lib/lws-hmi/usb-debug  ("1"/"0"). Missing file = default ON.
set -eu

PHY_OTG_MODE=/sys/devices/platform/fe8a0000.usb2-phy/otg_mode
PREF=/var/lib/lws-hmi/usb-debug
LOCK_DIR=/run/lws-hmi-usb-otg-mode.lock

usage() {
	echo "usage: $0 {debug|host|status|apply|help}" >&2
	exit 2
}

pref_is_debug() {
	if [ ! -r "$PREF" ]; then
		return 0
	fi
	case "$(tr -d ' \n' <"$PREF")" in
	0 | off | false | host) return 1 ;;
	*) return 0 ;;
	esac
}

write_pref() {
	mkdir -p "$(dirname "$PREF")"
	printf '%s\n' "$1" >"$PREF"
}

otg_set_mode() {
	local want="$1" cur
	[ -w "$PHY_OTG_MODE" ] || return 0
	cur="$(tr -d ' \n' <"$PHY_OTG_MODE" 2>/dev/null || true)"
	[ "$cur" = "$want" ] && return 0
	echo "$want" >"$PHY_OTG_MODE"
}

go_debug() {
	otg_set_mode peripheral
	/usr/lib/lws-hmi/usb-plug-ssh-vbus-check.sh >/dev/null 2>&1 || true
}

go_host() {
	otg_set_mode host
	systemctl stop lws-hmi-usb-plug-ssh.service 2>/dev/null || true
}

cmd_status() {
	local pref mode act
	if pref_is_debug; then
		pref=on
	else
		pref=off
	fi
	mode="$(tr -d ' \n' <"$PHY_OTG_MODE" 2>/dev/null || echo unknown)"
	act="$(systemctl is-active lws-hmi-usb-plug-ssh.service 2>/dev/null || echo inactive)"
	echo "usb-debug=$pref otg_mode=$mode plug-ssh=$act"
	[ "$pref" = on ]
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
	write_pref 1
	go_debug
	;;
host | off | disable)
	write_pref 0
	go_host
	;;
apply)
	if pref_is_debug; then
		go_debug
	else
		go_host
	fi
	;;
*)
	usage
	;;
esac
