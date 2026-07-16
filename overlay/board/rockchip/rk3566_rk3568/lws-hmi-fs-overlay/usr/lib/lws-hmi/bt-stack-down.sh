#!/bin/sh
# Power down HMI Bluetooth adapter (units stay boot-deferred).
# Usage: bt-stack-down.sh
set -eu

if [ -f /run/lws-hmi-bt-agent.pid ]; then
	kill "$(cat /run/lws-hmi-bt-agent.pid)" 2>/dev/null || true
	rm -f /run/lws-hmi-bt-agent.pid
fi
pkill -f '/usr/lib/lws-hmi/bt-pair-agent.sh' 2>/dev/null || true

if command -v bluetoothctl >/dev/null 2>&1; then
	bluetoothctl discoverable off >/dev/null 2>&1 || true
	bluetoothctl pairable off >/dev/null 2>&1 || true
	bluetoothctl power off >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
	systemctl stop bluealsa-aplay.service 2>/dev/null || true
	systemctl stop bluealsa.service 2>/dev/null || true
	# Intentional stop — clear failed/coredump state so the next stack-up can start.
	systemctl stop bluetooth.service 2>/dev/null || true
	systemctl reset-failed bluetooth.service 2>/dev/null || true
fi

echo "bt-stack-down: done"
