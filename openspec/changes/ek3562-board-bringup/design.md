## Context

ek3562 hardware baseline is Rockchip RK3562 EVB2 DDR4 V10 (live FDT matched 2026-08-15). Overlay contains `ek3562.dts` plus display/io/linux-root fragments; OEM pack `ek3562-panel` has `fit_dt: ek3562`; FIT inventory lists `ek3562`. Bootloader directory `vendor-ek3562` is still a placeholder (this change §3). Console is USB-C Debug CH340 @ 115200.

This change formalizes the board after **`ynh960-spl-linux-uboot`** proves self-built `loader.bin` + Linux-first uboot recovery on ynh960.

## Goals / Non-Goals

**Goals:**
- Ship ek3562 FIT conf, OEM `fit_dt`, and `prebuilt/bootloader/vendor-ek3562/{loader.bin,uboot.img}`.
- Same naming and Linux-first bootcmd rules as ynh960 SPL change.
- Document/build RK3562 rkbin MINIALL + TRUST pins; serial bring-up checklist.

**Non-Goals:**
- Replacing ynh960 as default FIT conf.
- Final production panel timing (panel TBD may remain placeholder screen pack).
- Teaching unbrick on ek3562 before ynh960 path is proven.

## Decisions

### D1 — Sequence after ynh960 SPL change

- **Choice:** Apply/flash self-built ek3562 bootloader only after ynh960 SPL+uboot lab acceptance (or explicit waiver).
- **Why:** User requirement; ynh960 eMMC short recovery known.

### D2 — loader.bin + Linux-first uboot (shared policy)

- **Choice:** Reuse scripts/docs patterns from `ynh960-spl-linux-uboot`; rkbin `RK3562MINIALL*.ini` → `loader.bin`; u-boot with Linux-first patch; FIT conf name `ek3562`.
- **Why:** One operator mental model across SoCs.

### D3 — TRUST pins for RK3562

- **Choice:** Use `RK3562TRUST.ini` from the rkbin revision under test; record BL31/BL32 versions in `prebuilt/bootloader/vendor-ek3562/README.md`. Live board previously showed cmdline-style `bl31-v1.22` / `bl32-v1.08` on vendor image — reconcile to chosen rkbin pins during apply and re-verify OP-TEE if product enables it on ek3562.
- **Why:** 3562 TRUST is separate from 3568/ynh960 pins.

### D4 — FIT inventory gate

- **Choice:** Append `ek3562` to `board/rk356x-fit-boards.txt` together with OEM `fit_dt=ek3562` and multi-board A/B `*-linux-root.dtsi` packaging; verify-boot-fit after rebuild.
- **Why:** Avoid half-wired FIT; default conf stays `ynh960`.

### D5 — DTS already in overlay

- **Choice:** Treat existing `ek3562.dts` + EVB2 dtsi as SoT; commit independently if needed before apply.
- **Why:** User requested early commit of prep.

## Risks / Trade-offs

- [ynh960 validation slips] → Mitigation: keep ek3562 FIT/OEM tasks ready but block flash of new loader until gate passes.
- [Wrong RK3562 DDR ini] → Mitigation: match EVB2 DDR4; serial early logs.
- [Panel TBD] → Mitigation: boot to console/HMI without final LCD; OEM screen pack remains TBD.
- [OP-TEE on ek3562] → Mitigation: document whether seal/OP-TEE is required for first bring-up; do not assume ynh960 BL32 pins.

## Migration Plan

1. Ensure `ynh960-spl-linux-uboot` accepted (or waiver).
2. Build Image+DTB; add FIT line; verify-boot-fit.
3. Build loader+uboot into `vendor-ek3562/`.
4. Set OEM `fit_dt`; `FACTORY_SKU=ek3562-dev make build-oem` / `build-img`.
5. Flash lab ek3562; serial @ 115200; confirm model/compatible; optional HMI.

## Open Questions

- First-ship OP-TEE requirement on ek3562 (full seal vs defer).
- Exact U-Boot defconfig name in rockchip-linux/u-boot for EVB2 DDR4.
- U-Boot default FIT conf vs factory env for `bootm #ek3562` when FIT default remains `ynh960`.
