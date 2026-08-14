#!/bin/sh
# Stop every release/debug HMI embedder (Weston + flutter-wayland-client) and wait
# for DRM/Mali teardown.
set -eu

TIMEOUT="${1:-15}"
PIDFILE=/var/lib/hmi/debug-app.pid
DEBUG_LOG=/var/lib/hmi/debug-app.log

log() {
	echo "hmi-stop: $*"
}

live_flutter_pids() {
	for comm_file in /proc/[0-9]*/comm; do
		[ -r "$comm_file" ] || continue
		IFS= read -r comm <"$comm_file" || continue
		case "$comm" in
		flutter-wayland | flutter-waylan)
			# BusyBox /proc/comm is TASK_COMM_LEN (16): flutter-wayland-client → flutter-waylan
			;;
		*)
			continue
			;;
		esac
		pid="${comm_file#/proc/}"
		pid="${pid%/comm}"
		IFS=' ' read -r _ _ state _ <"/proc/$pid/stat" || continue
		[ "$state" = "Z" ] || printf '%s\n' "$pid"
	done
}

live_weston_pids() {
	for comm_file in /proc/[0-9]*/comm; do
		[ -r "$comm_file" ] || continue
		IFS= read -r comm <"$comm_file" || continue
		[ "$comm" = "weston" ] || continue
		pid="${comm_file#/proc/}"
		pid="${pid%/comm}"
		IFS=' ' read -r _ _ state _ <"/proc/$pid/stat" || continue
		[ "$state" = "Z" ] || printf '%s\n' "$pid"
	done
}

reap_stale_flutter_zombies() {
	for comm_file in /proc/[0-9]*/comm; do
		[ -r "$comm_file" ] || continue
		IFS= read -r comm <"$comm_file" || continue
		case "$comm" in
		flutter-wayland | flutter-waylan) ;;
		*) continue ;;
		esac
		pid="${comm_file#/proc/}"
		pid="${pid%/comm}"
		IFS=' ' read -r _ _ state ppid _ <"/proc/$pid/stat" || continue
		[ "$state" = "Z" ] || continue
		[ -r "/proc/$ppid/comm" ] || continue
		IFS= read -r parent_comm <"/proc/$ppid/comm" || continue
		if [ "$parent_comm" = "tail" ]; then
			log "reaping stale embedder zombie $pid via log tail parent $ppid"
			kill "$ppid" 2>/dev/null || true
		fi
	done
}

stop_stale_debug_log_tails() {
	for comm_file in /proc/[0-9]*/comm; do
		[ -r "$comm_file" ] || continue
		IFS= read -r comm <"$comm_file" || continue
		[ "$comm" = "tail" ] || continue
		pid="${comm_file#/proc/}"
		pid="${pid%/comm}"
		[ -r "/proc/$pid/cmdline" ] || continue
		cmdline="$(tr '\000' ' ' <"/proc/$pid/cmdline")"
		case "$cmdline" in
		*"tail -F $DEBUG_LOG"*)
			kill "$pid" 2>/dev/null || true
			;;
		esac
	done
}

systemctl stop hmi.service 2>/dev/null || true

stop_stale_debug_log_tails
if [ -f "$PIDFILE" ]; then
	pid="$(cat "$PIDFILE" 2>/dev/null || true)"
	[ -z "$pid" ] || kill "$pid" 2>/dev/null || true
fi
reap_stale_flutter_zombies
live_pids="$(live_flutter_pids)"
[ -z "$live_pids" ] || kill $live_pids 2>/dev/null || true
weston_pids="$(live_weston_pids)"
[ -z "$weston_pids" ] || kill $weston_pids 2>/dev/null || true

i=0
while { [ -n "$(live_flutter_pids)" ] || [ -n "$(live_weston_pids)" ]; } \
	&& [ "$i" -lt "$TIMEOUT" ]; do
	i=$((i + 1))
	sleep 1
done

live_pids="$(live_flutter_pids)"
weston_pids="$(live_weston_pids)"
if [ -n "$live_pids" ] || [ -n "$weston_pids" ]; then
	log "embedder did not exit after ${TIMEOUT}s; forcing termination"
	[ -z "$live_pids" ] || kill -9 $live_pids 2>/dev/null || true
	[ -z "$weston_pids" ] || kill -9 $weston_pids 2>/dev/null || true
	sleep 1
fi

if [ -n "$(live_flutter_pids)" ] || [ -n "$(live_weston_pids)" ]; then
	log "HMI embedder is still running; refusing to start a second instance"
	exit 1
fi
rm -f "$PIDFILE" /var/lib/hmi/debug-app.vm-service
# Let deferred DRM/Mali task_work complete before another instance opens DRM.
sleep 1
log "all HMI embedder processes stopped"
