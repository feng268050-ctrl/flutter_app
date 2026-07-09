#!/usr/bin/env bash
# Fail early if firmware images exceed Android-GPT partition sizes in parameter.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRMWARE="${1:-}"
PARAM="${2:-$ROOT/board/parameter-buildroot-fit.txt}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -d "$FIRMWARE" ]] || die "usage: $0 <firmware-dir> [parameter.txt]"

python3 - "$FIRMWARE" "$PARAM" <<'PY'
import re, sys
from pathlib import Path

firmware = Path(sys.argv[1])
param = Path(sys.argv[2]).read_text()
cmd = next(l for l in param.splitlines() if l.startswith("CMDLINE:"))
parts = []
for m in re.finditer(r"0x([0-9a-fA-F]+)@0x([0-9a-fA-F]+)\(([^)]+)\)", cmd):
    size, off, name = int(m.group(1), 16), int(m.group(2), 16), m.group(3)
    parts.append((name.split(":")[0], off, size * 512))

# Map package-file names to partition names
images = {
    "boot.img": "boot",
    "rootfs.img": "rootfs",
    "uboot.img": "uboot",
    "misc.img": "misc",
    "vbmeta.img": "vbmeta",
}
limits = {name: size for name, _off, size in parts}

ok = True
for img, part in images.items():
    path = firmware / img
    if not path.is_file():
        continue
    need = path.stat().st_size
    cap = limits.get(part)
    if cap is None:
        print(f"WARN: no partition entry for {part} ({img})")
        continue
    status = "OK" if need <= cap else "TOO LARGE"
    print(f"{img:12} → {part:8}  {need/1024/1024:7.2f} MiB / {cap/1024/1024:7.2f} MiB  {status}")
    if need > cap:
        ok = False

sys.exit(0 if ok else 1)
PY
