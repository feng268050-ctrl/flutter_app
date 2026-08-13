#!/usr/bin/env python3
"""Patch Rockchip resource.img embedded DTB bootargs for A/B slot FITs.

ynh960 U-Boot applies root= from the DTB inside resource.img (not only fdt-*).
Slot B FITs must not ship resource.img still pointing at rootfs_a.
"""
from __future__ import annotations

import sys
from pathlib import Path


def patch_resource_partlabel(path: Path, expect: str) -> None:
    if expect not in ("rootfs_a", "rootfs_b"):
        raise SystemExit(f"expect must be rootfs_a or rootfs_b, got {expect!r}")
    other = "rootfs_b" if expect == "rootfs_a" else "rootfs_a"
    data = bytearray(path.read_bytes())
    want = f"PARTLABEL={expect}".encode("ascii")
    forbid = f"PARTLABEL={other}".encode("ascii")
    if want not in data and forbid not in data:
        raise SystemExit(f"ERROR: no PARTLABEL=rootfs_* in {path}")
    if forbid not in data:
        if want in data:
            print(f"OK: {path.name} already PARTLABEL={expect}")
            return
        raise SystemExit(f"ERROR: missing PARTLABEL={expect} in {path}")
    count = data.count(forbid)
    data = data.replace(forbid, want)
    if forbid in data:
        raise SystemExit(f"ERROR: PARTLABEL={other} still present in {path}")
    path.write_bytes(data)
    print(f"OK: {path.name} patched {count}x PARTLABEL={other} -> {expect}")


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit(f"usage: {sys.argv[0]} <resource.img> <rootfs_a|rootfs_b>")
    patch_resource_partlabel(Path(sys.argv[1]), sys.argv[2])


if __name__ == "__main__":
    main()
