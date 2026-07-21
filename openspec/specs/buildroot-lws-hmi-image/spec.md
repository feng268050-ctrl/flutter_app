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

The P1 rootfs SHALL include Rockchip Mali GPU, libdrm/libgbm, flutter-pi (prebuilt install), RKNPU2 runtime (`librknnrt.so`, `rknn_server`) without RKNPU2 example binaries, wpa_supplicant and BlueZ/rkwifibt userland (installed but boot-deferred), powermanager, and Chinese font support. RKNPU2 binaries SHALL be staged via `make fetch-rknn-rt` into `rootfs-overlay` (this SDK has no `BR2_PACKAGE_RKNPU2` Buildroot package).

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

Buildroot SHALL mount `rootfs-overlay` via `BR2_ROOTFS_OVERLAY` and install ynh960 LCD/MIPI parameter files under `/system/etc/` per existing lws-hmi display hooks.

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
- `make devices` — list connected devices (MODE / SN / ChipID / LocationID / USB)
- `make flash` — unified flash: `uf update.img`; auto `ul` loader when RockUSB is Maskrom; `IMAGE=` overrides firmware path

Multi-device selection SHALL use `SN=` matching table **SN** or **ChipID** (adb SerialNo or RockUSB SerialNo for those modes). macOS Docker builds SHALL auto-export `output/firmware/` to host after `make build-img`.

#### Scenario: devices table lists RockUSB Loader

- **WHEN** board is in RockUSB Loader mode and developer runs `make devices`
- **THEN** output includes a row with MODE `Loader`, SN and ChipID matching device SerialNo, LocationID, and USB `0x2207:…`

#### Scenario: bootloader enters RockUSB from Android

- **WHEN** device runs Android with adb connected and developer runs `SN=… make reboot-loader`
- **THEN** subsequent `make devices` shows a RockUSB Loader row visible to `upgrade_tool ld`

#### Scenario: flash writes update.img

- **WHEN** RockUSB device is connected and `output/firmware/update.img` exists
- **THEN** `make flash` invokes `upgrade_tool uf` on that image (or `make flash IMAGE=/path/to.img`)

#### Scenario: multi-device requires SN

- **WHEN** more than one RockUSB device is connected and `SN` is not set
- **THEN** `make flash` fails with a message to run `make devices` and set `SN=`

### Requirement: Build-time rootfs overlay verification

The repo SHALL provide `scripts/verify-rootfs-overlay.sh` that validates systemd unit links, helper scripts, and `/opt/hmi` layout in the Buildroot staging `target/` directory after `make build-rootfs`.

#### Scenario: verify passes after rootfs build

- **WHEN** developer runs `make build-rootfs` successfully
- **THEN** `verify-rootfs-overlay.sh` reports PASS for expected units and `/opt/hmi` artifacts

### Requirement: Minimal wlan0 DHCP client for Wi-Fi client networking

The lws_hmi rootfs SHALL include a lightweight DHCP client usable for **wlan0** after wpa_supplicant association (e.g. `dhcpcd` or BusyBox `udhcpc`). The same client binary MAY also be invoked by **eth0-scoped App helpers** after operator or Demo action. Neither wlan0 nor eth0 addressing MUST require enabling `dhcpcd.service` or `network.service` at boot. Static IPv4 on wlan0 or eth0 SHALL use existing `iproute2` tooling via per-iface helpers (no requirement to enable systemd-networkd). Eth0 IPC camera segment scripting remains a separate P5.1 concern and MUST NOT be required for this DHCP client package to exist.

#### Scenario: DHCP client binary present

- **WHEN** P2.1 rootfs is deployed to device
- **THEN** a documented DHCP client binary for wlan0 (dhcpcd or udhcpc) exists and is executable

#### Scenario: Boot does not require network.service

- **WHEN** the device boots to multi-user
- **THEN** `network.service` remains not in `multi-user.target.wants` (Wi-Fi and Ethernet IP config are App/helper-triggered)

### Requirement: eth0 DHCP/static helpers in rootfs overlay

The lws_hmi rootfs SHALL include eth0-scoped helper scripts for DHCP and static IPv4 (e.g. `eth0-dhcp.sh`, `eth0-static.sh` under `/usr/libexec/hmi/`) usable from the HMI after boot. Eth0 DHCP MUST remain outside `dhcpcd.service` / `network.service` default boot enablement. Static IPv4 on eth0 SHALL use `iproute2` via those helpers (no requirement to enable systemd-networkd).

