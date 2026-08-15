## Why

ynh960 still ships a Rockchip/Innohi-era `MiniLoaderAll.bin` filename and a vendor `uboot.img` whose stock `RKIMG_BOOTCOMMAND` tries Android (`boot_android` / android FIT) before Linux `boot_fit`. That naming and boot order confuse operators, block a clean self-build path, and are the wrong default for a Linux-only product. Public rkbin already builds RK3566 eMMC loaders as **SPL** mergers; we should rename, self-build, and ship a Linux-first U-Boot — with a recoverable backup — before repeating the same pattern on ek3562.

## What Changes

- Rename the delivered early loader artifact from **`MiniLoaderAll.bin`** to a SPL-honest name (canonical **`loader.bin`**, with documented Rockchip alias `rk356x_spl_loader_*.bin` where staging requires it).
- Self-build **loader** via [rockchip-linux/rkbin](https://github.com/rockchip-linux/rkbin) `boot_merger` + matching `RK3566MINIALL*.ini` (DDR-matched).
- Self-build **`uboot.img`** from [rockchip-linux/u-boot](https://github.com/rockchip-linux/u-boot) (`make fetch-uboot` / `next-dev`), packing trust with **pinned** BL31 **v1.44** + BL32 **v2.15** (current ynh960 OP-TEE / seal-TA contract — do **not** silent-bump to rkbin master v1.46/v2.16).
- Ensure bootcmd is **Linux-first**: no Android FIT / `boot_android` attempt before `boot_fit` (extend or replace `overlay/device/rockchip/common/scripts/patch-uboot-bootcmd.sh`; fork/patch Rockchip source if upstream default still prefers android).
- **Backup** today’s validated `MiniLoaderAll.bin` + `uboot.img` under a dated rollback directory before replacing `prebuilt/bootloader/rockchip-ynh960/`.
- Update `build-img` / flash / docs so factory packaging and Maskrom `ul` use the new names without breaking recovery.
- **Out of scope:** ek3562 factory bring-up (separate change `ek3562-board-bringup`); OP-TEE BL32 major upgrade.

## Capabilities

### New Capabilities
- `ynh960-spl-loader`: Self-built SPL `loader.bin` delivery, rename away from MiniLoaderAll, rkbin `boot_merger` workflow, and rollback backup of the prior loader.
- `linux-first-uboot`: Self-built `uboot.img` with Linux-first `RKIMG_BOOTCOMMAND` (no Android FIT try-chain ahead of `boot_fit`), pinned RK3568 TRUST BL31/BL32, and install into `prebuilt/bootloader/rockchip-ynh960/`.

### Modified Capabilities
- `buildroot-lws-hmi-image`: Factory/`build-img` packaging MUST accept `loader.bin` (and transitional aliases) for the ynh960 uboot_id instead of requiring only `MiniLoaderAll.bin`.

## Impact

- `prebuilt/bootloader/rockchip-ynh960/`, `prebuilt/sdk-loader/`, `prebuilt/sdk-uboot/`
- `scripts/build-img.sh`, `scripts/build-uboot.sh`, `scripts/fetch-uboot.sh`, flash/Maskrom helpers
- `overlay/device/rockchip/common/scripts/patch-uboot-bootcmd.sh` (+ possible `overlay/kernel/patches` or u-boot overlay patches)
- Docs: `docs/uboot-rkbin.md`, README / make-commands / AGENTS rebuild notes
- Field risk: wrong DDR/SPL or uboot bricks boot — mitigated by backup + eMMC short / Maskrom recovery (known on ynh960)
- OP-TEE: unchanged if TRUST stays v1.44/v2.15; seal TA / `vendor_ta.pem` remain valid
