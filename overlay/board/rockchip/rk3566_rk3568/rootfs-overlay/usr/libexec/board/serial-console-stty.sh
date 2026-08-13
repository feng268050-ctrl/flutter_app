#!/bin/sh
# Serial console geometry for ttyFIQ0: kernel winsize + xterm resize to host terminal.
set -eu

COLS="${SERIAL_COLS:-206}"
ROWS="${SERIAL_ROWS:-50}"
STTY=/bin/stty
[ -x "$STTY" ] || STTY=stty

log() {
	[ "${SERIAL_STTY_DEBUG:-0}" = 1 ] || return 0
	echo "serial-console-stty: $*" >&2
}

emit_terminal_resize() {
	# DECSLPP / xterm: resize terminal emulator (Cursor/iTerm); ignored on raw UART sniffers.
	local out="$1"
	[ -n "$out" ] || return 0
	[ -e "$out" ] || return 0
	printf '\033[8;%s;%st' "$ROWS" "$COLS" >"$out" 2>/dev/null || true
}

apply_device_stty() {
	local dev="$1"
	[ -e "$dev" ] || return 0
	# Keep line settings; only set geometry (BusyBox + coreutils stty).
	"$STTY" -F "$dev" columns "$COLS" rows "$ROWS" 2>/dev/null || return 1
	log "stty -F $dev -> $( "$STTY" -F "$dev" size 2>/dev/null || echo '?' )"
	emit_terminal_resize "$dev"
	return 0
}

# Controlling tty (login shell / profile): affects systemctl, less, etc.
if [ -t 0 ] && [ -t 1 ]; then
	"$STTY" columns "$COLS" rows "$ROWS" 2>/dev/null || true
	export COLUMNS="$COLS" LINES="$ROWS"
	log "stty controlling tty -> $( "$STTY" size 2>/dev/null || echo '?' )"
	emit_terminal_resize "$(tty 2>/dev/null || echo /dev/tty)"
fi

for dev in /dev/ttyFIQ0 /dev/console; do
	apply_device_stty "$dev" || true
done
