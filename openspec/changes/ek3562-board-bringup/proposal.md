## Why

ek3562 (RK3562 EVB2 DDR4 V10) already has Linux board DTS in `overlay/kernel/rockchip/` and OEM placeholders, but is not yet a first-class FIT conf, self-built bootloader pair, or flashable `FACTORY_SKU`. After ynh960 proves the self-built SPL `loader.bin` + Linux-first U-Boot path (and rollback), we can apply the same rules to ek3562 without learning unbrick on a less familiar board first.

## What Changes

- Formalize **ek3562** as a product `board_id`: FIT inventory line, OEM `compat.fit_dt: ek3562`, factory SKU `ek3562-dev` with real `prebuilt/bootloader/vendor-ek3562/{loader.bin,uboot.img}`.
- Self-build **loader.bin** via rkbin `boot_merger` + `RK3562MINIALL*.ini` (DDR-matched to EVB2).
- Self-build **uboot.img** from rockchip-linux/u-boot with the **same Linux-first bootcmd policy** as `ynh960-spl-linux-uboot` (no Android FIT try-chain before `boot_fit`); select FIT conf `ek3562` (`bootm …#ek3562` or factory env).
- Use RK3562 TRUST from rkbin (`RK3562TRUST.ini` — BL31/BL32 versions as validated on that board; document pins in design).
- Wire kernel Image Kconfig for RK3562 as needed (`FORCE_KERNEL_IMAGE=1` once), Wi‑Fi `rtw88` / OEM helpers already sketched.
- **Gate:** Do **not** flash ek3562 self-built bootloader as the primary validation path until **`ynh960-spl-linux-uboot`** has passed board recovery tests on ynh960 (known eMMC short / Maskrom procedure).
- DTS package already landed in overlay MAY be committed independently before this change’s apply phase.

## Capabilities

### New Capabilities
- `ek3562-board`: End-to-end ek3562 board identity — FIT conf, OEM fit_dt, factory SKU bootloader pair (`loader.bin` + Linux-first `uboot.img`), and bring-up acceptance criteria.

### Modified Capabilities
- `boot-fit-multi-dt`: Inventory MUST allow `ek3562` as a named FIT configuration alongside `ynh960` once Image/DTB are ready.
- `oem-pack`: ek3562 pack `compat.fit_dt` MUST move from `pending` to `ek3562` when FIT conf ships.
- `buildroot-lws-hmi-image`: `FACTORY_SKU=ek3562-dev` packaging MUST consume `prebuilt/bootloader/vendor-ek3562/` with `loader.bin` naming consistent with the ynh960 rename.

## Impact

- `overlay/kernel/rockchip/ek3562.dts` + EVB2 dtsi (already present), `ek3562-wifibt.config`, `board/rk356x-fit-boards.txt`, `board/factory-skus.tsv`
- `oem/packs/ek3562-panel/`, `prebuilt/bootloader/vendor-ek3562/`
- Shared u-boot patch / build scripts from `ynh960-spl-linux-uboot`
- Kernel universal Image (RK3562 drivers), rootfs Wi‑Fi firmware packages
- Depends on / sequenced after: `openspec/changes/ynh960-spl-linux-uboot`
- Docs: `overlay/kernel/rockchip/ek3562.md`, `docs/uboot-rkbin.md`
