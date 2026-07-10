#!/bin/sh
# Intercept poweroff/halt/reboot before poweroff.target activates.
set -eu

case "${1:-}" in
poweroff|halt|reboot)
	mode="$1"
	shift
	exec /usr/lib/lws-hmi/shutdown.sh "$mode" "$@"
	;;
esac

if [ ! -x /usr/bin/systemctl.real ]; then
	echo "lws-hmi-systemctl: missing /usr/bin/systemctl.real" >/dev/console 2>&1
	exit 1
fi

exec /usr/bin/systemctl.real "$@"
