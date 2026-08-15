## ADDED Requirements

### Requirement: ek3562 board_id end-to-end

The product line SHALL support **`board_id` `ek3562`** (Rockchip RK3562 EVB2 DDR4 V10 baseline) with: overlay DTS producing `ek3562.dtb`, a FIT configuration named `ek3562`, OEM pack `compat.fit_dt` of `ek3562`, and factory SKU `ek3562-dev` resolving `prebuilt/bootloader/vendor-ek3562/`.

#### Scenario: FIT inventory lists ek3562 when enabled

- **WHEN** `ek3562` is present in `board/rk356x-fit-boards.txt` and `make build-kernel` succeeds
- **THEN** `scripts/verify-boot-fit.sh` SHALL report a configuration named `ek3562`

#### Scenario: OEM fit_dt matches board_id

- **WHEN** the ek3562 OEM pack is shipped for factory
- **THEN** its `manifest.json` `compat.fit_dt` SHALL equal `ek3562` and `board_id` SHALL equal `ek3562`

### Requirement: ek3562 self-built loader.bin and Linux-first uboot

`prebuilt/bootloader/vendor-ek3562/` SHALL provide **`loader.bin`** (rkbin `boot_merger` + RK3562 SPL MINIALL) and **`uboot.img`** built with the same **Linux-first** bootcmd policy as ynh960 (no Android FIT/`boot_android` before `boot_fit`). README in that directory SHALL record rkbin ini, DDR/SPL versions, and BL31/BL32 pins used.

#### Scenario: Bootloader package complete

- **WHEN** an operator prepares `FACTORY_SKU=ek3562-dev make build-img`
- **THEN** `prebuilt/bootloader/vendor-ek3562/loader.bin` and `uboot.img` SHALL exist

### Requirement: ynh960 bootloader validation gate

Flashing a newly self-built ek3562 `loader.bin` / `uboot.img` as the primary lab validation path SHALL be gated on successful acceptance of **`ynh960-spl-linux-uboot`** on ynh960 hardware (or an explicit written waiver in the change notes), because ynh960 has a known eMMC-short / Maskrom recovery procedure.

#### Scenario: Gate documented in tasks or notes

- **WHEN** implementers reach ek3562 bootloader flash tasks
- **THEN** the change tasks SHALL require ynh960 SPL/U-Boot acceptance (or recorded waiver) before marking those flash tasks done
