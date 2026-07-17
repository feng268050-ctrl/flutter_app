#!/bin/sh
# Stop the shell bluetoothctl pairing agent (for HMI Agent1 handoff).
set -eu

PIDFILE="${LWS_BT_AGENT_PIDFILE:-/run/lws-hmi-bt-agent.pid}"

if [ -f "$PIDFILE" ]; then
	pid="$(cat "$PIDFILE" 2>/dev/null || true)"
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		kill "$pid" 2>/dev/null || true
		# Wait briefly for exit.
		i=0
		while [ "$i" -lt 20 ] && kill -0 "$pid" 2>/dev/null; do
			i=$((i + 1))
			sleep 0.05
		done
		kill -9 "$pid" 2>/dev/null || true
	fi
	rm -f "$PIDFILE"
fi

pkill -f '/usr/lib/lws-hmi/bt-pair-agent.sh' 2>/dev/null || true
rm -f /run/lws-hmi-btctl.fifo
exit 0
