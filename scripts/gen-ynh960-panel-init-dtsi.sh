#!/usr/bin/env bash
# Generate panel-init-sequence DTSI from Innohi board/lcd_mipi_param.txt
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/board/lcd_mipi_param.txt"
OUT="$ROOT/overlay/kernel/rockchip/ynh960-panel-init.dtsi"

python3 - "$SRC" "$OUT" <<'PY'
import re
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])
text = src.read_text()
cmds = []
for line in text.splitlines():
    line = line.strip()
    if not line.startswith("0x"):
        continue
    vals = [int(x, 16) for x in re.findall(r"0x[0-9A-Fa-f]+", line)]
    if len(vals) < 3:
        continue
    plen = vals[2]
    if len(vals) != 3 + plen:
        raise SystemExit(f"bad line: {line!r} (expected {3 + plen} bytes, got {len(vals)})")
    cmds.append(vals)

total = sum(len(c) for c in cmds)
lines = [
    "// Generated from board/lcd_mipi_param.txt — do not edit; run scripts/gen-ynh960-panel-init-dtsi.sh",
    "",
    "&dsi0_panel {",
    f"\tpanel-init-sequence-size = <{total}>;",
    "\tpanel-init-sequence = [",
]
for cmd in cmds:
    hexes = " ".join(f"{b:02X}" for b in cmd)
    lines.append(f"\t\t{hexes}")
lines.extend(["\t];", "};", ""])

out.write_text("\n".join(lines) + "\n")
print(f"gen-ynh960-panel-init: {len(cmds)} commands, {total} bytes -> {out}")
PY
