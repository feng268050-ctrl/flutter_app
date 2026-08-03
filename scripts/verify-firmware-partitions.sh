#!/usr/bin/env bash
# Fail early if firmware images exceed GPT partition sizes in parameter.
# A/B: boot.img → boot, boot_b.img → boot_b; rootfs.img fits both rootfs slots.
#
# Usage: $0 <firmware-dir> [parameter.txt] [rootfs.img-path]
# Optional 3rd arg: APP-scoped rootfs when not present as firmware-dir/rootfs.img.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIRMWARE="${1:-}"
PARAM="${2:-$ROOT/board/parameter-buildroot-fit.txt}"
ROOTFS_OVERRIDE="${3:-}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -d "$FIRMWARE" ]] || die "usage: $0 <firmware-dir> [parameter.txt] [rootfs.img]"

python3 - "$FIRMWARE" "$PARAM" "$ROOTFS_OVERRIDE" <<'PY'
import re, sys
from pathlib import Path

firmware = Path(sys.argv[1])
param = Path(sys.argv[2]).read_text()
rootfs_override = Path(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else None
cmd = next(l for l in param.splitlines() if l.startswith("CMDLINE:"))
parts = []
for m in re.finditer(r"0x([0-9a-fA-F]+)@0x([0-9a-fA-F]+)\(([^)]+)\)", cmd):
    size, off, name = int(m.group(1), 16), int(m.group(2), 16), m.group(3)
    parts.append((name.split(":")[0], off, size * 512))

limits = {name: size for name, _off, size in parts}

# Vendor U-Boot requires PARTNAME "boot" (letter A); letter B is boot_b.
images = {
    "boot.img": ["boot"],
    "boot_b.img": ["boot_b"],
    "rootfs.img": ["rootfs_a", "rootfs_b", "rootfs"],
    "uboot.img": ["uboot"],
    "misc.img": ["misc"],
    "vbmeta.img": ["vbmeta"],
}

ok = True
for img, part_names in images.items():
    if img == "rootfs.img" and rootfs_override is not None and rootfs_override.is_file():
        path = rootfs_override.resolve()
    else:
        path = firmware / img
    if not path.is_file():
        continue
    need = path.stat().st_size
    matched = [p for p in part_names if p in limits]
    if not matched:
        print(f"WARN: no partition entry for {img} (tried {', '.join(part_names)})")
        continue
    for part in matched:
        cap = limits[part]
        status = "OK" if need <= cap else "TOO LARGE"
        label = img if path.name == img else f"{img} ({path})"
        print(f"{label:12} → {part:10}  {need/1024/1024:7.2f} MiB / {cap/1024/1024:7.2f} MiB  {status}")
        if need > cap:
            ok = False

for required in ("boot", "boot_b", "rootfs_a", "rootfs_b"):
    if required not in limits:
        print(f"FAIL: parameter missing {required}")
        ok = False

if "boot_a" in limits:
    print("FAIL: parameter still has boot_a — vendor U-Boot needs PARTNAME=boot (see docs/ab-slot-misc.md)")
    ok = False

sys.exit(0 if ok else 1)
PY
