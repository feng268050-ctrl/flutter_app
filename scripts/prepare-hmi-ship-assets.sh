#!/usr/bin/env bash
# Stage pruned Flutter ship assets under app/lws_hmi/assets/.generated/
# (process-library JSON+manifest, control-board newest-per-HW,
# camera firmware newest-per-model).
#
# Sources (git, multi-version OK):
#   assets/process-library/<model>/<version>.xlsx
#   assets/firmware/control-board/LSW01H####S####.bin
#   assets/firmware/camera/{MODEL}-v{SEMVER} build{YYYYMMDD}.zip
#
# Invoked by make prepare-app-assets / build-app / build-debug-app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Prefer APP_DIR from app-select / build-app; default product HMI.
APP_DIR="${APP_DIR:-$ROOT/app/lws_hmi}"
GEN="$APP_DIR/assets/.generated"
PROC_SRC="$APP_DIR/assets/process-library"
FW_SRC="$APP_DIR/assets/firmware/control-board"
CAM_FW_SRC="$APP_DIR/assets/firmware/camera"
PROC_OUT="$GEN/process-library"
FW_OUT="$GEN/firmware/control-board"
CAM_FW_OUT="$GEN/firmware/camera"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

echo "==> prepare HMI ship assets → $GEN"

# Drop legacy plural ship dir if present.
rm -rf "$GEN/process-libraries" "$PROC_OUT" "$FW_OUT" "$CAM_FW_OUT"
mkdir -p "$PROC_OUT" "$FW_OUT" "$CAM_FW_OUT"
# Preserve gitkeep parents if present.
mkdir -p "$GEN/process-library" "$GEN/firmware/control-board" "$GEN/firmware/camera"
touch "$GEN/process-library/.gitkeep" "$GEN/firmware/control-board/.gitkeep" "$GEN/firmware/camera/.gitkeep"

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

# Newest SemVer+build per MODEL from source camera firmware tree.
export CAM_FW_SRC CAM_FW_OUT
python3 - <<'PY'
import os, re, shutil
from pathlib import Path

src = Path(os.environ["CAM_FW_SRC"])
out = Path(os.environ["CAM_FW_OUT"])
pat = re.compile(
    r"^(?P<model>[A-Za-z0-9]+)-v(?P<maj>\d+)\.(?P<min>\d+)\.(?P<patch>\d+) "
    r"build(?P<build>\d{8})\.zip$",
    re.I,
)
# model_key -> (semver_tuple, build, path)
best: dict[str, tuple[tuple[int, int, int], int, Path]] = {}
unexpected = []
if not src.is_dir():
    raise SystemExit(f"missing camera firmware source: {src}")
for p in sorted(src.iterdir()):
    if not p.is_file():
        continue
    if p.name in ("README.md", ".DS_Store") or p.name.startswith("."):
        continue
    m = pat.match(p.name)
    if not m:
        if p.suffix.lower() == ".zip":
            unexpected.append(p.name)
        continue
    model = m.group("model").upper()
    sem = (int(m.group("maj")), int(m.group("min")), int(m.group("patch")))
    build = int(m.group("build"))
    prev = best.get(model)
    if prev is None or (sem, build) > (prev[0], prev[1]):
        best[model] = (sem, build, p)

if unexpected:
    raise SystemExit(f"invalid camera firmware zip names: {', '.join(unexpected)}")
if not best:
    raise SystemExit(f"no camera *.zip under {src}")

out.mkdir(parents=True, exist_ok=True)
for model, (sem, build, path) in sorted(best.items()):
    dest = out / path.name
    shutil.copy2(path, dest)
    print(
        f"ship camera firmware MODEL={model} "
        f"v{sem[0]}.{sem[1]}.{sem[2]} build{build}: {path.name}"
    )
PY

# Flutter 3.24 packs only direct files under each pubspec asset directory
# entry (not recursive). Rewrite model-subdir lines between markers.
PUBSPEC="$APP_DIR/pubspec.yaml"
MARKER_BEGIN='# BEGIN generated-ship-assets'
MARKER_END='# END generated-ship-assets'
[[ -f "$PUBSPEC" ]] || die "missing $PUBSPEC"
grep -qF "$MARKER_BEGIN" "$PUBSPEC" || die "missing $MARKER_BEGIN in pubspec.yaml"
grep -qF "$MARKER_END" "$PUBSPEC" || die "missing $MARKER_END in pubspec.yaml"

PROC_ASSET_LINES=$'    - assets/.generated/firmware/control-board/\n    - assets/.generated/firmware/camera/\n    - assets/.generated/process-library/'
while IFS= read -r model_dir; do
	[[ -n "$model_dir" ]] || continue
	PROC_ASSET_LINES+=$'\n'"    - assets/.generated/process-library/${model_dir}/"
done < <(
	find "$PROC_OUT" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | LC_ALL=C sort
)

export PUBSPEC MARKER_BEGIN MARKER_END PROC_ASSET_LINES
python3 - <<'PY'
import os
from pathlib import Path

pubspec = Path(os.environ["PUBSPEC"])
begin = os.environ["MARKER_BEGIN"]
end = os.environ["MARKER_END"]
body = os.environ["PROC_ASSET_LINES"].rstrip("\n")
text = pubspec.read_text()
i = text.find(begin)
j = text.find(end)
if i < 0 or j < 0 or j < i:
    raise SystemExit(f"markers not found in {pubspec}")
i_line = text.rfind("\n", 0, i) + 1
j_line = text.find("\n", j)
if j_line < 0:
    j_line = len(text)
else:
    j_line += 1
replacement = f"    {begin}\n{body}\n    {end}\n"
pubspec.write_text(text[:i_line] + replacement + text[j_line:])
print(f"updated pubspec ship assets:\n{body}")
PY

echo "OK: ship assets ready"
ls -la "$PROC_OUT" "$FW_OUT" "$CAM_FW_OUT"
