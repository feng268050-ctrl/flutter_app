## ADDED Requirements

### Requirement: Factory artifact named factory.img includes oem

`make build-img` SHALL produce `output/firmware/<factory_sku>/factory.img` for the resolved `FACTORY_SKU`, packaging loader, uboot from `prebuilt/bootloader/<uboot_id>/`, misc, dual FIT, rootfs, and **oem** when `oem.img` is present for the resolved `OEM_ID`. A sibling `manifest.txt` SHALL record `uboot_id`, `oem_id`, and git/build identity. During migration, `output/firmware/update.img` SHALL remain usable as a symlink or copy of the selected/default sku's `factory.img` so existing flash defaults keep working.

#### Scenario: build-img writes per-sku factory.img

- **WHEN** required inputs including oem.img exist and the operator runs `FACTORY_SKU=ynh960-p800 make build-img`
- **THEN** `output/firmware/ynh960-p800/factory.img` and `manifest.txt` exist

#### Scenario: flash default uses factory path

- **WHEN** the operator runs `FACTORY_SKU=ynh960-p800 make flash` without `IMAGE=`
- **THEN** the flash path SHALL target that sku's `factory.img` (or the compatible `update.img` symlink to it)

## MODIFIED Requirements

### Requirement: lws_hmi Buildroot defconfig is the default rootfs profile for ynh960

The build system SHALL provide `rockchip_rk3566_rk3568_lws_hmi_defconfig` in the SDK Buildroot configs tree, composed from `base/base.config`, `lws_hmi_{base,systemd,network,flutter,bt,npu,font,build,toolchain_external}.config`, `rk3566_rk3568_aarch64.config`, `gpu/gpu.config`, `wifibt/wireless.config`, `wifibt/bt.config`, and `powermanager.config`. P1 SHALL `#include` `lws_hmi_npu.config` to gate RKNPU runtime overlay staging (`make fetch-rknn-rt`); P3+ fragments (`lws_hmi_gst_*`, `lws_hmi_mediamtx`, `lws_hmi_platform`) SHALL remain commented out until those phases are enabled. The ynh960 board configuration SHALL set `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"` (resolving to `rockchip_rk3566_rk3568_lws_hmi`) and `RK_ROOTFS_SYSTEM_BUILDROOT=y`.

#### Scenario: ynh960 lunch selects lws_hmi defconfig

- **WHEN** developer runs `make lunch` and selects ynh960 defconfig
- **THEN** SDK `.config` contains `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"`

#### Scenario: product-line firmware boots on ynh960

- **WHEN** P1 `factory.img` (or migration `update.img` symlink) is built via `make lunch` with `ynh960_defconfig` and flashed to **ynh960 (RK3566)** hardware
- **THEN** the image SHALL boot and reach the Hello World HMI on ynh960 (primary P1 acceptance target)

#### Scenario: shared firmware goal across product line

- **WHEN** the same P1 factory image is flashed to ynh961 (RK3568) or ynh962 (RK3568B2) boards on the same product line
- **THEN** the image SHOULD boot without a per-SKU defconfig fork (cross-SKU smoke is optional in P1; not a blocker for ynh960-only CI)

#### Scenario: rootfs build succeeds with lws_hmi defconfig

- **WHEN** developer runs `make build-rootfs` after overlay apply
- **THEN** Buildroot completes without missing defconfig or package errors and `scripts/verify-rootfs-overlay.sh` reports PASS
