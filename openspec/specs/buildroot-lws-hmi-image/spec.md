# buildroot-lws-hmi-image Specification

## Purpose
TBD - created by archiving change p1-linux-flutter-platform. Update Purpose after archive.
## Requirements
### Requirement: lws_hmi Buildroot defconfig is the default rootfs profile for ynh960

The build system SHALL provide `rockchip_rk3566_rk3568_lws_hmi_defconfig` in the SDK Buildroot configs tree, composed from `base/base.config`, `lws_hmi_{base,systemd,network,flutter,bt,npu,font,build,toolchain_external}.config`, `rk3566_rk3568_aarch64.config`, `gpu/gpu.config`, `wifibt/wireless.config`, `wifibt/bt.config`, and `powermanager.config`. P1 SHALL `#include` `lws_hmi_npu.config` to gate RKNPU runtime overlay staging (`make fetch-rknn-rt`); P3+ fragments (`lws_hmi_gst_*`, `lws_hmi_mediamtx`, `lws_hmi_platform`) SHALL remain commented out until those phases are enabled. The ynh960 board configuration SHALL set `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"` (resolving to `rockchip_rk3566_rk3568_lws_hmi`) and `RK_ROOTFS_SYSTEM_BUILDROOT=y`.

#### Scenario: ynh960 lunch selects lws_hmi defconfig

- **WHEN** developer runs `make lunch` and selects ynh960 defconfig
- **THEN** SDK `.config` contains `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"`

#### Scenario: product-line firmware boots on ynh960

- **WHEN** P1 `update.img` is built via `make lunch` with `ynh960_defconfig` and flashed to **ynh960 (RK3566)** hardware
- **THEN** the image SHALL boot and reach the Hello World HMI on ynh960 (primary P1 acceptance target)

#### Scenario: shared firmware goal across product line

- **WHEN** the same P1 `update.img` is flashed to ynh961 (RK3568) or ynh962 (RK3568B2) boards on the same product line
- **THEN** the image SHOULD boot without a per-SKU defconfig fork (cross-SKU smoke is optional in P1; not a blocker for ynh960-only CI)

#### Scenario: rootfs build succeeds with lws_hmi defconfig

- **WHEN** developer runs `make build-rootfs` after overlay apply
- **THEN** Buildroot completes without missing defconfig or package errors and `scripts/verify-rootfs-overlay.sh` reports PASS

### Requirement: EVB demo packages are excluded from lws_hmi image

The lws_hmi defconfig MUST NOT include Weston, Chromium, camera, benchmark, test, or Android adbd packages. Recovery image build SHALL be disabled for P1 (`RK_RECOVERY` not set).

#### Scenario: weston not installed

- **WHEN** P1 rootfs is built and inspected
- **THEN** `weston` binary is absent from target rootfs

#### Scenario: adbd not installed

- **WHEN** P1 rootfs is built and inspected
- **THEN** `adbd` package is not present in rootfs

### Requirement: Platform stack packages are present

The P1 rootfs SHALL include Rockchip Mali GPU, libdrm/libgbm, flutter-pi (prebuilt install), RKNPU2 runtime (`librknnrt.so`, `rknn_server`) without RKNPU2 example binaries, wpa_supplicant and BlueZ/rkwifibt userland (installed but boot-deferred), powermanager, and Chinese font support. RKNPU2 binaries SHALL be staged via `make fetch-rknn-rt` into `lws-hmi-fs-overlay` (this SDK has no `BR2_PACKAGE_RKNPU2` Buildroot package).

#### Scenario: flutter-pi binary on target

- **WHEN** P1 rootfs is deployed to device
- **THEN** `/usr/bin/flutter-pi` exists and is executable

#### Scenario: RKNPU2 runtime on target without demo

- **WHEN** P1 rootfs is deployed to device
- **THEN** `/usr/lib/librknnrt.so` and `/usr/bin/rknn_server` exist and `rknn_common_test` is absent

#### Scenario: Wi-Fi userland present but boot-deferred

- **WHEN** P1 device boots
- **THEN** `wpa_supplicant` binary is installed but `wpa_supplicant.service` and `network.service` are not in `multi-user.target.wants`

### Requirement: flutter-pi and engine install from prebuilt only

