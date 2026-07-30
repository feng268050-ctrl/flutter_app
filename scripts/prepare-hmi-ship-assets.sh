#!/usr/bin/env bash
# Stage pruned Flutter ship assets under app/lws_hmi/assets/.generated/
# (process-library JSON+manifest, control-board firmware newest-per-HW).
#
# Sources (git, multi-version OK):
#   assets/process-library/<model>/<version>.xlsx
#   assets/firmware/control-board/LSW01H####S####.bin
#
# Invoked by make prepare-app-assets / build-app / build-debug-app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app/lws_hmi"
GEN="$APP_DIR/assets/.generated"
PROC_SRC="$APP_DIR/assets/process-library"
FW_SRC="$APP_DIR/assets/firmware/control-board"
PROC_OUT="$GEN/process-library"
FW_OUT="$GEN/firmware/control-board"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

echo "==> prepare HMI ship assets → $GEN"

# Drop legacy plural ship dir if present.
rm -rf "$GEN/process-libraries" "$PROC_OUT" "$FW_OUT"
mkdir -p "$PROC_OUT" "$FW_OUT"
# Preserve gitkeep parents if present.
mkdir -p "$GEN/process-library" "$GEN/firmware/control-board"
touch "$GEN/process-library/.gitkeep" "$GEN/firmware/control-board/.gitkeep"

[[ -d "$PROC_SRC" ]] || die "missing process-library source: $PROC_SRC"
# Source tree must be model dirs + README only (no checked-in JSON/manifest).
if [[ -f "$PROC_SRC/manifest.json" ]]; then
	die "refusing checked-in $PROC_SRC/manifest.json (ship-only; run prepare)"
fi

python3 "$ROOT/scripts/convert-process-library.py" \
	--ship-from "$PROC_SRC" \
	--output-dir "$PROC_OUT" \
	--asset-key-prefix "assets/.generated/process-library"

# Newest SW per HW from source firmware tree.
export FW_SRC FW_OUT
python3 - <<'PY'
import os, re, shutil
from pathlib import Path

src = Path(os.environ["FW_SRC"])
out = Path(os.environ["FW_OUT"])
pat = re.compile(r"^LSW01H(?P<hw>\d{4})S(?P<sw>\d{4})\.bin$", re.I)
best: dict[int, tuple[int, Path]] = {}
unexpected = []
for p in sorted(src.iterdir()):
    if not p.is_file():
        continue
    if p.name in ("README.md", ".DS_Store") or p.name.startswith("."):
        continue
    m = pat.match(p.name)
    if not m:
        if p.suffix.lower() == ".bin":
            unexpected.append(p.name)
        continue
    hw = int(m.group("hw"))
    sw = int(m.group("sw"))
    prev = best.get(hw)
    if prev is None or sw > prev[0]:
        best[hw] = (sw, p)

if unexpected:
    raise SystemExit(f"invalid control-board bin names: {', '.join(unexpected)}")
if not best:
    raise SystemExit(f"no LSW01H*.bin under {src}")

out.mkdir(parents=True, exist_ok=True)
for hw, (sw, path) in sorted(best.items()):
    dest = out / path.name
    shutil.copy2(path, dest)
    print(f"ship firmware HW={hw} SW={sw}: {path.name}")
PY

echo "OK: ship assets ready"
ls -la "$PROC_OUT" "$FW_OUT"
