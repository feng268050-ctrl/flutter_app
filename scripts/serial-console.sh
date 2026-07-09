#!/usr/bin/env bash
# ynh960 debug UART (UART2 / ttyFIQ0): 1500000 8N1 via pyserial miniterm (quit: Ctrl+]).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${SERIAL_PORT:-}"
BAUD="${SERIAL_BAUD:-1500000}"
PY="$("$ROOT/scripts/ensure-serial-venv.sh")"

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

USB-TTL not detected. Check:

  1. USB-TTL dongle plugged into Mac (UART end goes to board, USB end to Mac)
  2. Data cable — not charge-only
  3. Driver (unplug/replug, then check System Settings → Privacy → USB):
     • CH340/CH341 → WCH driver: https://www.wch.cn/downloads/CH341SER_MAC_ZIP.html
     • CP2102     → Silicon Labs CP210x VCP driver
     • FTDI       → often works without extra driver on macOS
  4. After driver install: unplug USB-TTL, replug, run:
       ls /dev/cu.*
     expect e.g. /dev/cu.wchusbserial1410 or /dev/cu.usbserial-XXXX

  5. Board wiring (3.3V TTL only — do NOT use 5V):
       USB-TTL GND  → board GND
       USB-TTL TX   → board RX
       USB-TTL RX   → board TX
     UART2 / debug header on core board (ask Innohi silkscreen if unsure)

  Then:
       SERIAL_PORT=/dev/cu.wchusbserial1410 make serial-console

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
Usage: SERIAL_PORT=/dev/cu.usbserial-XXX make serial-console

  Baud: ${BAUD} (ynh960 earlycon=ttyFIQ0)
  List ports:  make serial-ports
  Quit:        Ctrl+]
EOF
}

[[ "${1:-}" == -h || "${1:-}" == --help ]] && usage && exit 0
[[ "${1:-}" == --list ]] && list_ports && exit 0

if [[ -z "$PORT" ]]; then
  PORT="$(pick_port)" || {
    echo "ERROR: no USB-TTL serial port found." >&2
    list_ports
    usb_uart_hint
    exit 1
  }
fi

[[ -e "$PORT" ]] || { echo "ERROR: $PORT not found" >&2; list_ports; exit 1; }

if lsof "$PORT" >/dev/null 2>&1; then
  echo "ERROR: $PORT is busy (another serial-console / serial-sniff?)" >&2
  lsof "$PORT" 2>/dev/null | sed 's/^/  /' >&2 || true
  exit 1
fi

echo "serial-console $PORT @ $BAUD  (quit: Ctrl+])"
# miniterm's default filter strips ESC/CSI (breaks ANSI colors from kernel/systemd).
if [[ -z "${TERM:-}" || "${TERM}" == dumb ]]; then
  export TERM=xterm-256color
fi
exec "$PY" -m serial.tools.miniterm -f direct "$PORT" "$BAUD"
