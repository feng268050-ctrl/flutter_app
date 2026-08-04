# buildroot-lws-hmi-image Specification

## Purpose
TBD - created by archiving change p1-linux-flutter-platform. Update Purpose after archive.
## Requirements
### Requirement: lws_hmi Buildroot defconfig is the default rootfs profile for ynh960

The build system SHALL provide `rockchip_rk3566_rk3568_lws_hmi_defconfig` in the SDK Buildroot configs tree, composed from `base/base.config`, `lws_hmi_{base,systemd,network,flutter,bt,npu,font,build,toolchain_external}.config`, `rk3566_rk3568_aarch64.config`, `gpu/gpu.config`, `wifibt/wireless.config`, `wifibt/bt.config`, and `powermanager.config`. P1 SHALL `#include` `lws_hmi_npu.config` to gate RKNPU runtime overlay staging (`make fetch-rknn-rt`). Product MediaMTX SHALL NOT be gated by an included `lws_hmi_mediamtx` rootfs fragment (App ships the binary under `/opt/hmi`). Other deferred fragments (`lws_hmi_gst_*`, `lws_hmi_platform`) remain as documented by their owning phases. The ynh960 board configuration SHALL set `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"` (resolving to `rockchip_rk3566_rk3568_lws_hmi`) and `RK_ROOTFS_SYSTEM_BUILDROOT=y`.

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

### Requirement: EVB demo packages are excluded from lws_hmi image

The lws_hmi defconfig MUST NOT include Weston, Chromium, camera, benchmark, test, or Android adbd packages. Recovery image build SHALL be disabled for P1 (`RK_RECOVERY` not set).

#### Scenario: weston not installed

- **WHEN** P1 rootfs is built and inspected
- **THEN** `weston` binary is absent from target rootfs

#### Scenario: adbd not installed

- **WHEN** P1 rootfs is built and inspected
- **THEN** `adbd` MUST NOT be present under `/usr/bin`, `/sbin`, or `/system/bin`, and `/etc/profile.d/adbd.sh` MUST NOT remain
- **AND** board `post-build.sh` SHALL remove those paths when incremental Buildroot `target/` reuse would otherwise keep them after `BR2_PACKAGE_ANDROID_ADBD` is unset

### Requirement: Platform stack packages are present

The P1 rootfs SHALL include Rockchip Mali GPU, libdrm/libgbm, eLinux HMI (prebuilt install), RKNPU2 runtime (`librknnrt.so`, `rknn_server`) without RKNPU2 example binaries, wpa_supplicant and BlueZ/rkwifibt userland (installed but boot-deferred), powermanager, Chinese font support, and system OpenSSL libraries from the overlay-pinned `libopenssl` package (see `buildroot-libopenssl`). RKNPU2 binaries SHALL be staged via `make fetch-rknn-rt` into `rootfs-overlay` (this SDK has no `BR2_PACKAGE_RKNPU2` Buildroot package).

#### Scenario: eLinux HMI binary on target

- **WHEN** P1 rootfs is deployed to device
- **THEN** `/usr/bin/flutter-wayland-client` exists and is executable

#### Scenario: RKNPU2 runtime on target without demo

- **WHEN** P1 rootfs is deployed to device
- **THEN** `/usr/lib/librknnrt.so` and `/usr/bin/rknn_server` exist and `rknn_common_test` is absent

#### Scenario: Wi-Fi userland present but boot-deferred

- **WHEN** P1 device boots
- **THEN** `wpa_supplicant` binary is installed but `wpa_supplicant.service` and `network.service` are not in `multi-user.target.wants`

#### Scenario: OpenSSL libraries from overlay pin

- **WHEN** P1 rootfs is deployed to device after this change
- **THEN** `/lib/libcrypto.so.3` or `/usr/lib/libcrypto.so.3` exists and its OpenSSL version string matches the overlay `libopenssl` pin (not vendor `3.2.1`)

### Requirement: Rootfs ships overlay-pinned libopenssl