Buildroot overlay packages for flutter-pi and flutter-engine SHALL copy from `prebuilt/flutter-pi/<version>/` and `prebuilt/flutter-engine/<version>/` during `make build-rootfs`. `make check-prebuilt` SHALL fail if prebuilt artifacts are missing. Host `make build-runtime-deps` populates prebuilt directories.

#### Scenario: check-prebuilt gates rootfs build

- **WHEN** developer runs `make build-rootfs` without flutter prebuilt
- **THEN** build fails with `check-prebuilt` error directing to `make build-runtime-deps`

#### Scenario: engine version pinned

- **WHEN** developer inspects version pins
- **THEN** `overlay/buildroot/flutter-engine.version` and `overlay/buildroot/flutter-pi.version` document the active pins (Flutter 3.24.4 / commit 37bd977)

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

- `make audit` — pre-flight before flash (firmware on host, upgrade_tool, RockUSB)
- `make devices` — list connected devices (MODE / SERIAL / LocationID / USB)
- `make flash` — unified flash: `uf update.img`; auto `ul` loader when RockUSB is Maskrom; `IMAGE=` overrides firmware path

Multi-device selection SHALL use `SERIAL=` (table SERIAL column; adb serial or RockUSB SerialNo). macOS Docker builds SHALL auto-export `output/firmware/` to host after `make build-img`.

#### Scenario: devices table lists RockUSB Loader

- **WHEN** board is in RockUSB Loader mode and developer runs `make devices`
- **THEN** output includes a row with MODE `Loader`, SERIAL matching device, LocationID, and USB `0x2207:…`

#### Scenario: bootloader enters RockUSB from Android

- **WHEN** device runs Android with adb connected and developer runs `SERIAL=… make reboot-loader`
- **THEN** subsequent `make devices` shows a RockUSB Loader row visible to `upgrade_tool ld`

#### Scenario: flash writes update.img

- **WHEN** RockUSB device is connected and `output/firmware/update.img` exists
- **THEN** `make flash` invokes `upgrade_tool uf` on that image (or `make flash IMAGE=/path/to.img`)

#### Scenario: multi-device requires SERIAL

- **WHEN** more than one RockUSB device is connected and `SERIAL` is not set
- **THEN** `make flash` fails with a message to run `make devices` and set `SERIAL=`

### Requirement: Build-time rootfs overlay verification

The repo SHALL provide `scripts/verify-rootfs-overlay.sh` that validates systemd unit links, helper scripts, and `/opt/hmi` layout in the Buildroot staging `target/` directory after `make build-rootfs`.

#### Scenario: verify passes after rootfs build

- **WHEN** developer runs `make build-rootfs` successfully
- **THEN** `verify-rootfs-overlay.sh` reports PASS for expected units and `/opt/hmi` artifacts

### Requirement: Minimal wlan0 DHCP client for Wi-Fi client networking

The lws_hmi rootfs SHALL include a lightweight DHCP client usable for **wlan0** after wpa_supplicant association (e.g. `dhcpcd` or BusyBox `udhcpc`). Eth0 camera addressing MUST remain outside this client's default boot behavior. Static IPv4 on wlan0 SHALL use existing `iproute2` tooling via helpers (no requirement to enable systemd-networkd).

#### Scenario: DHCP client binary present

- **WHEN** P2.1 rootfs is deployed to device
- **THEN** a documented DHCP client binary for wlan0 (dhcpcd or udhcpc) exists and is executable

#### Scenario: Boot does not require network.service

- **WHEN** the device boots to multi-user
- **THEN** `network.service` remains not in `multi-user.target.wants` (Wi-Fi IP config is App/helper-triggered)

### Requirement: CA certificates for HTTPS

The lws_hmi rootfs SHALL include a system CA certificate bundle (`BR2_PACKAGE_CA_CERTIFICATES` or equivalent) so Dart `HttpClient` (and similar TLS clients) can verify public HTTPS endpoints used by the Demo HTTP probe.

#### Scenario: CA bundle present on rootfs

- **WHEN** P2.1 rootfs is built with the lws_hmi network fragment
- **THEN** `/etc/ssl/certs/ca-certificates.crt` exists and is non-empty

