## MODIFIED Requirements

### Requirement: lws_hmi Buildroot defconfig is the default rootfs profile for ynh960

The build system SHALL provide `rockchip_rk3566_rk3568_lws_hmi_defconfig` in the SDK Buildroot configs tree, composed from `base/base.config`, `lws_hmi_{base,systemd,network,flutter,bt,npu,font,build,toolchain_external}.config`, `rk3566_rk3568_aarch64.config`, `gpu/gpu.config`, `wifibt/wireless.config`, `wifibt/bt.config`, and `powermanager.config`. P1 SHALL `#include` `lws_hmi_npu.config` to gate RKNPU runtime overlay staging (`make fetch-rknn-rt`). Product MediaMTX SHALL NOT be gated by an included `lws_hmi_mediamtx` rootfs fragment (App ships the binary under `/opt/hmi`). Other deferred fragments (`lws_hmi_gst_*`, `lws_hmi_platform`) remain as documented by their owning phases. The defconfig SHALL `#include` `chips/lws_hmi_selinux.config` so the product rootfs builds with SELinux userspace and a permissive refpolicy (see `buildroot-selinux`). The ynh960 board configuration SHALL set `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"` (resolving to `rockchip_rk3566_rk3568_lws_hmi`) and `RK_ROOTFS_SYSTEM_BUILDROOT=y`.

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

#### Scenario: mediamtx not a rootfs fragment gate

- **WHEN** the active product defconfig is inspected after this change
- **THEN** it MUST NOT `#include` `chips/lws_hmi_mediamtx.config` as a required rootfs packaging step

#### Scenario: selinux fragment is included

- **WHEN** the active product defconfig is inspected after this change
- **THEN** it `#include`s `chips/lws_hmi_selinux.config`
