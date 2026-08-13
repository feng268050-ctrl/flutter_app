#!/usr/bin/env python3
"""Patch Rockchip resource.img embedded DTB bootargs for A/B slot FITs.

ynh960 U-Boot applies root= from the DTB inside resource.img (not only fdt-*).
Slot B FITs must not ship resource.img still pointing at rootfs_a.

RSCE ENTR entries store a SHA-1 of each payload (rk-kernel.dtb, logo*.bmp).
A raw PARTLABEL replace changes the DTB bytes; the stored hash must be
refreshed or U-Boot rejects/skips the resource DTB (no drm-logo fill-in,
wrong early FDT path — B-only splash / jank / cold-boot panic). See
docs/ab-slot-misc.md «resource.img RSCE SHA-1».
"""
from __future__ import annotations

import hashlib
import struct
import sys
from pathlib import Path

ENTR = b"ENTR"
RSCE = b"RSCE"
HASH_OFF = 224
HASH_LEN = 20
HASH_SIZE_OFF = 256
BLK_OFF = 260
SIZE_OFF = 264
ENTRY_STRIDE = 512
ENTRY_COUNT_OFF = 12


def _entr_name(ent: bytes) -> str:
    return ent[4:260].split(b"\0", 1)[0].decode("ascii", "replace")


def _iter_entr(rsce: bytes):
    if rsce[:4] != RSCE:
        raise SystemExit("ERROR: not a Rockchip RSCE resource.img")
    count = struct.unpack_from("<I", rsce, ENTRY_COUNT_OFF)[0]
    if not (1 <= count <= 64):
        raise SystemExit(f"ERROR: bad RSCE entry_count={count}")
    for i in range(count):
        off = ENTRY_STRIDE * (i + 1)
        if off + ENTRY_STRIDE > len(rsce):
            raise SystemExit(f"ERROR: RSCE truncated at entry {i}")
        ent = rsce[off : off + ENTRY_STRIDE]
        if ent[:4] != ENTR:
            raise SystemExit(f"ERROR: missing ENTR at entry {i} offset {off}")
        yield off, ent


def _entr_payload(rsce: bytes, ent: bytes) -> bytes:
    hash_size = struct.unpack_from("<I", ent, HASH_SIZE_OFF)[0]
    if hash_size != HASH_LEN:
        raise SystemExit(f"ERROR: unsupported ENTR hash_size={hash_size}")
    blk = struct.unpack_from("<I", ent, BLK_OFF)[0]
    size = struct.unpack_from("<I", ent, SIZE_OFF)[0]
    start = blk * ENTRY_STRIDE
    if size <= 0 or start + size > len(rsce):
        raise SystemExit(
            f"ERROR: bad ENTR {_entr_name(ent)!r} blk={blk} size={size}"
        )
    return rsce[start : start + size]


def _refresh_entr_hashes(data: bytearray) -> int:
    """Recompute SHA-1 for every ENTR whose payload no longer matches."""
    updated = 0
    for off, ent in _iter_entr(data):
        digest = hashlib.sha1(_entr_payload(data, ent)).digest()
        stored = bytes(ent[HASH_OFF : HASH_OFF + HASH_LEN])
        if stored != digest:
            data[off + HASH_OFF : off + HASH_OFF + HASH_LEN] = digest
            updated += 1
            print(f"OK: refreshed SHA-1 for {_entr_name(ent)!r}")
    return updated


def assert_entr_hashes(rsce: bytes) -> None:
    for _off, ent in _iter_entr(rsce):
        digest = hashlib.sha1(_entr_payload(rsce, ent)).digest()
        stored = ent[HASH_OFF : HASH_OFF + HASH_LEN]
        if stored != digest:
            raise SystemExit(
                f"ERROR: ENTR SHA-1 mismatch for {_entr_name(ent)!r} "
                f"(stored={stored.hex()} calc={digest.hex()}) — "
                "PARTLABEL patch must refresh RSCE hashes; "
                "see docs/ab-slot-misc.md"
            )


def assert_partlabel(rsce: bytes, expect: str) -> None:
    if expect not in ("rootfs_a", "rootfs_b"):
        raise SystemExit(f"expect must be rootfs_a or rootfs_b, got {expect!r}")
    other = "rootfs_b" if expect == "rootfs_a" else "rootfs_a"
    want = f"PARTLABEL={expect}".encode("ascii")
    forbid = f"PARTLABEL={other}".encode("ascii")
    if forbid in rsce:
        raise SystemExit(f"ERROR: resource still has PARTLABEL={other}")
    if want not in rsce:
        raise SystemExit(f"ERROR: resource missing PARTLABEL={expect}")