The lws_hmi rootfs SHALL include system OpenSSL libraries (`libssl.so.3` / `libcrypto.so.3`) built from the overlay-pinned `libopenssl` package version required by `buildroot-libopenssl`, not the vendor SDK default of OpenSSL 3.2.1. The image MAY omit the `openssl` CLI binary.

#### Scenario: rootfs libcrypto version is pinned

- **WHEN** a product rootfs built after this change is inspected
- **THEN** `libcrypto.so.3` reports the overlay-pinned OpenSSL version (not `3.2.1`)

### Requirement: Rootfs ships overlay-pinned BlueZ

The lws_hmi rootfs SHALL include BlueZ userspace (`bluetoothd` and related tools enabled by `lws_hmi_bt.config`) built from the overlay-pinned `bluez5_utils` version required by `buildroot-bluez-security`, not the vendor SDK default of BlueZ 5.77.

#### Scenario: rootfs bluetoothd version is pinned

- **WHEN** a product rootfs built after this change is inspected on device or in `target/`
- **THEN** `bluetoothd -v` reports the overlay pin (≥ 5.87), not `5.77`

### Requirement: eLinux HMI and engine install from prebuilt only

Buildroot overlay packages for the eLinux HMI and flutter-engine SHALL copy from `prebuilt/eLinux HMI/<version>/` and `prebuilt/flutter-engine/<version>/` during `make build-rootfs`. `make check-prebuilt` SHALL fail if prebuilt artifacts are missing. Host `make build-runtime-deps` populates prebuilt directories.

#### Scenario: check-prebuilt gates rootfs build

- **WHEN** developer runs `make build-rootfs` without flutter prebuilt
- **THEN** build fails with `check-prebuilt` error directing to `make build-runtime-deps`

#### Scenario: engine version pinned

- **WHEN** developer inspects version pins
- **THEN** `overlay/buildroot/flutter-engine.version`, `overlay/buildroot/flutter-sdk.version`, and `overlay/buildroot/flutter-embedded-linux.version` document the active pins (Flutter **3.41.9** / eLinux **42d3d75a56**)

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

The repo SHALL provide `scripts/flash-usb.sh` and Makefile targets for ynh960 firmware programming on a **macOS, Linux (x86_64), or Windows (Git Bash / MSYS2)** host with Rockchip **upgrade_tool** vendored at `tools/upgrade_tool/{macos,linux,windows}/`, aligned with `tools/upgrade_tool/命令行开发工具使用文档.pdf`. The host script SHALL select the platform subdirectory from the host OS (`Darwin` → `macos`, `Linux` → `linux`, `MINGW*` / `MSYS*` / `CYGWIN*` → `windows`).

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

### Requirement: curl CLI on product rootfs

The lws_hmi rootfs SHALL include the Buildroot `libcurl` package with the curl CLI option enabled (`BR2_PACKAGE_LIBCURL` and `BR2_PACKAGE_LIBCURL_CURL`) so `/usr/bin/curl` (or an equivalent PATH location such as `/bin/curl`) is present and executable. The binary SHALL use the system CA certificate bundle already required for HTTPS (`BR2_PACKAGE_CA_CERTIFICATES`) for TLS verification. Enabling the gst-plugins-bad curl plugin is not required by this requirement.

#### Scenario: curl present after rootfs build

- **WHEN** rootfs is built with the lws_hmi network fragment after this change
- **THEN** an executable `curl` binary exists on the target filesystem under a standard PATH location

#### Scenario: HTTPS probe can use system trust

- **WHEN** an operator runs `curl` against a public HTTPS URL on a networked device with a valid CA bundle
- **THEN** TLS verification uses the system CA store (not an empty/missing trust path that forces `--insecure` for normal probes)

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

