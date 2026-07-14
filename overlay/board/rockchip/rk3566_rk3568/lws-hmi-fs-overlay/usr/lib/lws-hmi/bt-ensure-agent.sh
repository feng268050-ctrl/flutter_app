#!/bin/sh
# Ensure the headless pairing agent is running (idempotent).
set -eu

AGENT="/usr/lib/lws-hmi/bt-pair-agent.sh"
PIDFILE="/run/lws-hmi-bt-agent.pid"

if [ -f "$PIDFILE" ]; then
	pid="$(cat "$PIDFILE" 2>/dev/null || true)"
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		exit 0
	fi
	rm -f "$PIDFILE"
fi

if [ ! -x "$AGENT" ]; then
	echo "bt-ensure-agent: missing $AGENT" >&2
	exit 1
fi

# Kill stale fifo/agent shells from older implementations.
pkill -f '/usr/lib/lws-hmi/bt-pair-agent.sh' 2>/dev/null || true
rm -f /run/lws-hmi-btctl.fifo

"$AGENT" >/tmp/lws-bt-agent.log 2>&1 &
# Give it a moment to write the pidfile (bluetoothctl pid).
i=0
while [ "$i" -lt 20 ]; do
	if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
		echo "bt-ensure-agent: ok pid=$(cat "$PIDFILE")" >&2
		exit 0
	fi
	i=$((i + 1))
	sleep 0.1
done

echo "bt-ensure-agent: agent failed to start — see /tmp/lws-bt-agent.log" >&2
tail -40 /tmp/lws-bt-agent.log >&2 || true
exit 1
