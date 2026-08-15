## Why

ynh960 still ships a Rockchip/Innohi-era `MiniLoaderAll.bin` filename and a vendor `uboot.img` whose stock `RKIMG_BOOTCOMMAND` tries Android (`boot_android` / android FIT) before Linux `boot_fit`. That naming and boot order confuse operators, block a clean self-build path, and are the wrong default for a Linux-only product. Public rkbin already builds RK3566 eMMC loaders as **SPL** mergers whose **OUTPUT PATH** is `rk356x_spl_loader_v*.bin`; we should ship that upstream name, self-build, and ship a Linux-first U-Boot — with a recoverable backup — before repeating the same pattern on ek3562.

## What Changes

- Replace the delivered early-loader artifact name from **`MiniLoaderAll.bin`** (authoritative) with the **rkbin `boot_merger` OUTPUT name** **`rk356x_spl_loader_v*.bin`** (exact version pinned in the package README). Do **not** invent repo-local aliases such as `loader.bin` or `bootloader.bin` as the authoritative filename.
- Self-build that SPL loader via rkbin `boot_merger` + DDR-matched `RK3566MINIALL*.ini`.
- Self-build **`uboot.img`** from rockchip-linux/u-boot with **Linux-first** bootcmd (no Android try-chain before `boot_fit`), packing TRUST **BL31 v1.44 / BL32 v2.15** to match the current OP-TEE / seal contract.
- **Backup** today’s validated `MiniLoaderAll.bin` + `uboot.img` under a dated rollback directory before replacing `prebuilt/bootloader/rockchip-ynh960/`.
- Update `build-img` / flash / Maskrom helpers to resolve `rk356x_spl_loader_*.bin` (with optional transitional `MiniLoaderAll.bin` → that file symlink for tool compat).
- Document the flow in `docs/uboot-rkbin.md` and the package README (ini, DDR/SPL, BL31/BL32, git rev).

## Capabilities

### New Capabilities
- `ynh960-spl-loader`: Self-built SPL delivery under the rkbin OUTPUT basename `rk356x_spl_loader_v*.bin`, rename away from MiniLoaderAll-as-authority, rkbin `boot_merger` workflow, and rollback backup of the prior loader.
- `linux-first-uboot`: Self-built `uboot.img` whose default Rockchip boot command reaches Linux `boot_fit` without attempting Android boot paths first; TRUST pins documented.

### Modified Capabilities
- `buildroot-lws-hmi-image`: Factory/`build-img` packaging MUST accept `rk356x_spl_loader_*.bin` (and transitional `MiniLoaderAll.bin` symlink) for the ynh960 uboot_id instead of requiring only `MiniLoaderAll.bin` as the opaque authoritative name.

## Impact

- `prebuilt/bootloader/rockchip-ynh960/` layout and backup tree
- `scripts/build-img.sh`, flash / Maskrom / factory packaging paths
- `docs/uboot-rkbin.md`, make-commands / AGENTS wording that still says “never build uboot”
- Unblocks `ek3562-board-bringup` to reuse the same SPL OUTPUT naming + Linux-first uboot policy (ek3562 uses `rk3562_spl_loader_v*.bin`)
- Lab flash + serial validation on ynh960; OP-TEE/seal smoke after uboot replace