The lws-hmi Buildroot/kernel configuration for ynh960 SHALL retain (or restore if previously trimmed) the USB HID and **USB host controller** pieces required for a wired keyboard on the **1 mm pin-header host expansion**: host controller / PHY for that path, `usbhid`/`hid-generic` (or equivalent). Trim fragments and the Micro-USB OTG overlay MUST NOT leave that host expansion disabled solely to enable OTG gadget or dual-role mode. Micro-USB OTG dual-role, plug-ssh, and **MTP** remain in scope of `usb-otg-id-role` / `usb-plug-ssh-debug` / `usb-otg-mtp` and MUST keep working per those specs.

#### Scenario: HID host path present for keyboard expansion

- **WHEN** the flashed image boots and a USB HID keyboard is plugged in via the 1 mm host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Expansion host keyboard still enumerates with debug

- **WHEN** a USB HID keyboard is attached via the 1 mm host expansion while OTG mode is `debug`
- **THEN** the keyboard still enumerates on the expansion host path

### Requirement: Image enables Micro-USB OTG dual-role with HID host on OTG

The lws-hmi kernel/Device Tree/Buildroot configuration SHALL enable **OTG dual-role** on the Micro-USB `usbdrd` path (`dr_mode=otg` or equivalent) with USB HID host support when that port is in host role, without removing the 1 mm expansion host enablement. DWC3 MUST NOT be built gadget-only if that prevents OTG host on Micro-USB.

#### Scenario: OTG host keyboard without out-of-tree modules

- **WHEN** the flashed image boots, Debug over USB is off (Micro-USB host), and a USB HID keyboard is attached through an OTG host adapter
- **THEN** a HID input device appears without requiring an out-of-tree module from the operator

#### Scenario: Peripheral plug-ssh still available

- **WHEN** the same image is used with Debug over USB on and a PC data cable on Micro-USB (peripheral role + VBUS)
- **THEN** plug-ssh ECM debug can still come up per `usb-plug-ssh-debug`

### Requirement: eLinux HMI keyboard runtime data present

The image SHALL ship the userspace data eLinux HMI needs to enable text/raw keyboard input: **xkeyboard-config** files under `/usr/share/X11/xkb` (including `rules/evdev`) and enough X11 locale Compose mapping under `/usr/share/X11/locale` for locale `C` / `C.UTF-8`. Enabling `BR2_PACKAGE_LIBXKBCOMMON` alone is not sufficient. Full X.org (`BR2_PACKAGE_XORG7`) is not required when Compose stubs are provided via rootfs overlay.

#### Scenario: eLinux HMI initializes keyboard configuration

- **WHEN** `eLinux HMI` starts on a flashed image that includes the keyboard runtime data
- **THEN** it MUST NOT log `Could not initialize keyboard configuration` / `eLinux HMI will run without text/raw keyboard input`

### Requirement: eLinux HMI cursor and mouse pref support in image

The Buildroot/lws-hmi image SHALL ship a eLinux HMI build that: (1) shows a reliable on-screen mouse pointer when a USB mouse is attached on ynh960; and (2) applies mouse preferences from `/var/lib/hal/` (natural scroll, scroll speed, pointer speed, primary button) at process start and when pointer devices are added. Any package patches required for cursor fallback or pref apply MUST be present under the repository eLinux HMI package overlay and baked into the prebuilt used by rootfs.

#### Scenario: Prebuilt includes mouse/cursor patches

- **WHEN** the image is built with the eLinux HMI prebuilt used by rootfs
- **THEN** the shipped eLinux HMI binary includes the cursor visibility and mouse preference apply support required by `linux-usb-hid-mouse` and `linux-mouse-settings`

#### Scenario: verify-rootfs accepts mouse pref path

- **WHEN** `scripts/verify-rootfs-overlay.sh` runs against an overlay that documents or stages mouse preference defaults
- **THEN** verification accepts `/var/lib/hal/` as the mouse preference directory

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

### Requirement: Product image includes the GStreamer/MPP live IP-camera preview runtime

