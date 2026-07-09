#!/usr/bin/env bash
# Project venv with pyserial (macOS Homebrew Python blocks --user pip).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.cache/serial-venv"

if [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" -c 'import serial' 2>/dev/null; then
  echo "$VENV/bin/python"
  exit 0
fi

echo "Creating $VENV and installing pyserial ..."
mkdir -p "$ROOT/.cache"
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q pyserial
echo "$VENV/bin/python"
