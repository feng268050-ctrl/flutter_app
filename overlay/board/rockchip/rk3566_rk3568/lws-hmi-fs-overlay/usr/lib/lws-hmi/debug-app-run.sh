#!/bin/sh
# Start debug flutter-pi for IDE sessions; keep process alive after SSH detach.
set -eu

BUNDLE=/opt/hmi
MODE_FILE="$BUNDLE/runtime-mode.json"
LOG=/var/lib/lws-hmi/debug-app.log
PIDFILE=/var/lib/lws-hmi/debug-app.pid
VM_LINE_FILE=/var/lib/lws-hmi/debug-app.vm-service

log() {
	echo "lws-hmi-debug-run: $*"
}

read_json_field() {
	file="$1"
	key="$2"
	grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
		| sed 's/.*"\([^"]*\)"$/\1/' \
		| head -1
}

emit_vm_service_line() {
	line="$(grep -Ei 'Dart VM service is listening on|VM Service is listening on|Observatory listening on' "$LOG" 2>/dev/null \
		| tail -1 || true)"
	[ -n "$line" ] || return 1
	printf '%s\n' "$line" | tee "$VM_LINE_FILE"
}

pid_is_live() {
	pid="$1"
	[ -r "/proc/$pid/stat" ] || return 1
	IFS=' ' read -r _ _ state _ <"/proc/$pid/stat" || return 1
	[ "$state" != "Z" ]
}

stop_ide_session_only() {
	exit 0
}

trap stop_ide_session_only TERM INT

[ -f "$MODE_FILE" ] || {
	log "missing $MODE_FILE"
	exit 1
}
MODE="$(read_json_field "$MODE_FILE" mode)"
[ "$MODE" = "debug" ] || {
	log "installed payload is not debug mode"
	exit 1
}

if [ -f "$PIDFILE" ] && pid_is_live "$(cat "$PIDFILE")"; then
	if [ -f "$VM_LINE_FILE" ]; then
		cat "$VM_LINE_FILE"
	else
		emit_vm_service_line || true
	fi
	exec tail -F "$LOG"
fi

/usr/lib/lws-hmi/hmi-stop-and-wait.sh
: >"$LOG"
start-stop-daemon -S -b -m -p "$PIDFILE" \
	-x /bin/sh -- -c "exec /usr/lib/lws-hmi/hmi-launch.sh >>'$LOG' 2>&1"

i=0
while [ "$i" -lt 60 ]; do
	if emit_vm_service_line; then
		exec tail -F "$LOG"
	fi
	if ! pid_is_live "$(cat "$PIDFILE")"; then
		log "flutter-pi exited during startup"
		tail -40 "$LOG" >&2 || true
		exit 1
	fi
	i=$((i + 1))
	sleep 1
done

log "timed out waiting for VM Service"
tail -40 "$LOG" >&2 || true
exit 1