The lws_hmi product rootfs SHALL include the runtime needed for the Flutter HMI to decode and render the local MediaMTX RTSP preview: overlay-pinned GStreamer core (≥ **1.28.5** per `buildroot-gstreamer-security`), RTSP/RTP transports, required H.264/H.265 parsing, and Rockchip MPP hardware decode integration. The product rootfs SHALL include a flutter-embedded-linux client linked with the Sony eLinux GStreamer video player plugin and install its required shared library. The active product defconfig SHALL include `lws_hmi_gst_rtsp.config` or its generated prebuilt equivalent. This runtime is required by the IP Camera settings preview and MUST NOT remain deferred/commented out after this change.

#### Scenario: Rootfs contains the preview runtime

- **WHEN** the product rootfs for this change is built and deployed
- **THEN** the required GStreamer shared libraries and RTSP/RTP plugins SHALL be present
- **AND** Rockchip MPP decode integration SHALL be available
- **AND** the eLinux video player plugin SHALL be registered for the App
- **AND** GStreamer core version SHALL be ≥ 1.28.5

#### Scenario: Product image contains its video texture plugin

- **WHEN** `build-rootfs` is built and deployed
- **THEN** `flutter-wayland-client` SHALL be linked against the eLinux video player plugin
- **AND** `libvideo_player_plugin.so` and the shared GStreamer/MPP runtime SHALL be installed
- **AND** the App SHALL not replace the eLinux platform implementation with a DRM-only video player

#### Scenario: Local relay stream produces a Flutter video texture

- **WHEN** MediaMTX is running and `rtsp://127.0.0.1:8554/camera/pr1` is readable
- **AND** the App initializes its preview controller
- **THEN** the plugin SHALL create a video texture and deliver moving frames to the Flutter widget

#### Scenario: Host build remains usable without the device plugin

- **WHEN** the App runs on a host/emulator without the device GStreamer plugin
- **THEN** the preview wrapper SHALL fail softly or use a host stub
- **AND** Settings navigation MUST remain usable

### Requirement: Rootfs ships overlay-pinned GStreamer ≥ 1.28.5

The lws_hmi product rootfs SHALL include the GStreamer/MPP live preview and recording runtime built from the overlay-pinned GStreamer stack required by `buildroot-gstreamer-security` (core and co-versioned plugins at least **1.28.5**), not the vendor SDK default of **1.22.9**. Functional presence requirements for RTSP preview, MPP decode, eLinux video player plugin, and MP4 remux remain in force.

#### Scenario: rootfs GStreamer version is pinned

- **WHEN** a product rootfs built after this change is inspected
- **THEN** `gst-inspect-1.0 --version` or `libgstreamer-1.0.so` reports the overlay-pinned version ≥ 1.28.5 (not `1.22.9`)

### Requirement: Product image includes encoded RTSP recording runtime

The product GStreamer runtime SHALL include TCP RTSP/RTP depayloading, H.264 and
H.265 parsers, and ISO MP4/QuickTime mux support required by the HAL recorder.
Recording SHALL remux encoded video without requiring a second decode path.

#### Scenario: RTSP recording can finalize MP4

- **WHEN** HAL records a supported PR0 stream to an `.mp4` destination
- **THEN** `rtspsrc`, the matching RTP depay/parser elements, `qtmux`/equivalent,
  and `filesink` SHALL be available
- **AND** stopping through EOS SHALL produce a finalized non-empty MP4

### Requirement: Image includes MTP gadget userspace for OTG mtp mode

The lws-hmi Buildroot configuration SHALL include the kernel and userspace pieces required to run USB **MTP** gadget mode for `usb-otg-mtp` (FunctionFS/configfs MTP and/or the selected MTP responder package such as umtprd, as decided in implementation). Shipping the image MUST NOT omit MTP deps while advertising `mode=mtp`.

#### Scenario: MTP binary present on rootfs

- **WHEN** `verify-rootfs-overlay` / rootfs checks run after this change
- **THEN** the chosen MTP responder (or documented unit/helper path) is present on the rootfs used by ynh960

### Requirement: Factory artifact named factory.img includes oem

