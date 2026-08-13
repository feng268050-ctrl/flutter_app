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

**Try-boot (apply):** backup running FIT `boot` → `boot_b`, write new try FIT → `boot`, reboot. U-Boot always loads `boot`; running kernel/rootfs are unaffected until reboot. **Rollback (confirm):** swap `boot` ↔ `boot_b` to restore previous FIT. Inactive `rootfs_*` is written during apply; no rootfs partition swap.

**Rootfs LABEL/UUID:** `rootfs_a` and `rootfs_b` MUST NOT share ext4 `LABEL` or `UUID` (udev `by-label` / `by-uuid` hygiene). Boot itself uses **`root=PARTLABEL=`**, so collisions do not change which slot mounts. Stamp at **write time** only — never a boot service (KPI): OTA via `ab-rootfs-identity.sh` after `dd`; RockUSB / factory via host `scripts/stamp-rootfs-ext4-identity.sh` (`flash-usb.sh`, `build-img` → `rootfs_a.img` / `rootfs_b.img`). Manual repair: `ab-rootfs-identity.sh ensure` over SSH.

Slot letter marker lives on **`misc`** (never userdata).

## resource.img PARTLABEL + RSCE SHA-1 (required for true slot B)

ynh960 U-Boot takes `root=` from the **DTB inside `resource.img`**, not only from FIT `fdt-*`. `scripts/build-kernel-ab.sh` therefore stages a per-slot `resource.img` via `scripts/patch-resource-img-partlabel.py`:

| FIT artifact | `resource.img` / FDT `root=` |
|--------------|------------------------------|
| `boot.img` | `PARTLABEL=rootfs_a` |
| `boot_b.img` | `PARTLABEL=rootfs_b` |

Rockchip `resource.img` is an **RSCE** container. Each `ENTR` (e.g. `rk-kernel.dtb`, `logo.bmp`) stores a **SHA-1** of that file’s bytes. Changing PARTLABEL inside the embedded DTB **changes those bytes**, so the ENTR hash **must be refreshed** in the same patch.

| Gate | Where |
|------|--------|
| Patch refreshes SHA-1 | `scripts/patch-resource-img-partlabel.py` |
| Self-test | `python3 scripts/patch-resource-img-partlabel.py --self-test` |
| Per-FIT after pack | `build-kernel-ab.sh` → `--verify <fit> rootfs_{a\|b}` |
| Host verify | `scripts/verify-boot-fit.sh` on `boot.img` / `boot_b.img` |

Do **not** binary-replace `PARTLABEL=rootfs_a`→`rootfs_b` in `resource.img` (or in a packed FIT) without going through that script. A stale ENTR hash is a silent, B-only failure mode (see pitfalls below).

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

Board helpers: `/usr/libexec/ab/ab-slot-*.sh` (read/write this block via `PARTLABEL=misc`; **pure shell**, no python on rootfs).

If the marker is absent at `0x100000` (including migration from the retired, vendor-owned `0x0800` location), the board helper initializes `active` from the block device actually mounted as `/`. It never assumes A when deciding which rootfs partition is safe to overwrite.

## U-Boot spike (confirmed on device)

Serial after flashing `boot_a`/`boot_b`:

- SPL: `A/B-slot: _a` (loader path OK)
- U-Boot: `FIT: No boot partition` / `Can't find part: boot`

**Do not** binary-patch vendor uboot env (CRC → brick). Do **not** rename A slot to `boot_a` without an Innohi-approved U-Boot that resolves `boot_${slot}`.

Escalate `make build-uboot` only if product later requires true `boot_a`/`boot_b` names without content swap.

## Pitfalls (field lessons)

### 1. Stale RSCE SHA-1 after PARTLABEL patch (B-only)

**Symptom (true `rootfs_b` only):** no kernel boot splash; UI stutter / frame drops; after soft poweroff, cold boot dies early.

**Serial fingerprint:**

```text
OF: fdt: Reserved memory: failed to reserve memory for node 'drm-logo@0': base 0x0, size 0 MiB
rockchip-pm-domain ... failed to get ack on domain 'npu' ...
Kernel panic - not syncing: panic_on_set_idle set ...
```

**Cause:** `resource.img` DTB bytes changed to `PARTLABEL=rootfs_b` but the `rk-kernel.dtb` ENTR SHA-1 still matched the unpatched (A) blob. U-Boot skipped / mishandled resource DTB + logo setup (`drm-logo@0` left at 0). Slot A was fine because its resource was never rewritten.

**Fix / prevention:** always use `patch-resource-img-partlabel.py` (refreshes hashes). Build gates above fail the pack if hashes drift. Manual check:

```bash
python3 scripts/patch-resource-img-partlabel.py --verify output/firmware/boot.img rootfs_a
python3 scripts/patch-resource-img-partlabel.py --verify output/firmware/boot_b.img rootfs_b
```

### 2. “Fake B” — misc says B but kernel still has `rootfs_a`

**Symptom:** misc `active=B`, but UI / splash look like A (smooth, splash present).

**Cause:** U-Boot **always** loads GPT `PARTNAME=boot`. Writing misc to B does **not** load `boot_b`. RockUSB `di` of `boot.img`→`boot` and `boot_b.img`→`boot_b` leaves A’s FIT in `boot` until try-boot / `ab_swap_boot_partitions`.

**Check:**

```text
grep PARTLABEL= /proc/cmdline    # must be rootfs_b for true B
. /usr/libexec/ab/ab-slot-lib.sh; ab_slot_read
```

**True B after both FITs are already on eMMC:** `ab_swap_boot_partitions` then `ab_slot_write B 0 A 0` and reboot (or run a normal SSH OTA try-boot onto the inactive letter).

### 3. Do not blame rootfs / present-hook first for B-only jank

When **only** true B is broken and A is fine with the same rootfs bytes, suspect FIT/`resource.img` first (PARTLABEL + RSCE hash), not Flutter eLinux present-hook or app drift.

## Safety

- Upgrade helpers **must not** write Android `boot-recovery` strings at misc offset 0 or vendor boot-control data at `0x0800`
- Upgrade helpers **must not** wipe userdata or `/userdata/lws-hmi`
- Upgrade helpers **must not** rewrite the `uboot` partition
- The block device actually mounted as `/` (resolved from `/proc/self/mountinfo` → sysfs `PARTNAME`) is authoritative. Apply must refuse if it cannot identify `rootfs_a`/`rootfs_b`, if misc `active` disagrees with the mounted root, or if a try-boot is still pending.
- Immediately before `dd`, apply must compare resolved block devices and refuse to overwrite the device mounted as `/`, regardless of misc metadata.
