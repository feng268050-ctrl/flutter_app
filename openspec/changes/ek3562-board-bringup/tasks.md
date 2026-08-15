## 1. Prerequisites

- [ ] 1.1 Confirm `ynh960-spl-linux-uboot` lab acceptance (or record explicit waiver) before flashing new ek3562 loader/uboot
- [x] 1.2 Ensure ek3562 overlay DTS package is committed (`ek3562.dts` + display/io/linux-root + EVB2 dtsi); SoC `rk3562.dtsi` remains in SDK

## 2. Kernel Image and FIT

- [x] 2.1 Wire `ek3562-wifibt.config` into `RK_KERNEL_CFG_FRAGMENTS` + rootfs `lws_hmi_wifi_rtw88.config` (Image still needs `FORCE_KERNEL_IMAGE=1` when enabling rtw88 / RK3562 SoC bits)
- [x] 2.2 Append `ek3562` to `board/rk356x-fit-boards.txt`; multi-board `*-linux-root.dtsi` in `build-kernel-ab.sh`; ITS `fdt-ek3562`
- [ ] 2.3 `make apply-overlay` + `make build-kernel` then `bash scripts/verify-boot-fit.sh output/firmware` (refresh DTB with display/io; confs `ynh960` + `ek3562`)

## 3. Bootloader (same rules as ynh960)

- [ ] 3.1 rkbin `boot_merger` with `RK3562MINIALL*.ini` (DDR4 EVB2 matched) → `prebuilt/bootloader/vendor-ek3562/loader.bin`
- [ ] 3.2 Build `uboot.img` with Linux-first bootcmd patch; RK3562 TRUST pins recorded in README; FIT conf selection `#ek3562` or factory env
- [ ] 3.3 Package README: ini, DDR/SPL, BL31/BL32, u-boot rev

## 4. OEM and factory

- [x] 4.1 Set `oem/packs/ek3562-panel/manifest.json` `compat.fit_dt` to `ek3562`; screen.json 800×1280
- [ ] 4.2 `FACTORY_SKU=ek3562-dev make build-oem` then `make build-img` (img requires loader+uboot)
- [x] 4.3 Update `overlay/kernel/rockchip/ek3562.md` checklist for FIT/OEM (bootloader still open)

## 5. Board validation

- [ ] 5.1 Flash lab ek3562; serial `@115200` (`cu.usbserial*`); confirm model/compatible EVB2 DDR4 V10
- [ ] 5.2 Confirm Linux boot via `boot_fit` / conf `ek3562` without Android try-chain
- [ ] 5.3 Smoke Wi‑Fi helper / eth as applicable; note panel limits
- [ ] 5.4 ynh960 regression: same FIT still boots conf `ynh960`