`make build-img` SHALL produce `output/firmware/<APP>/<factory_sku>/factory.img` for the resolved `APP` (default `lws_hmi`) and `FACTORY_SKU`, packaging loader, uboot from `prebuilt/bootloader/<uboot_id>/`, misc, dual FIT, rootfs from `output/firmware/<APP>/rootfs.img`, and **oem** when `oem.img` is present for the resolved `OEM_ID`. A sibling `manifest.txt` SHALL record `app`, `uboot_id`, `oem_id`, and git/build identity. During migration, `output/firmware/update.img` SHALL remain usable as a symlink or copy of the selected/default APP + sku's `factory.img` so existing flash defaults keep working.

#### Scenario: build-img writes per-APP per-sku factory.img

- **WHEN** `APP=lws_hmi` and `FACTORY_SKU=ynh960-p800` and `make build-img` succeeds
- **THEN** `output/firmware/lws_hmi/ynh960-p800/factory.img` and `manifest.txt` exist

#### Scenario: flash uses FACTORY_SKU and APP

- **WHEN** the operator sets `FACTORY_SKU=ynh960-p800` and `APP=lws_hmi` (or defaults) for `make flash`
- **THEN** the flash path SHALL target that APP+sku's `factory.img` (or the compatible `update.img` symlink to it)

### Requirement: Host SDK workflow includes trim before overlay

The host build documentation and Make help SHALL describe the owned-SDK workflow: extract vendor volumes into `linux-sdk/`, optionally or by default after extract run `trim-linux-sdk`, then `apply-overlay`, then kernel/rootfs builds. On macOS Docker volume builds, documentation SHALL require volume init or sync after trim so deleted vendor trees are not retained in the volume.

#### Scenario: make help lists trim and check

- **WHEN** a developer runs `make help`
- **THEN** help text includes `trim-linux-sdk` and `check-linux-sdk` (or equivalent names)

#### Scenario: README documents trim after extract

- **WHEN** a developer follows first-time Linux SDK setup in README
- **THEN** the documented sequence includes trimming (or `TRIM=1` extract) before relying on daily `apply-overlay` / build targets

### Requirement: apply-overlay keeps third-party packages on overlay path

`make apply-overlay` MUST continue to sync custom and third-party Buildroot packages from `overlay/buildroot/package/` (and related third-party pins) into the SDK. Platform kernel/device steps MAY no-op when the owned-tree marker is present, but package overlay injection MUST NOT be removed or relocated into the committed monorepo as part of W3.

#### Scenario: flutter package sync still runs

- **WHEN** `make apply-overlay` runs on an owned (trimmed) tree
- **THEN** overlay Flutter / libserialport / bluez-alsa / font package recipes are still copied into the SDK Buildroot package directories

### Requirement: Multi-configuration FIT packaging for family Image

The lws-hmi kernel packaging path SHALL generate dual A/B FITs using a multi-configuration ITS that supports multiple board FDTs sharing one `Image`. Lunch/board config MAY keep a default DTS of `ynh960` for validation, but MUST NOT permanently encode “exactly one anonymous `fdt`/`conf` pair” as the only supported FIT shape. Emulator publication of a bare `Image` alongside FITs remains required.

#### Scenario: build-kernel emits multi-conf-capable FITs

- **WHEN** `make build-kernel` completes after this change
- **THEN** `output/firmware/boot.img` and `boot_b.img` SHALL be FIT images whose configurations are named per board inventory (default `ynh960`)
- **AND** a bare `Image` SHALL still be published for the P3.2 emulator path

### Requirement: Product /opt/hmi MUST NOT contain Flutter JIT snapshot blobs

The product rootfs HMI bundle under `/opt/hmi` SHALL be release AOT layout (`lib/libapp.so` + `data/flutter_assets` assets). It MUST NOT contain Flutter JIT artifacts `kernel_blob.bin`, `isolate_snapshot_data`, or `vm_snapshot_data` under `data/flutter_assets/`. Because Buildroot overlay rsync into the incremental `target/` tree does not delete overlay orphans, the board `post-build.sh` (BR2_ROOTFS_POST_BUILD_SCRIPT) SHALL explicitly remove those paths when present before packing `rootfs.img`. `scripts/verify-rootfs-overlay.sh` SHALL fail if any of those files remain in the staging `target/` after `make build-rootfs`.

