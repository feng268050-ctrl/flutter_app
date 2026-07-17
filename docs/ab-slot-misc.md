# A/B slot marker (misc) — P2.4

## Partition naming (vendor U-Boot constraint)

ynh960 **vendor** `uboot.img` `boot_fit` / `boot_android` look for a GPT partition literally named **`boot`**. Naming the A slot `boot_a` causes:

```text
FIT: No boot partition
Can't find part: boot
```

| Letter | Boot PARTNAME | Rootfs PARTNAME |
|--------|---------------|-----------------|
| **A** | `boot` | `rootfs_a` |
| **B** | `boot_b` (storage) | `rootfs_b` |

**Try-boot (apply):** backup running FIT `boot` → `boot_b`, write new try FIT → `boot`, reboot. U-Boot always loads `boot`; running kernel/rootfs are unaffected until reboot. **Rollback (confirm):** swap `boot` ↔ `boot_b` to restore previous FIT. Rootfs letter is selected via FIT `root=PARTLABEL=rootfs_{a|b}` (inactive `rootfs_*` is written during apply; no rootfs swap).

Slot letter marker lives on **`misc`** (never userdata).

## Layout (512-byte sectors; misc is 4 MiB)

| Region | Offset | Size | Purpose |
|--------|--------|------|---------|
| Android recovery BCB | `0x0000` | 2 KiB | **Must stay zero** — non-empty recovery commands break Linux boot on this product |
| Vendor boot-control data | `0x0800` (2 KiB) | vendor-owned | Rewritten by ynh960 U-Boot during boot; **must not be used by LWS-HMI** |
| LWS-HMI AB block | `0x100000` (1 MiB) | 64 bytes | Active / try-boot / previous letter + try counter |
| Reserved | rest of misc | — | Unused by P2.4 |

## LWS-HMI AB block (`0x100000`)

Little-endian fields:

| Offset | Type | Field |
|--------|------|-------|
| 0 | 8 bytes | Magic `LWSAB\0\1\0` (bytes `4C 57 53 41 42 00 01 00`) |
| 8 | u8 | `active` — ASCII `A` or `B` |
| 9 | u8 | `try_boot` — `A`/`B`, or `0` if not armed |
| 10 | u8 | `previous` — `A` or `B` (rollback target) |
| 11 | u8 | `tries_remaining` — decremented on try-boot; `0` → revert |
| 12 | u32 | `crc32` — CRC-32/IEEE of bytes `[0..11]` (poly `0xEDB88320`) |
| 16–63 | — | Reserved zero |

**Factory default:** `active=A`, `try_boot=0`, `previous=A`, `tries_remaining=0`.

Board helpers: `/usr/libexec/hmi/ab-slot-*.sh` (read/write this block via `PARTLABEL=misc`; **pure shell**, no python on rootfs).

If the marker is absent at `0x100000` (including migration from the retired, vendor-owned `0x0800` location), the board helper initializes `active` from the block device actually mounted as `/`. It never assumes A when deciding which rootfs partition is safe to overwrite.

## U-Boot spike (confirmed on device)

Serial after flashing `boot_a`/`boot_b`:

- SPL: `A/B-slot: _a` (loader path OK)
- U-Boot: `FIT: No boot partition` / `Can't find part: boot`

**Do not** binary-patch vendor uboot env (CRC → brick). Do **not** rename A slot to `boot_a` without an Innohi-approved U-Boot that resolves `boot_${slot}`.

Escalate `make build-uboot` only if product later requires true `boot_a`/`boot_b` names without content swap.

## Safety

- Upgrade helpers **must not** write Android `boot-recovery` strings at misc offset 0 or vendor boot-control data at `0x0800`
- Upgrade helpers **must not** wipe userdata or `/userdata/lws-hmi`
- Upgrade helpers **must not** rewrite the `uboot` partition
- The block device actually mounted as `/` (resolved from `/proc/self/mountinfo` → sysfs `PARTNAME`) is authoritative. Apply must refuse if it cannot identify `rootfs_a`/`rootfs_b`, if misc `active` disagrees with the mounted root, or if a try-boot is still pending.
- Immediately before `dd`, apply must compare resolved block devices and refuse to overwrite the device mounted as `/`, regardless of misc metadata.
