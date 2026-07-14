#!/bin/sh
# Headless BlueZ pairing agent (phone → HMI).
#
# Phones often use Numeric Comparison / "Confirm passkey" — that needs
# DisplayYesNo, not NoInputNoOutput (JustWorks only). Auto-answer "yes" on
# agent prompts. Keep bluetoothctl alive so Agent1 stays registered.
#
# After Paired: yes, immediately Trust (+ Connect if bluealsa is up) so iPhone
# can finish A2DP without losing the short post-PIN window.
set -eu

CAPABILITY="${LWS_BT_AGENT_CAPABILITY:-DisplayYesNo}"
LOG="${LWS_BT_AGENT_LOG:-/tmp/lws-bt-agent.log}"
PIDFILE="${LWS_BT_AGENT_PIDFILE:-/run/lws-hmi-bt-agent.pid}"
FIFO="${LWS_BT_AGENT_FIFO:-/run/lws-hmi-btctl.fifo}"

log() {
	echo "bt-pair-agent: $*" >>"$LOG"
	echo "bt-pair-agent: $*" >&2
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
	log "bluetoothctl missing"
	exit 1
fi

if [ -f "$PIDFILE" ]; then
	old="$(cat "$PIDFILE" 2>/dev/null || true)"
	if [ -n "$old" ] && kill -0 "$old" 2>/dev/null; then
		log "already running pid=$old"
		exit 0
	fi
	rm -f "$PIDFILE"
fi

i=0
while [ "$i" -lt 40 ]; do
	if bluetoothctl show >/dev/null 2>&1; then
		break
	fi
	i=$((i + 1))
	sleep 0.25
done

rm -f "$FIFO"
mkfifo "$FIFO"
exec 3<>"$FIFO"

YES_PID=""
cleanup() {
	kill "$YES_PID" 2>/dev/null || true
	exec 3<&- 2>/dev/null || true
	exec 3>&- 2>/dev/null || true
	rm -f "$FIFO"
}
trap cleanup EXIT INT TERM

: >"$LOG"
log "starting bluetoothctl --agent=$CAPABILITY"

set +e
bluetoothctl --agent="$CAPABILITY" <&3 >>"$LOG" 2>&1 &
BT_PID=$!
set -e

sleep 0.3
if ! kill -0 "$BT_PID" 2>/dev/null; then
	log "--agent= failed; fallback without flag"
	bluetoothctl <&3 >>"$LOG" 2>&1 &
	BT_PID=$!
	sleep 0.5
	printf '%s\n' "agent $CAPABILITY" >&3
fi

echo "$BT_PID" >"$PIDFILE"
log "bluetoothctl pid=$BT_PID"

sleep 0.5
printf '%s\n' 'default-agent' 'pairable on' >&3
log "sent default-agent / pairable on"

# Auto-accept Confirm passkey / Authorize service / RequestAuthorization.
# On Paired: yes → Trust only (do NOT connect; that triggers initiator SDP ENOSYS).
(
	last_prompt=""
	last_paired=""
	while kill -0 "$BT_PID" 2>/dev/null; do
		hit="$(grep -Eia 'confirm passkey|authorize service|request confirmation|request authorization|yes/no' "$LOG" 2>/dev/null | tail -1 || true)"
		if [ -n "$hit" ] && [ "$hit" != "$last_prompt" ]; then
			log "auto-yes for: $hit"
			printf 'yes\n' >&3
			last_prompt="$hit"
			sleep 0.5
		fi

		paired_line="$(grep -E 'Paired:\s*yes' "$LOG" 2>/dev/null | tail -1 || true)"
		if [ -n "$paired_line" ] && [ "$paired_line" != "$last_paired" ]; then
			last_paired="$paired_line"
			log "paired detected — trust only (phone initiates A2DP)"
			addr="$(grep -Eo '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' "$LOG" 2>/dev/null | tail -1 || true)"
			if [ -x /usr/lib/lws-hmi/bt-trust-paired.sh ]; then
				/usr/lib/lws-hmi/bt-trust-paired.sh || true
			elif [ -n "$addr" ]; then
				printf '%s\n' "trust $addr" >&3 || true
			fi
		fi
		sleep 0.2
	done
) &
YES_PID=$!

wait "$BT_PID"
status=$?
log "bluetoothctl exited status=$status"
rm -f "$PIDFILE"
exit "$status"