#### Scenario: Stale kernel_blob purged on build-rootfs

- **WHEN** Buildroot `target/opt/hmi/data/flutter_assets/kernel_blob.bin` exists from a prior incremental build and `make build-rootfs` runs with the product post-build script
- **THEN** the packed rootfs staging tree MUST NOT contain that file

#### Scenario: verify rejects JIT leftovers

- **WHEN** `verify-rootfs-overlay.sh` inspects a staging `target/` that still has `/opt/hmi/data/flutter_assets/kernel_blob.bin` (or `isolate_snapshot_data` / `vm_snapshot_data`)
- **THEN** verification MUST report FAIL for the release `/opt/hmi` layout

#### Scenario: debug-app path unchanged

- **WHEN** the operator builds or deploys a debug HMI via `make debug-app` / debug staging
- **THEN** that path MAY still include `kernel_blob.bin` outside the product rootfs overlay bake (post-build applies only to Buildroot `target/` for image packing)

### Requirement: Product /opt/hmi MUST NOT duplicate system librknnrt.so

The product rootfs SHALL provide Rockchip RKNN runtime at `/usr/lib/librknnrt.so` (via `make fetch-rknn-rt` / overlay). The HMI App tree under `/opt/hmi/lib/` MUST NOT contain `librknnrt.so`. Board `post-build.sh` SHALL remove any leftover `/opt/hmi/lib/librknnrt.so*` from the incremental Buildroot `target/` before packing `rootfs.img`. `scripts/verify-rootfs-overlay.sh` SHALL fail if `/opt/hmi/lib/librknnrt.so` is present.

#### Scenario: post-build purges App-bundled RKNN leftover

- **WHEN** `target/opt/hmi/lib/librknnrt.so` exists from a prior bake and `make build-rootfs` runs
- **THEN** the staging tree MUST NOT contain that file after post-build

#### Scenario: verify rejects duplicate

- **WHEN** `verify-rootfs-overlay.sh` finds `/opt/hmi/lib/librknnrt.so`
- **THEN** verification MUST report FAIL

### Requirement: Product rootfs ships hwdb.bin without hwdb.d sources

The product rootfs SHALL ship the compiled systemd hardware database at `/usr/lib/udev/hwdb.bin` when `BR2_PACKAGE_SYSTEMD_HWDB` is enabled. It MUST NOT ship `*.hwdb` source files under `/usr/lib/udev/hwdb.d/` or `/etc/udev/hwdb.d/` in the packed image. Because Buildroot installs both the compiled binary and the text sources, the board `post-build.sh` (BR2_ROOTFS_POST_BUILD_SCRIPT) SHALL remove those `*.hwdb` sources after package install and before packing `rootfs.img`. The image MUST NOT place a compiled database at `/etc/udev/hwdb.bin` solely as a byproduct of this trim. `scripts/verify-rootfs-overlay.sh` SHALL fail if `/usr/lib/udev/hwdb.bin` is missing, or if any `*.hwdb` remains under `usr/lib/udev/hwdb.d` or `etc/udev/hwdb.d` in the staging `target/`.

#### Scenario: post-build drops hwdb sources

- **WHEN** Buildroot has installed `/usr/lib/udev/hwdb.d/*.hwdb` and `/usr/lib/udev/hwdb.bin`, and `make build-rootfs` runs with the product post-build script
- **THEN** the packed rootfs staging tree MUST contain `/usr/lib/udev/hwdb.bin` and MUST NOT contain any `*.hwdb` under `/usr/lib/udev/hwdb.d/` or `/etc/udev/hwdb.d/`

#### Scenario: verify rejects leftover hwdb sources

- **WHEN** `verify-rootfs-overlay.sh` inspects a staging `target/` that still has any `*.hwdb` under `usr/lib/udev/hwdb.d` or `etc/udev/hwdb.d`
- **THEN** verification MUST fail

