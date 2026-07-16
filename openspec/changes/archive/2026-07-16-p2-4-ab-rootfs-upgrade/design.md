## Context

Today GPT has a **single `boot`** and **single `rootfs`**. Day-to-day system updates (including **kernel / DTS / FIT**) still require **`make flash`** (RockUSB). Prefs live on **userdata** and must survive remote upgrades. SSH target discovery already works for `push-app`.

P2.4 must make **`make upgrade` approach `make flash` for updatable runtime firmware**: at minimum **boot + rootfs**, optionally other non-bootloader partitions present in the package, with A/B rollback — while **never** repartitioning GPT or rewriting U-Boot/MiniLoader over SSH.

## Goals / Non-Goals

**Goals:**

- Paired A/B: **`boot`/`boot_b`** FIT storage + **`rootfs_a`/`rootfs_b`** (same letter always used together; vendor U-Boot always loads the partition named `boot`).
- Default **`make upgrade`** installs a **firmware bundle** ≥ `{boot.img, rootfs.img}` (+ digests); writes the **inactive letter** for both; arms try-boot; reboots; commits or rolls back.
- Update **as many flashable runtime parts as safe**: boot + rootfs required; **oem** (and similar vendor images) when included in the bundle; skip only what must stay flash-only.
- **userdata / P2.3 prefs untouched**.
- App-only developer iteration remains `make push-app`; `make upgrade` has no mode switch.
- One-time **`make flash`** after GPT change; thereafter kernel+rootfs iteration via upgrade.

**Non-Goals:**

- Remote update of **U-Boot / MiniLoader** (brick risk → `make flash` only).
- Remote **GPT / parameter** rewrite.
- Product OTA UI / cloud (P5.8).
- Wiping userdata on upgrade.

## Decisions

### 1. GPT layout (paired slots)

**Choice:**

| Part | Size (sectors) | Notes |
|------|----------------|-------|
| uboot, misc | unchanged | flash-only for uboot content |
| **boot, boot_b** | each `0x00020000` (64 MiB) | A/loading partition must remain named `boot` for vendor U-Boot |
| recovery, backup | keep single (current sizes) | not A/B in P2.4; optional write if later needed |
| **rootfs_a, rootfs_b** | each `0x00200000` (1 GiB) | replace single `rootfs` |
| oem, private*, userdata:grow | shifted after dual rootfs | userdata preserved across upgrade |

**Rationale:** Kernel FIT and rootfs (modules/userspace) must roll forward/back together.

### 2. What `make upgrade` updates vs `make flash`

| Component | `make upgrade` (full-system) | `make flash` |
|-----------|------------------------------|--------------|
| `boot.img` / `boot_b.img` (slot-specific kernel FITs) | **Yes** → target FIT staged into `boot`; previous FIT backed up to `boot_b` | Yes |
| `rootfs.img` | **Yes** → inactive `rootfs_*` | Yes |
| `oem` (if in bundle) | **Yes** → single oem partition (no A/B) | Yes |
| misc slot marker | Yes (board-managed) | Yes |
| uboot / MiniLoader | **No** | Yes |
| GPT / parameter | **No** | Yes |
| userdata / prefs | **Never wipe** | Factory reset (prefs clear policy) |
| recovery / backup | **Out of P2.4 default bundle** (may add later) | Yes if in `update.img` |

**Rationale:** “接近 flash” = all day-to-day runtime images; exclude bootloader + repartition.

### 3. Firmware bundle (not rootfs-only)

**Choice:** Host stages under `/userdata/ota/` a **manifest + images**, e.g.:

- `manifest.json` (or equivalent): version, slot policy, SHA-256 per image, required vs optional
- **Required:** `boot.img`, `rootfs.img`
- **Optional:** `oem.img` (or tar for `/oem`)

May be produced by `build-img` as a side artifact or assembled from `output/firmware/`. Full Rockchip `update.img` remains the flash vehicle; upgrade MAY extract boot/rootfs from it on the host if convenient, but board apply still writes **by partition**, not via `upgrade_tool uf`.

### 4. Slot marker and boot selection

**Choice:** Misc offset `0x100000` holds **active letter** (A|B), **try-boot letter**, **previous letter**, and try counter. The earlier `0x0800` candidate is vendor-owned boot-control data and is rewritten by ynh960 U-Boot. When the safe marker is absent, Linux initializes it from the rootfs block device actually mounted as `/`. Vendor U-Boot always loads PARTNAME `boot`; the board helper places the FIT for the selected letter there, and that FIT sets **`root=PARTLABEL=rootfs_${letter}`**.

**Alternatives:** Independent boot vs rootfs letters (rejected — module/ABI skew); single boot with dual rootfs only (rejected — cannot remote-update kernel safely).

### 5. Apply / commit / rollback

**Choice:**

1. Determine inactive letter.
2. Write + verify **inactive boot**, then **inactive rootfs** (and optional oem last).
3. Arm try-boot = inactive; previous = active.
4. Reboot.
5. Confirm oneshot: running boot+root match try-boot letter and health (HMI within timeout) → **commit**; else **revert** letter and reboot.

Fail any image verify → **do not arm** try-boot; leave active letter unchanged.

### 6. Factory `update.img`

**Choice:** Pack hash-valid slot-specific `boot.img` (`rootfs_a`) into **boot** and `boot_b.img` (`rootfs_b`) into **boot_b**, and the same `rootfs.img` into **rootfs_a and rootfs_b**. Default active = **A**.

### 7. Host `make upgrade`

**Choice:** `scripts/upgrade-remote.sh` + Makefile `upgrade`. Reuse `SERIAL=` / `IP=`. It always applies the full-system A/B bundle and **must not** call RockUSB `uf`. App-only iteration uses `make push-app`.

### 8. Prefs invariant

Unchanged: upgrade scripts refuse userdata `mkfs` / prefs tree deletion.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Dual boot eats ~64 MiB extra | Accept; document in storage-layout |
| Vendor U-Boot only loads PARTNAME `boot` | Keep A storage named `boot`; apply backs it up to `boot_b` and writes the target slot FIT into `boot`; rollback swaps it back |
| oem is single-slot (no rollback) | oem optional; prefer non-critical drop-ins |
| Larger transfer (boot+rootfs) over SSH | Resume-friendly copy; digests before arm |
| Mismatched partial write | Write both images before arming; single letter commit |

## Migration Plan

1. Land GPT + docs + verify for boot+rootfs A/B; build factory image.
2. **`make flash` once** (repartition).
3. Confirm boot from A (`boot` FIT + `rootfs_a`); `boot_b` and `rootfs_b` hold the B pair.
4. Land board apply/confirm + host upgrade.
5. Accept: change kernel and/or rootfs → `make upgrade` → other letter → HMI up → prefs intact; bad bundle rejected.
6. P5.8 reuses bundle + protocol.

## Open Questions

1. Exact misc layout vs Rockchip BCBC (spike).
2. Whether package-file can duplicate boot/rootfs into both letters natively or needs a build-img post-step.
3. Commit health: require `hmi.service` active (default) vs weaker multi-user only.