def find_rsce_in_blob(blob: bytes) -> bytes:
    """Locate the Rockchip resource.img payload inside a FIT (or raw RSCE)."""
    if blob[:4] == RSCE:
        return blob
    idx = 0
    while True:
        j = blob.find(RSCE, idx)
        if j < 0:
            raise SystemExit("ERROR: no RSCE magic in image")
        # Header: magic, reserved, version-ish, entry_count
        if j + ENTRY_STRIDE <= len(blob):
            count = struct.unpack_from("<I", blob, j + ENTRY_COUNT_OFF)[0]
            if 1 <= count <= 64:
                max_end = j + ENTRY_STRIDE * (count + 1)
                ok = True
                for i in range(count):
                    ent_off = j + ENTRY_STRIDE * (i + 1)
                    if ent_off + ENTRY_STRIDE > len(blob):
                        ok = False
                        break
                    ent = blob[ent_off : ent_off + ENTRY_STRIDE]
                    if ent[:4] != ENTR:
                        ok = False
                        break
                    blk = struct.unpack_from("<I", ent, BLK_OFF)[0]
                    size = struct.unpack_from("<I", ent, SIZE_OFF)[0]
                    if size <= 0:
                        ok = False
                        break
                    max_end = max(max_end, j + blk * ENTRY_STRIDE + size)
                if ok and max_end <= len(blob):
                    return blob[j:max_end]
        idx = j + 4


def verify_resource(path: Path, expect: str | None = None) -> None:
    data = path.read_bytes()
    rsce = find_rsce_in_blob(data) if data[:4] != RSCE else data
    assert_entr_hashes(rsce)
    if expect:
        assert_partlabel(rsce, expect)
    label = expect or "any"
    print(f"OK: {path.name} RSCE ENTR SHA-1 valid (PARTLABEL expect={label})")


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
            assert_entr_hashes(data)
            print(f"OK: {path.name} already PARTLABEL={expect}")
            return
        raise SystemExit(f"ERROR: missing PARTLABEL={expect} in {path}")
    count = data.count(forbid)
    data = bytearray(data.replace(forbid, want))
    if forbid in data:
        raise SystemExit(f"ERROR: PARTLABEL={other} still present in {path}")
    refreshed = _refresh_entr_hashes(data)
    assert_entr_hashes(data)
    path.write_bytes(data)
    print(
        f"OK: {path.name} patched {count}x PARTLABEL={other} -> {expect} "
        f"(refreshed {refreshed} ENTR hash(es))"
    )


def _self_test() -> None:
    """Synthetic RSCE: PARTLABEL patch must leave ENTR SHA-1 consistent."""
    # Minimal: header + 1 ENTR pointing at sector 4 with a tiny "FDT-like" blob
    payload = bytearray(b"\xd0\x0d\xfe\xed" + b"\0" * 60)
    payload += b"PARTLABEL=rootfs_a"
    payload += b"\0" * (256 - len(payload))
    rsce = bytearray(ENTRY_STRIDE * 5)
    rsce[0:4] = RSCE
    struct.pack_into("<I", rsce, ENTRY_COUNT_OFF, 1)
    ent_off = ENTRY_STRIDE
    rsce[ent_off : ent_off + 4] = ENTR
    rsce[ent_off + 4 : ent_off + 4 + 13] = b"rk-kernel.dtb"
    struct.pack_into("<I", rsce, ent_off + HASH_SIZE_OFF, HASH_LEN)
    struct.pack_into("<I", rsce, ent_off + BLK_OFF, 4)
    struct.pack_into("<I", rsce, ent_off + SIZE_OFF, len(payload))
    start = 4 * ENTRY_STRIDE
    rsce[start : start + len(payload)] = payload
    digest = hashlib.sha1(payload).digest()
    rsce[ent_off + HASH_OFF : ent_off + HASH_OFF + HASH_LEN] = digest
    assert_entr_hashes(rsce)

    tmp = Path("/tmp/lws-rsce-selftest.img")
    tmp.write_bytes(rsce)
    # Simulate the old bug: replace without hash refresh → must fail verify
    broken = bytearray(rsce)
    broken[start : start + len(payload)] = payload.replace(
        b"PARTLABEL=rootfs_a", b"PARTLABEL=rootfs_b"
    )
    try:
        assert_entr_hashes(broken)
    except SystemExit:
        pass
    else:
        raise SystemExit("ERROR: self-test expected SHA-1 mismatch after raw replace")

    patch_resource_partlabel(tmp, "rootfs_b")
    verify_resource(tmp, "rootfs_b")
    tmp.unlink(missing_ok=True)
    print("OK: self-test passed")


def main() -> None:
    if len(sys.argv) >= 2 and sys.argv[1] == "--self-test":
        _self_test()
        return
    if len(sys.argv) >= 2 and sys.argv[1] == "--verify":
        if len(sys.argv) not in (3, 4):
            raise SystemExit(
                f"usage: {sys.argv[0]} --verify <resource.img|boot*.img> [rootfs_a|rootfs_b]"
            )
        expect = sys.argv[3] if len(sys.argv) == 4 else None
        verify_resource(Path(sys.argv[2]), expect)
        return
    if len(sys.argv) != 3:
        raise SystemExit(
            f"usage: {sys.argv[0]} <resource.img> <rootfs_a|rootfs_b>\n"
            f"       {sys.argv[0]} --verify <resource.img|boot*.img> [rootfs_a|rootfs_b]\n"
            f"       {sys.argv[0]} --self-test"
        )
    patch_resource_partlabel(Path(sys.argv[1]), sys.argv[2])


if __name__ == "__main__":
    main()