#### Scenario: eth0 helpers present

- **WHEN** P2.1 rootfs is deployed to device after this change
- **THEN** documented eth0 DHCP and static helper scripts exist and are executable under `/usr/libexec/hmi/`

#### Scenario: Boot does not enable dhcpcd for eth0

- **WHEN** the device boots to multi-user without App-triggered eth0 config
- **THEN** `dhcpcd.service` and `network.service` remain not in `multi-user.target.wants`

### Requirement: CA certificates for HTTPS

The lws_hmi rootfs SHALL include a system CA certificate bundle (`BR2_PACKAGE_CA_CERTIFICATES` or equivalent) so Dart `HttpClient` (and similar TLS clients) can verify public HTTPS endpoints used by the Demo HTTP probe.

#### Scenario: CA bundle present on rootfs

- **WHEN** P2.1 rootfs is built with the lws_hmi network fragment
- **THEN** `/etc/ssl/certs/ca-certificates.crt` exists and is non-empty

### Requirement: Minimal ALSA userland for P2.1 speaker smoke

The lws_hmi rootfs SHALL include a minimal ALSA userland sufficient to play a local media file and adjust output volume on ynh960 (ALSA libraries plus mixer/player tooling required by the Linux media-audio backend). This SHALL NOT require enabling the full P5 MediaMTX / RTSP GStreamer product stack solely for speaker smoke.

#### Scenario: ALSA mixer tooling present

- **WHEN** P2.1 rootfs is deployed to device
- **THEN** an ALSA mixer utility usable by the media-audio backend (e.g. `amixer`) is present on the target

#### Scenario: Playback helper present when plugin path needs it

- **WHEN** the chosen Linux media-audio backend relies on an external decoder/player
- **THEN** that binary is present on the target rootfs and invocable by the HMI process

### Requirement: Overlay includes settings isolation units

The lws_hmi rootfs overlay SHALL include `wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`, `settings-restore.service`, `run-wpa.sh`, and `restore-settings.sh`. `verify-rootfs-overlay` SHALL fail if `wifi-stack-up.sh` still starts `wpa_supplicant -B` directly instead of the dedicated unit.

#### Scenario: verify catches in-cgroup wpa

- **WHEN** `verify-rootfs-overlay.sh` runs against a staging target whose `wifi-stack-up.sh` still embeds `wpa_supplicant -B`
- **THEN** verification fails

### Requirement: Image retains USB HID host support for the 1 mm expansion

The lws-hmi Buildroot/kernel configuration for ynh960 SHALL retain (or restore if previously trimmed) the USB HID and **USB host controller** pieces required for a wired keyboard on the **1 mm pin-header host expansion**: host controller / PHY for that path, `usbhid`/`hid-generic` (or equivalent). Trim fragments and the Micro-USB OTG overlay MUST NOT leave that host expansion disabled solely to enable OTG gadget or dual-role mode. Micro-USB OTG dual-role and plug-ssh remain in scope of `usb-otg-id-role` / `usb-plug-ssh-debug` and MUST keep working per those specs.

#### Scenario: HID host path present for keyboard expansion

- **WHEN** the flashed image boots and a USB HID keyboard is plugged in via the 1 mm host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Overlay verify lists new helpers if shipped

- **WHEN** the change adds overlay helpers specific to host-expansion keyboard bring-up (if any)
- **THEN** `scripts/verify-rootfs-overlay.sh` (and env-verify expectations if applicable) includes those helpers

### Requirement: Image enables Micro-USB OTG dual-role with HID host on OTG

The lws-hmi kernel/Device Tree/Buildroot configuration SHALL enable **OTG dual-role** on the Micro-USB `usbdrd` path (`dr_mode=otg` or equivalent) with USB HID host support when that port is in host role, without removing the 1 mm expansion host enablement. DWC3 MUST NOT be built gadget-only if that prevents OTG host on Micro-USB.

#### Scenario: OTG host keyboard without out-of-tree modules

- **WHEN** the flashed image boots, Debug over USB is off (Micro-USB host), and a USB HID keyboard is attached through an OTG host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Peripheral plug-ssh still available

- **WHEN** the same image is used with Debug over USB on and a PC data cable on Micro-USB (peripheral role + VBUS)
- **THEN** plug-ssh ECM debug can still come up per `usb-plug-ssh-debug`