#### Scenario: verify rejects missing hwdb.bin

- **WHEN** `verify-rootfs-overlay.sh` inspects a staging `target/` that lacks `/usr/lib/udev/hwdb.bin` while the product profile enables systemd hwdb
- **THEN** verification MUST fail

### Requirement: Rootfs verify optional factory_test app tree

When repo `app/factory_test/pubspec.yaml` exists, `scripts/verify-rootfs-overlay.sh` after `make build-rootfs` SHALL require staging `target/opt/factory_test/lib/libapp.so` and `target/opt/factory_test/data/flutter_assets` release assets. That tree MUST NOT contain `libflutter_engine.so` or `icudtl.dat` under the app prefix, and MUST NOT contain Flutter JIT blobs (`kernel_blob.bin`, `isolate_snapshot_data`, `vm_snapshot_data`) under `data/flutter_assets/`. When `app/factory_test` is absent, verification MUST NOT require `/opt/factory_test`.

#### Scenario: factory_test present in source and rootfs

- **WHEN** `app/factory_test/pubspec.yaml` exists and `verify-rootfs-overlay.sh` inspects a staging `target/` after `make build-rootfs`
- **THEN** verification MUST PASS only if `/opt/factory_test` has release AOT layout without engine/ICU/JIT orphans

#### Scenario: factory_test source absent

- **WHEN** `app/factory_test` does not exist
- **THEN** verification MUST NOT fail solely due to missing `/opt/factory_test`

### Requirement: Kernel FIT ships pinned 6.1 LTS version

Product firmware images that include the kernel FIT (`boot.img` / `boot_b.img`) SHALL embed a Linux kernel whose release string is the documented 6.1.y LTS pin from `kernel-61-lts-security` (minimum `6.1.180`, not `6.1.99`). Rootfs module directories shipped with that image MUST match the same kernel ABI/release as the FIT.

#### Scenario: uname after factory or upgrade image

- **WHEN** a ynh960 board boots a firmware image built after this change (via flash or A/B upgrade)
- **THEN** `uname -r` reports the pinned `6.1.<tip>` and loadable product modules match that release

### Requirement: Product rootfs MUST NOT ship Wi-Fi/BT firmware kitchen sink

The shared product rootfs SHALL NOT install the multi-vendor Rockchip/Innohi Wi‑Fi/BT firmware dump (e.g. bulk `fw_bcm*`, `fw_syn*`, unrelated `.hcd`, Realtek trees) into `/usr/lib/firmware` or `/vendor/etc/firmware`. Combo module firmware for product boards SHALL come from the OEM radio pack. Kernel modules for the onboard AIC radio MAY remain on the rootfs/module path as today. `verify-rootfs-overlay.sh` (or equivalent) SHALL fail if forbidden kitchen-sink patterns are present after `make build-rootfs`.

#### Scenario: build-rootfs has no fw_bcm kitchen sink

- **WHEN** `make build-rootfs` completes after this change is implemented
- **THEN** staging `target/usr/lib/firmware` MUST NOT contain `fw_bcm*` blobs from the multi-chip dump
- **AND** AIC8800D80 product firmware MUST NOT be required to live under rootfs for Wi‑Fi bring-up success

### Requirement: Product HMI does not ship ffmpeg for frame extract

After `gstreamer-frame-extract` is implemented, the product HMI image / App bundle SHALL NOT require `/opt/hmi/bin/ffmpeg` for process-video covers or AI Vision offline frame samples. Rootfs GStreamer MUST provide the elements needed for the documented extract helper pipeline.

#### Scenario: Bundle without product ffmpeg

- **WHEN** `make build-app` produces `/opt/hmi` for a release tip with frame-extract cutover complete
- **THEN** product cover and AI sample paths MUST work without installing ffmpeg into `/opt/hmi/bin`
- **AND** host-only measurement scripts MAY still use a separate ffmpeg binary outside the product HMI contract

