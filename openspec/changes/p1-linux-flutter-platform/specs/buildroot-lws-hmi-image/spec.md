## ADDED Requirements

### Requirement: lws_hmi Buildroot defconfig is the default rootfs profile for ynh960

The build system SHALL provide `rockchip_rk3566_rk3568_lws_hmi_defconfig` in the SDK Buildroot configs tree, composed from `base/base.config`, `lws_hmi_{base,systemd,network,npu,flutter}.config`, `rk3566_rk3568_aarch64.config`, `gpu/gpu.config`, `wifibt/wireless.config`, `wifibt/bt.config`, `font/chinese.config`, and `powermanager.config`. The ynh960 board configuration SHALL set `RK_BUILDROOT_CFG=rockchip_rk3566_rk3568_lws_hmi` and `RK_ROOTFS_SYSTEM_BUILDROOT=y`.

#### Scenario: ynh960 lunch selects lws_hmi defconfig

- **WHEN** developer runs `make lunch` and selects ynh960 defconfig
- **THEN** SDK `.config` contains `RK_BUILDROOT_CFG=rockchip_rk3566_rk3568_lws_hmi`

#### Scenario: rootfs build succeeds with lws_hmi defconfig

- **WHEN** developer runs `make build-rootfs` after overlay apply
- **THEN** Buildroot completes without missing defconfig or package errors

### Requirement: EVB demo packages are excluded from lws_hmi image

The lws_hmi defconfig MUST NOT include Weston, Chromium, camera, benchmark, test, or Android adbd packages. Recovery image build SHALL be disabled for P1 (`RK_RECOVERY=n`).

#### Scenario: weston not installed

- **WHEN** P1 rootfs is built and inspected
- **THEN** `weston` binary is absent from target rootfs

#### Scenario: adbd not installed

- **WHEN** P1 rootfs is built and inspected
- **THEN** `adbd` package is not present in rootfs

### Requirement: Platform stack packages are present

The P1 rootfs SHALL include Rockchip Mali GPU, libdrm/libgbm, flutter-pi, RKNPU2 runtime (`librknnrt.so`, `rknn_server`) without RKNPU2 example binaries, wpa_supplicant, BlueZ/rkwifibt stack, powermanager, and Chinese font support.

#### Scenario: flutter-pi binary on target

- **WHEN** P1 rootfs is deployed to device
- **THEN** `/usr/bin/flutter-pi` exists and is executable

#### Scenario: RKNPU2 runtime without demo

- **WHEN** P1 rootfs is inspected
- **THEN** `librknnrt.so` is present and `rknn_common_test` is absent

#### Scenario: Wi-Fi and Bluetooth userland present

- **WHEN** P1 rootfs is inspected
- **THEN** `wpa_supplicant` and `bluetoothd` binaries are installed (bluetoothd not auto-enabled at boot)

### Requirement: Rootfs overlay and LCD display params are applied

Buildroot SHALL mount `lws-hmi-fs-overlay` via `BR2_ROOTFS_OVERLAY` and install ynh960 LCD/MIPI parameter files under `/system/etc/` per existing lws-hmi display hooks.

#### Scenario: LCD params on target

- **WHEN** P1 device boots
- **THEN** `/system/etc/960_lcd_param_rk356x.txt` and `/system/etc/lcd_mipi_param.txt` exist

### Requirement: P1 rootfs size target

The P1 rootfs (excluding `/opt/hmi` Flutter app) SHOULD be between 220 MB and 450 MB uncompressed on first successful build; exceeding 500 MB MUST trigger a documented trim review.

#### Scenario: rootfs size measurement

- **WHEN** first P1 rootfs build completes
- **THEN** `du -sh` of Buildroot `target/` is recorded in build notes or CI log

### Requirement: Host USB flash via Makefile and upgrade_tool

The repo SHALL provide `scripts/flash-usb.sh` and Makefile targets for ynh960 firmware programming on a **macOS host** with Rockchip **upgrade_tool** vendored at `tools/upgrade_tool/`, aligned with `tools/upgrade_tool/命令行开发工具使用文档.pdf`:

- `make devices` — list connected devices in a table (columns: MODE, SERIAL, LocationID, USB); includes adb (`android`, …) and RockUSB (`Loader`, `Maskrom`, …) from `upgrade_tool ld`
- `make bootloader` — `adb reboot loader` to enter RockUSB Loader (not Android `reboot bootloader`)
- `make loader` — `upgrade_tool ul` with default `output/firmware/MiniLoaderAll.bin`
- `make upgrade` — `upgrade_tool uf` with default `output/firmware/update.img`; `IMAGE=` overrides the firmware path

Multi-device selection SHALL use `SERIAL=` (table SERIAL column) or `USB_LOCATION=` (`upgrade_tool -s`, PDF §1.11). macOS Docker builds SHALL document `make docker-volume-pull` or `LWS_HMI_AUTO_PULL=1` before flash.

#### Scenario: devices table lists RockUSB Loader

- **WHEN** board is in RockUSB Loader mode and developer runs `make devices`
- **THEN** output includes a row with MODE `Loader`, SERIAL matching device, LocationID, and USB `0x2207:…`

#### Scenario: bootloader enters RockUSB from Android

- **WHEN** device runs Android with adb connected and developer runs `SERIAL=… make bootloader`
- **THEN** subsequent `make devices` shows a RockUSB Loader row visible to `upgrade_tool ld`

#### Scenario: upgrade flashes update.img

- **WHEN** RockUSB device is connected and `output/firmware/update.img` exists
- **THEN** `make upgrade` invokes `upgrade_tool uf` on that image (or `make upgrade IMAGE=/path/to.img`)

#### Scenario: multi-device requires SERIAL or USB_LOCATION

- **WHEN** more than one RockUSB device is connected and neither `SERIAL` nor `USB_LOCATION` is set
- **THEN** `make loader` or `make upgrade` fails with a message to run `make devices` and set selection