### Requirement: flutter-pi keyboard runtime data present

The image SHALL ship the userspace data flutter-pi needs to enable text/raw keyboard input: **xkeyboard-config** files under `/usr/share/X11/xkb` (including `rules/evdev`) and enough X11 locale Compose mapping under `/usr/share/X11/locale` for locale `C` / `C.UTF-8`. Enabling `BR2_PACKAGE_LIBXKBCOMMON` alone is not sufficient. Full X.org (`BR2_PACKAGE_XORG7`) is not required when Compose stubs are provided via rootfs overlay.

#### Scenario: flutter-pi initializes keyboard configuration

- **WHEN** `flutter-pi` starts on a flashed image that includes the keyboard runtime data
- **THEN** it MUST NOT log `Could not initialize keyboard configuration` / `Flutter-pi will run without text/raw keyboard input`

### Requirement: flutter-pi cursor and mouse pref support in image

The Buildroot/lws-hmi image SHALL ship a flutter-pi build that: (1) shows a reliable on-screen mouse pointer when a USB mouse is attached on ynh960; and (2) applies mouse preferences from `/var/lib/hmi/` (natural scroll, scroll speed, pointer speed, primary button) at process start and when pointer devices are added. Any package patches required for cursor fallback or pref apply MUST be present under the repository flutter-pi package overlay and baked into the prebuilt used by rootfs.

#### Scenario: Prebuilt includes mouse/cursor patches

- **WHEN** `make check-prebuilt` / rootfs packaging runs after this change
- **THEN** the shipped flutter-pi binary includes the cursor visibility and mouse preference apply support required by `linux-usb-hid-mouse` and `linux-mouse-settings`

#### Scenario: verify-rootfs accepts mouse pref path

- **WHEN** `scripts/verify-rootfs-overlay.sh` runs against an overlay that documents or stages mouse preference defaults
- **THEN** verification passes (or explicitly skips non-staged optional default files without failing the image)

### Requirement: Firmware GPT and size gates cover boot and rootfs A/B

The lws_hmi image build SHALL consume the A/B `parameter-buildroot-fit.txt` layout with **`boot`/`boot_b`** and **`rootfs_a`/`rootfs_b`**. `scripts/verify-firmware-partitions.sh` (or equivalent) SHALL fail the build if `boot.img` exceeds either boot slot or `rootfs.img` exceeds either rootfs slot. Factory packaging SHALL populate **both letters** with the same boot and rootfs images (or an equivalent documented first-boot clone policy).

#### Scenario: Oversized rootfs fails verify

- **WHEN** `rootfs.img` is larger than the `rootfs_a`/`rootfs_b` GPT size
- **THEN** firmware partition verification fails before shipping `update.img`

#### Scenario: Oversized boot fails verify

- **WHEN** `boot.img` is larger than the `boot`/`boot_b` GPT size
- **THEN** firmware partition verification fails before shipping `update.img`

#### Scenario: Parameter overlay installs A/B table

- **WHEN** developer runs `make apply-overlay` after this change
- **THEN** the SDK board parameter file matches the repo A/B `parameter-buildroot-fit.txt`

### Requirement: Rootfs overlay ships A/B upgrade helpers

The lws_hmi rootfs overlay SHALL include the board full-system apply/confirm helpers (scripts and any systemd units required by `ab-firmware-slots`), including support for writing **boot and rootfs** on the inactive letter. `scripts/verify-rootfs-overlay.sh` SHALL fail if those helpers are missing from the staging target after `make build-rootfs`.

#### Scenario: verify finds upgrade helpers

- **WHEN** `make build-rootfs` completes successfully after this change
- **THEN** `verify-rootfs-overlay.sh` reports PASS including A/B upgrade helper presence checks

### Requirement: Kernel/boot selection matches A/B letter pairs

The boot chain configuration used by the product image SHALL load the active letter’s FIT via the partition named **`boot`** (try-boot may swap with `boot_b`) and mount the matching `rootfs_*`. Hardcoded sole reliance on a pre-A/B single `root=/dev/mmcblk0p6` for product boots MUST NOT remain as the only mechanism after this change.

#### Scenario: Bootargs or DTS documents paired slot root

- **WHEN** a developer inspects the ynh960 Linux root DTS/bootargs overlay after this change
- **THEN** root selection is expressed in terms of A/B letters (PARTLABEL or slot-resolved device) paired with the selected boot slot

