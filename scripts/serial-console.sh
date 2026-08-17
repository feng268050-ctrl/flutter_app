#!/usr/bin/env bash
# Host serial console: MODE=TTL (default, pyserial miniterm) or MODE=RS485|RS232
# (curses hex console with fixed TX input bar).
# TTL baud (when BAUD unset): cu.usbmodem* / wch* / SLAB* → 1500000 (ynh960 FIQ);
#   cu.usbserial* → 115200 (ek3562 USB-C Debug CH340). BAUD= always wins.
# RS485/RS232: USB adapter @ 115200 default; RX hex / TX bar (quit: Esc or :q).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-}"
MODE_RAW="${MODE:-TTL}"
MODE="$(printf '%s' "$MODE_RAW" | tr '[:lower:]' '[:upper:]')"
LOG_PATH="${LOG_FILE:-}"
# Preserve whether the operator set BAUD before we pick a port-aware default.
USER_BAUD="${BAUD:-}"

case "$MODE" in
  TTL)
    BACKEND=miniterm
    QUIT_HINT='Ctrl+]'
    ;;
  RS485|RS232)
    BACKEND=serial-hex-console
    QUIT_HINT='Esc or :q'
    ;;
  *)
    echo "ERROR: MODE must be TTL, RS485, or RS232 (got: ${MODE_RAW})" >&2
    exit 1
    ;;
esac

# TTL: onboard CH9102 often enumerates as cu.usbmodem* @ 1.5M (ynh960 Debug).
# Classic CH340 USB-C Debug (ek3562) is cu.usbserial* @ 115200. External WCH/SLAB
# TTL dongles to ynh960 UART2 stay 1.5M unless BAUD= overrides.
ttl_default_baud() {
  case "$1" in
    /dev/cu.usbserial*|/dev/ttyUSB*)
      echo 115200
      ;;
    *)
      echo 1500000
      ;;
  esac
}

is_usb_uart() {
  case "$1" in
    /dev/cu.Bluetooth-*|/dev/cu.debug-console) return 1 ;;
    /dev/cu.usb*|/dev/cu.wch*|/dev/cu.SLAB*|/dev/cu.usbmodem*) return 0 ;;
  esac
  return 1
}

pick_port() {
  local p
  for p in /dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.wchusbserial* /dev/cu.SLAB_USBtoUART*; do
    [[ -e "$p" ]] || continue
    echo "$p"
    return 0
  done
  for p in /dev/cu.*; do
    [[ -e "$p" ]] || continue
    is_usb_uart "$p" || continue
    echo "$p"
    return 0
  done
  return 1
}

list_ports() {
  echo "Available /dev/cu.* ports:"
  ls -1 /dev/cu.* 2>/dev/null || echo "  (none)"
}

usb_uart_hint() {
  cat <<'EOF'

USB serial adapter not detected. Check:

  1. Dongle plugged into Mac (UART/RS end goes to board or bus, USB end to Mac)
  2. Data cable — not charge-only
  3. Driver (unplug/replug, then check System Settings → Privacy → USB):
     • CH340/CH341 → WCH driver: https://www.wch.cn/downloads/CH341SER_MAC_ZIP.html
     • CP2102     → Silicon Labs CP210x VCP driver
     • FTDI       → often works without extra driver on macOS
  4. After driver install: unplug adapter, replug, run:
       ls /dev/cu.*
     expect e.g. /dev/cu.wchusbserial1410 or /dev/cu.usbserial-XXXX

  5. TTL wiring (MODE=TTL, 3.3V only — do NOT use 5V):
       USB-TTL GND  → board GND
       USB-TTL TX   → board RX
       USB-TTL RX   → board TX
     UART2 / debug header on core board (ask Innohi silkscreen if unsure)

  Then:
       PORT=/dev/cu.wchusbserial1410 make serial-console
       MODE=RS485 PORT=/dev/cu.usbserial-XXXX make serial-console

EOF
  if system_profiler SPUSBDataType 2>/dev/null | grep -qiE 'ch34|wch|cp210|ftdi|serial'; then
    echo "USB profiler sees a UART chip — driver may still be loading; wait 5s and retry."
    system_profiler SPUSBDataType 2>/dev/null | grep -A6 -iE 'ch34|wch|cp210|ftdi|serial' | head -20
  else
    echo "system_profiler: no USB serial chip visible — dongle not connected or not enumerated."
  fi
}

