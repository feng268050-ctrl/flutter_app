#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv-tools"

run_build() {
  if python3 -c "from PIL import Image" 2>/dev/null; then
    python3 "$ROOT/scripts/build-boot-logo.py" "$@"
    return
  fi

  if [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" -c "from PIL import Image" 2>/dev/null; then
    "$VENV/bin/python" "$ROOT/scripts/build-boot-logo.py" "$@"
    return
  fi

  if [[ -f "$ROOT/board/logo/logo.bmp" && -f "$ROOT/board/logo/logo_kernel.bmp" ]]; then
    echo "boot logo: using existing board/logo/logo.bmp (no Pillow in PATH)"
    return 0
  fi

  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q pillow
  "$VENV/bin/python" "$ROOT/scripts/build-boot-logo.py" "$@"
}

run_build "$@"
