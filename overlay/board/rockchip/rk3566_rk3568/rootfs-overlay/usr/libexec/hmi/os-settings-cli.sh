#!/bin/sh
# Foreground OS Settings CLI.
# Default: refuse if hmi.service is active (does not steal the seat).
# --stop-hmi: stop HMI then run OS Settings in the foreground.
# Ctrl+C / exit does NOT start hmi.service — use switch-to-hmi / Exit.
set -eu

STOP_HMI=0
for arg in "$@"; do
	case "$arg" in
	--stop-hmi) STOP_HMI=1 ;;
	-h|--help)
		echo "Usage: os-settings [--stop-hmi]"
		echo "  Default: refuse if hmi.service is active."
		echo "  --stop-hmi: stop HMI, then run OS Settings in the foreground."
		echo "  Interrupt does not restore HMI; run switch-to-hmi."
		exit 0
		;;
	*)
		echo "os-settings: unknown argument: $arg" >&2
		exit 2
		;;
	esac
done

if systemctl is-active --quiet hmi.service 2>/dev/null; then
	if [ "$STOP_HMI" != 1 ]; then
		echo "os-settings: hmi.service is active; refuse seat grab (pass --stop-hmi)." >&2
		exit 1
	fi
	# Conflicts= on units also stop the peer; explicit stop keeps CLI semantics clear.
	systemctl stop hmi.service || true
fi

# If os-settings.service is already managing the seat, do not double-start.
if systemctl is-active --quiet os-settings.service 2>/dev/null; then
	echo "os-settings: os-settings.service already active; use systemctl or Exit." >&2
	exit 1
fi

exec /usr/libexec/hmi/os-settings-launch.sh
