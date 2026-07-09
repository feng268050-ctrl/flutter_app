#!/usr/bin/env bash
# ynh960 debug UART (UART2 / ttyFIQ0): 1500000 8N1 on macOS USB-TTL.
set -euo pipefail

BAUD="${SERIAL_BAUD:-1500000}"
PORT="${SERIAL_PORT:-}"

is_usb_uart() {
  case "$1" in
    /dev/cu.Bluetooth-*|/dev/cu.debug-console) return 1 ;;
    /dev/cu.usb*|/dev/cu.wch*|/dev/cu.SLAB*|/dev/cu.usbmodem*) return 0 ;;
  esac
  return 1
}

pick_port() {
  local p
  for p in /dev/cu.usbserial* /dev/cu.wchusbserial* /dev/cu.SLAB_USBtoUART* /dev/cu.usbmodem*; do
    [[ -e "$p" ]] || continue
    echo "$p"
    return 0
  done
  # Any non-Bluetooth cu.* (user may pass uncommon driver name)
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
  Exit screen: Ctrl-A then K, confirm y
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
  echo "ERROR: $PORT is busy (another serial-console / screen / serial-sniff?)" >&2
  echo "Holder:" >&2
  lsof "$PORT" 2>/dev/null | sed 's/^/  /' >&2 || true
  echo "" >&2
  echo "Fix: kill stale screen —  screen -ls  then  screen -S <id> -X quit" >&2
  echo "  or: pkill -f \"screen $PORT\"" >&2
  exit 1
fi

echo "Serial: $PORT @ ${BAUD} (quit: screen=Ctrl-A K then y; cu=Ctrl-\\ )"
if command -v screen >/dev/null 2>&1; then
  # macOS usbmodem + Cursor terminal: $TERM can be too long for screen.
  export TERM=screen
  exec screen "$PORT" "$BAUD"
fi

if command -v cu >/dev/null 2>&1; then
  exec cu -l "$PORT" -s "$BAUD"
fi

echo "ERROR: install screen: brew install screen" >&2
exit 1
