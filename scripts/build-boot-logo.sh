#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv-tools"

run_python() {
  exec python3 "$ROOT/scripts/build-boot-logo.py" "$@"
}

if python3 -c "from PIL import Image" 2>/dev/null; then
  run_python
fi

if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
  run_python
fi

if [[ -x "$VENV/bin/python" ]] && "$VENV/bin/python" -c "from PIL import Image" 2>/dev/null; then
  exec "$VENV/bin/python" "$ROOT/scripts/build-boot-logo.py" "$@"
fi

if [[ -f "$ROOT/board/logo/logo.bmp" && -f "$ROOT/board/logo/logo_kernel.bmp" ]]; then
  echo "boot logo: using existing board/logo/logo.bmp (no Pillow/ImageMagick in PATH)"
  exit 0
fi

python3 -m venv "$VENV"
"$VENV/bin/pip" install -q pillow
exec "$VENV/bin/python" "$ROOT/scripts/build-boot-logo.py" "$@"
