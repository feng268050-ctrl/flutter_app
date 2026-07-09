#!/usr/bin/env bash
# Listen on USB-TTL at common Rockchip baud rates (power-cycle board while this runs).
set -euo pipefail

PORT="${SERIAL_PORT:-}"
SEC="${SERIAL_SNIFF_SEC:-8}"
LOG="/tmp/serial-sniff-$$.log"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pick_port() {
  local p
  for p in /dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.wchusbserial* /dev/cu.SLAB_USBtoUART*; do
    [[ -e "$p" ]] || continue
    echo "$p"
    return 0
  done
  return 1
}

cleanup() {
  local s
  s="$(screen -ls 2>/dev/null | awk -v p="$PORT" '$0 ~ p && $0 ~ /Detached/ {gsub(/^\./,"",$1); print $1; exit}')" || true
  [[ -n "$s" ]] && screen -S "$s" -X quit 2>/dev/null || true
  rm -f "$LOG"
}
trap cleanup EXIT

[[ -n "$PORT" ]] || PORT="$(pick_port)" || {
  echo "ERROR: set SERIAL_PORT=/dev/cu.... (make serial-ports)" >&2
  exit 1
}

[[ -e "$PORT" ]] || { echo "ERROR: $PORT not found" >&2; exit 1; }

sniff_pyserial() {
  local py="$1"
  "$py" - "$PORT" "$SEC" <<'PY'
import sys, time
port, sec = sys.argv[1], int(sys.argv[2])
import serial
for baud in (1500000, 115200, 921600, 57600):
    print(f"\n=== {port} @ {baud} for {sec}s — power-cycle board NOW ===", flush=True)
    try:
        s = serial.Serial(port, baud, timeout=0.2)
    except Exception as e:
        print(f"open failed: {e}", flush=True)
        continue
    end = time.time() + sec
    got = 0
    while time.time() < end:
        data = s.read(4096)
        if data:
            got += len(data)
            sys.stdout.buffer.write(data)
            sys.stdout.flush()
    s.close()
    if got:
        print(f"\n>>> got {got} bytes at {baud}", flush=True)
        print(f">>> use: SERIAL_PORT={port} SERIAL_BAUD={baud} make serial-miniterm", flush=True)
        sys.exit(0)
print("\nNo data at any baud.", flush=True)
sys.exit(1)
PY
}

# macOS: stty often fails on usbmodem / 1500000 — use detached screen -L.
sniff_screen() {
  local baud="$1" sess
  echo ""
  echo "=== $PORT @ ${baud} for ${SEC}s — power-cycle / reset board NOW ==="
  command -v screen >/dev/null 2>&1 || {
    echo "ERROR: need screen (brew install screen) or: python3 -m pip install --user pyserial" >&2
    return 1
  }
  cleanup
  rm -f "$LOG"
  screen -L -Logfile "$LOG" -dm env TERM=screen "$PORT" "$baud" || {
    echo "WARN: screen $baud failed" >&2
    return 1
  }
  sleep "$SEC"
  sess="$(screen -ls 2>/dev/null | awk -v p="$PORT" '$0 ~ p && $0 ~ /Detached/ {gsub(/^\./,"",$1); print $1; exit}')" || true
  [[ -n "$sess" ]] && screen -S "$sess" -X quit 2>/dev/null || true
  sleep 0.3
  if [[ -s "$LOG" ]]; then
    # Strip screen log header lines if present; show printable data.
    grep -av '^[[:space:]]*$' "$LOG" | tail -n +1 | cat -v
    return 0
  fi
  return 1
}

echo "Serial sniff: $PORT"

PY="$("$ROOT/scripts/ensure-serial-venv.sh")"
if sniff_pyserial "$PY"; then
  exit 0
fi

if [[ "$(uname -s)" == Darwin ]]; then
  echo "pyserial sniff found nothing — fallback to screen ..."
fi

for baud in 1500000 115200 921600 57600; do
  if sniff_screen "$baud"; then
    echo ""
    echo ">>> got data at ${baud} — use:"
    echo "    SERIAL_PORT=$PORT SERIAL_BAUD=$baud make serial-console"
    exit 0
  fi
done

echo ""
echo "No data at any baud."
echo "  • Swap TX ↔ RX, confirm GND"
echo "  • UART2 debug header on core board (ask Innohi)"
echo "  • make serial-miniterm after wiring UART2 debug header"
exit 1