usage() {
  cat <<EOF
Usage: [MODE=TTL|RS485|RS232] [PORT=…] [BAUD=…] make serial-console

  MODE (default TTL, case-insensitive):
    TTL    pyserial miniterm → debug UART (baud by port unless BAUD= set)
    RS485  curses hex console → USB-RS485 (default baud 115200; RX hex + TX bar)
    RS232  curses hex console → USB-RS232 (default baud 115200; RX hex + TX bar)

  PORT=…                    host serial device (auto-pick /dev/cu.usb* if unset)
  BAUD=…                    override baud (all modes)
                            TTL defaults: cu.usbserial* → 115200 (ek3562 Debug);
                              cu.usbmodem* / wch* / SLAB* → 1500000 (ynh960 FIQ)
  DATABITS=…                framing (RS485/RS232): 5|6|7|8 (default 8)
  PARITY=…                  framing: none|even|odd|mark|space (default none)
  STOPBITS=…                framing: 1|2 (default 1)
  LOG_FILE=…                session log file (RS485/RS232 only)
  LOG_APPEND=1              append to log file
  TIMESTAMP_TIMEOUT=ms      RX idle gap → new line (default 5)

  List ports:  make serial-ports
  Quit TTL:    Ctrl+]
  Quit hex:    Esc, or type :q / quit / exit in TX bar then Enter
  TX bar:      type hex (e.g. 01 03 00 00) then Enter to send
EOF
}

[[ "${1:-}" == -h || "${1:-}" == --help ]] && usage && exit 0
[[ "${1:-}" == --list ]] && list_ports && exit 0

if [[ -n "$LOG_PATH" && "$MODE" == TTL ]]; then
  echo "ERROR: file logging (LOG_FILE=) requires MODE=RS485 or MODE=RS232 (TTL uses miniterm)." >&2
  exit 1
fi

if [[ -z "$PORT" ]]; then
  PORT="$(pick_port)" || {
    echo "ERROR: no USB serial port found." >&2
    list_ports
    usb_uart_hint
    exit 1
  }
fi

[[ -e "$PORT" ]] || { echo "ERROR: $PORT not found" >&2; list_ports; exit 1; }

if [[ -n "$USER_BAUD" ]]; then
  BAUD="$USER_BAUD"
elif [[ "$MODE" == TTL ]]; then
  BAUD="$(ttl_default_baud "$PORT")"
else
  BAUD=115200
fi

if lsof "$PORT" >/dev/null 2>&1; then
  echo "ERROR: $PORT is busy (another serial-console / serial-sniff?)" >&2
  lsof "$PORT" 2>/dev/null | sed 's/^/  /' >&2 || true
  exit 1
fi

echo "serial-console $PORT  MODE=$MODE  baud=$BAUD  backend=$BACKEND  (quit: $QUIT_HINT)"

PY="$("$ROOT/scripts/ensure-serial-venv.sh")"

if [[ "$MODE" == TTL ]]; then
  echo "  terminal: 206x50 (board sends xterm resize on login; widen host window if lines still wrap)"
  # miniterm's default filter strips ESC/CSI (breaks ANSI colors from kernel/systemd).
  if [[ -z "${TERM:-}" || "${TERM}" == dumb ]]; then
    export TERM=xterm-256color
  fi
  exec "$PY" -m serial.tools.miniterm -f direct "$PORT" "$BAUD"
fi

# RS485 / RS232: curses hex console with fixed TX input bar (no tio).
idle_ms="${TIMESTAMP_TIMEOUT:-5}"
data_bits="${DATABITS:-8}"
parity="${PARITY:-none}"
stop_bits="${STOPBITS:-1}"
echo "  hex console: RX idle→newline ${idle_ms}ms; bottom TX> bar (hex + Enter)"
[[ "$MODE" == RS485 ]] && echo "  note: electrical RS-485 is the USB adapter; host opens plain serial"

hex_args=(
  "$ROOT/scripts/serial-hex-console.py"
  "$PORT"
  --baud "$BAUD"
  --mode "$MODE"
  --data-bits "$data_bits"
  --parity "$parity"
  --stop-bits "$stop_bits"
  --idle-ms "$idle_ms"
)
if [[ -n "$LOG_PATH" ]]; then
  hex_args+=(--log "$LOG_PATH")
  [[ "${LOG_APPEND:-}" == 1 ]] && hex_args+=(--log-append)
  echo "  log: $LOG_PATH${LOG_APPEND:+ (append=${LOG_APPEND})}"
fi

exec "$PY" "${hex_args[@]}"
