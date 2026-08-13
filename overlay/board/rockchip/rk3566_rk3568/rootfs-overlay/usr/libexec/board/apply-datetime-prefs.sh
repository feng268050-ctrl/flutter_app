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

if [ -z "$tz" ]; then
	if [ -L /etc/localtime ]; then
		target="$(readlink /etc/localtime 2>/dev/null || true)"
		case "$target" in
		*/zoneinfo/*)
			log "no pref; keeping $(basename "${target##*/zoneinfo/}")"
			exit 0
			;;
		esac
	fi
	tz=Asia/Shanghai
fi

if command -v timedatectl >/dev/null 2>&1; then
	if timedatectl set-timezone "$tz" 2>/dev/null; then
		log "timedatectl → $tz"
		exit 0
	fi
fi

zonefile="/usr/share/zoneinfo/$tz"
if [ -f "$zonefile" ]; then
	ln -sf "$zonefile" /etc/localtime
	log "localtime → $tz"
	exit 0
fi

log "WARN: zoneinfo missing for $tz"
exit 1
