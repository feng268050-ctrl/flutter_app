#!/usr/bin/env bash
# Print repo-relative path to latest control-card firmware under firmware/, or empty line.
# Selection: max software version (S####), tie-break by hardware (H####). Same rules as bundleFirmwareAssets.
set -euo pipefail
cd "$(dirname "$0")/../.."
python3 - <<'PY'
import glob
import re

pat = re.compile(r"^LSW01H(?P<hw>\d{4})S(?P<sw>\d{4})\.bin$", re.I)
best = None  # (sw, hw, path)
for p in sorted(glob.glob("firmware/LSW01H????S????.bin")):
    name = p.split("/")[-1]
    m = pat.match(name)
    if not m:
        continue
    hw = int(m.group("hw"))
    sw = int(m.group("sw"))
    cand = (sw, hw, p)
    if best is None or (cand[0], cand[1]) > (best[0], best[1]):
        best = cand
print("" if best is None else best[2])
PY
