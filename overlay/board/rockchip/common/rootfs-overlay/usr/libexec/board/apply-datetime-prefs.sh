#!/bin/sh
# Apply timezone from /var/lib/hal/datetime.conf to libc (/etc/localtime).
# Idempotent; safe before HMI / os_settings start.
set -eu

log() {
	echo "apply-datetime-prefs: $*"
}

conf=/var/lib/hal/datetime.conf
tz=""
if [ -f "$conf" ]; then
	tz="$(sed -n 's/^timezone=//p' "$conf" 2>/dev/null | head -n1 | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
fi

current_tz=""
if [ -L /etc/localtime ]; then
	target="$(readlink /etc/localtime 2>/dev/null || true)"
	case "$target" in
	*/zoneinfo/*)
		current_tz="${target##*/zoneinfo/}"
		;;
	esac
fi

if [ -z "$tz" ]; then
	if [ -n "$current_tz" ]; then
		log "no pref; keeping $current_tz"
		exit 0
	fi
	tz=Asia/Shanghai
fi

# Boot KPI: skip D-Bus timedatectl when libc TZ is already correct
# (param-update often applied this moments earlier).
if [ "$current_tz" = "$tz" ]; then
	log "already $tz"
	exit 0
fi

# Prefer direct zoneinfo link — timedatectl → timedated is slow on cold boot.
zonefile="/usr/share/zoneinfo/$tz"
if [ -f "$zonefile" ]; then
	ln -sf "$zonefile" /etc/localtime
	log "localtime → $tz"
	exit 0
fi

if command -v timedatectl >/dev/null 2>&1; then
	if timedatectl set-timezone "$tz" 2>/dev/null; then
		log "timedatectl → $tz"
		exit 0
	fi
fi

log "WARN: zoneinfo missing for $tz"
exit 1
