## ADDED Requirements

### Requirement: Self-built Linux-first uboot.img for ynh960

The ynh960 `uboot.img` delivered under `prebuilt/bootloader/rockchip-ynh960/` SHALL be buildable from [rockchip-linux/u-boot](https://github.com/rockchip-linux/u-boot) (via `make fetch-uboot` or documented equivalent) with a **Linux-first** `RKIMG_BOOTCOMMAND`: it MUST NOT attempt Android boot (`boot_android` / Android FIT) before `boot_fit`. The build SHALL apply the repository bootcmd patch (or an overlay/fork patch that achieves the same order).

#### Scenario: Bootcmd has no Android attempt before boot_fit

- **WHEN** the self-built U-Boot source used for ynh960 is inspected after patching
- **THEN** `RKIMG_BOOTCOMMAND` SHALL run `boot_fit` without a preceding `boot_android` (or equivalent Android FIT try)

#### Scenario: Cold boot reaches Linux FIT path

- **WHEN** a ynh960 lab unit is flashed with the self-built `uboot.img` and product boot FIT
- **THEN** U-Boot SHALL load the Linux FIT via `boot_fit` without requiring an operator to interrupt an Android boot attempt

### Requirement: Pinned BL31 and BL32 in ynh960 uboot FIT

Self-built ynh960 `uboot.img` SHALL embed ATF/OP-TEE (BL31/BL32) matching the validated product pins **BL31 v1.44** and **BL32 v2.15** (SDK `RK3568TRUST.ini` / `rk3568_bl31_v1.44` + `rk3568_bl32_v2.15`), unless a separate approved change upgrades OP-TEE and seal TA together.

#### Scenario: Strings report pinned trust versions

- **WHEN** an operator extracts printable version markers from the shipped `uboot.img`
- **THEN** the image SHALL report `bl31-v1.44` and `bl32-v2.15` (or equivalent unambiguous markers for those versions)

### Requirement: Prior uboot backup before replace

Before replacing the shipping `uboot.img` for `rockchip-ynh960`, the repository or release process SHALL retain a **backup copy** of the previously validated `uboot.img` alongside the loader backup, with documented restore steps.

#### Scenario: U-Boot backup exists when cutting over

- **WHEN** the new self-built `uboot.img` is installed into `prebuilt/bootloader/rockchip-ynh960/`
- **THEN** a backup of the prior validated `uboot.img` SHALL exist under the documented rollback path
