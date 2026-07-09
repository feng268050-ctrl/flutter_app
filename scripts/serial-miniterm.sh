#!/usr/bin/env bash
# miniterm wrapper — works in Cursor terminal (quit: Ctrl+]).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${SERIAL_PORT:-}"
BAUD="${SERIAL_BAUD:-1500000}"
PY="$("$ROOT/scripts/ensure-serial-venv.sh")"

pick_port() {
  local p
  for p in /dev/cu.usbmodem* /dev/cu.usbserial* /dev/cu.wchusbserial* /dev/cu.SLAB_USBtoUART*; do
    [[ -e "$p" ]] || continue
    echo "$p"
    return 0
  done
  return 1
}

[[ -n "$PORT" ]] || PORT="$(pick_port)" || {
  echo "ERROR: set SERIAL_PORT=/dev/cu...." >&2
  exit 1
}

if lsof "$PORT" >/dev/null 2>&1; then
  echo "ERROR: $PORT busy — run: pkill -f 'screen $PORT'" >&2
  lsof "$PORT" 2>/dev/null | sed 's/^/  /'
  exit 1
fi

echo "miniterm $PORT @ $BAUD  (quit: Ctrl+])"
exec "$PY" -m serial.tools.miniterm "$PORT" "$BAUD"
