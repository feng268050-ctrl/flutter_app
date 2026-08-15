## Context

ynh960 ships `prebuilt/bootloader/rockchip-ynh960/` as symlinks to `prebuilt/sdk-loader/MiniLoaderAll.bin` and `prebuilt/sdk-uboot/uboot.img`. The loader blob is already an SPL+DDR merger (staged by `build-img` as `rk356x_spl_loader_v1.23.114.bin`), but the **MiniLoader** name implies the legacy FlashBoot=`*_miniloader_*` path. Vendor `uboot.img` embeds BL31 **v1.44** / BL32 **v2.15** and historically preferred Android boot commands; `patch-uboot-bootcmd.sh` already rewrites Rockchip `RKIMG_BOOTCOMMAND` for source builds, but shipping still uses prebuilt vendor uboot.

Public rkbin `RK3566MINIALL.ini` uses SPL; `RK3568TRUST.ini` in the local SDK pins BL31/BL32 to match the shipping FIT. Operators can recover ynh960 via eMMC short / Maskrom.

## Goals / Non-Goals

**Goals:**
- Deliver self-built SPL **`loader.bin`** (honest name) + self-built Linux-first **`uboot.img`** for `rockchip-ynh960`.
- Keep OP-TEE contract: TRUST **BL31 v1.44 / BL32 v2.15** inside uboot FIT.
- Backup current pair for one-command / documented rollback.
- Update packaging so `build-img` / flash / Maskrom `ul` work with `loader.bin`.

**Non-Goals:**
- ek3562 bring-up (change `ek3562-board-bringup`).
- Upgrading BL32 to rkbin master v2.16.
- Changing GPT / A/B letter naming (`boot` + `boot_b` stays).

## Decisions

### D1 — Canonical filename `loader.bin`

- **Choice:** Primary file under `prebuilt/bootloader/<uboot_id>/loader.bin`. Keep transitional acceptance of `MiniLoaderAll.bin` symlink or copy during one release if tools hardcode the old name; prefer updating scripts to prefer `loader.bin` then fall back.
- **Why:** Avoid “miniloader architecture” confusion while matching Rockchip SPL packaging.
- **Alt:** Keep only `rk356x_spl_loader_vX.Y.Z.bin` — rejected as versioned names churn SKU tables.

### D2 — SPL from rkbin `boot_merger`, not Innohi opaque blob

- **Choice:** Clone/update rkbin; run `./tools/boot_merger RKBOOT/RK3566MINIALL.ini` (or ULTRA / DDR-matched variant after measuring board DRAM). Install output as `loader.bin`.
- **Why:** Same path as ek3562; reproducible.
- **Alt:** Keep shipping binary forever — rejected for this change’s purpose.

### D3 — U-Boot from rockchip-linux/u-boot + existing bootcmd patch

- **Choice:** `make fetch-uboot`; apply/extend `patch-uboot-bootcmd.sh` so `#else` `RKIMG_BOOTCOMMAND` is **only** `run rkimg_bootdev; boot_fit; run distro_bootcmd;` (no `boot_android`, no android FIT try). If upstream layout drifts, add an overlay patch under `overlay/` that forks the define. Pack uboot.img with SDK `RK3568TRUST.ini` pins (**v1.44 / v2.15**), not github master TRUST.
- **Why:** Patch already exists; self-build makes it actually ship.
- **Alt:** Binary-edit vendor uboot env — forbidden (CRC / brick).

### D4 — Backup before replace

- **Choice:** Copy current resolved loader + uboot into `prebuilt/bootloader/rockchip-ynh960/backup/<stamp>/` (or `prebuilt/bootloader-backup/rockchip-ynh960/<stamp>/`) with a short README (git rev, DDR string, bl31/bl32 strings).
- **Why:** Fast rollback via restore + `make build-img` / flash without hunting LFS history.

### D5 — Validation order

- **Choice:** Validate on ynh960 with serial + Maskrom/eMMC recovery before ek3562 change applies bootloader flash as primary path.
- **Why:** Known unbrick; user requirement.

## Risks / Trade-offs

- [Wrong DDR ini] → Mitigation: confirm DRAM from schematic / working board `ddr-v*` string; start from ini matching current `ddr-v1.23` lineage if possible.
- [Self-built uboot breaks backlight / boot_fit] → Mitigation: serial console; restore backup; do not binary-patch.
- [Script still requires MiniLoaderAll.bin] → Mitigation: update `build-img.sh` / flash helpers in same change.
- [OP-TEE break if TRUST bumped] → Mitigation: pin v1.44/v2.15 in design + tasks; verify `bl32-v2.15` string in new uboot.img.

## Migration Plan

1. Backup existing pair.
2. Build loader + uboot; install under `rockchip-ynh960/`.
3. Update packaging docs/scripts for `loader.bin`.
4. `FACTORY_SKU=ynh960-p800 make build-img` → flash one lab unit; serial boot to Linux HMI; verify `/dev/tee0` + seal smoke.
5. On failure: restore backup files; reflash.
6. Only then proceed to `ek3562-board-bringup` bootloader flash validation.

## Open Questions

- Exact `RK3566MINIALL*.ini` variant for production ynh960 DRAM (1056 vs other) — resolve during apply with board measurement.
- Whether factory/`upgrade_tool` on all host OSes accept `loader.bin` without a `MiniLoaderAll.bin` alias — resolve in tasks with a compatibility symlink if needed.
