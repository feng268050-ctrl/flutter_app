## Context

lws-hmi wraps the Rockchip RK3566/RK3568 SDK in Docker and applies ynh960 board overlays. The upstream reference Buildroot defconfig (`rockchip_rk3566_rk3568_defconfig`) targets an EVB demo system (~1.5–2 GB rootfs) with Weston, Chromium, camera, and benchmark packages — unsuitable for a full-screen flutter-pi HMI.

The repo already scaffolds Plan A systemd (`lws_hmi_systemd.config`, `hmi.service`, `06-lws-hmi-systemd.sh`), display overlays (LCD/MIPI params), and a defconfig skeleton (`overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig`). **P1** completes the wiring: enable flutter-pi in Buildroot, trim EVB packages, add boot splash, build Hello World on the host, and deploy to `/opt/hmi`.

**Constraints:**
- flutter-pi requires **libsystemd** (Buildroot `BR2_PACKAGE_SYSTEMD`); busybox-init replacement is out of scope.
- Flutter app is **not** compiled inside Buildroot; host cross-compiles AOT and overlays into rootfs.
- Baseline board: **ynh960 (RK3566)**, 800×1280 MIPI, `lcd0_rotation=90`.
- KPI: power-on → Flutter home first frame **≤ 10 s** on eMMC; boot splash visible before KPI end.

## Goals / Non-Goals

**Goals:**
- Ship a bootable Buildroot image via `RK_BUILDROOT_CFG=rockchip_rk3566_rk3568_lws_hmi` with ~220–400 MB rootfs.
- Include platform stack: Mali GPU, flutter-pi, RKNPU2 runtime (no example), Wi‑Fi/BT, powermanager, Chinese fonts.
- Auto-start `flutter-pi --release /opt/hmi` via `hmi.service` after `local-fs.target` only.
- Show boot splash logo from U-Boot/kernel until flutter-pi home frame replaces it.
- Provide reproducible host build script for Hello World AOT + assets.

**Non-Goals:**
- Modbus, GPIO demo, AI (`libai.so`), FrostUI/IME, MediaMTX, GStreamer, eth0 camera scripts, cloud/network UI, OTA.
- RK3568/RK3568B2 board defconfigs (optional smoke only).
- Recovery partition (`RK_RECOVERY=n` for P1).

## Decisions

### 1. Defconfig composition — single `lws_hmi` defconfig with overlay fragments

**Choice:** Copy `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig` into SDK `buildroot/configs/` and copy chip fragments into `buildroot/configs/rockchip/chips/`. Enable `#include "chips/lws_hmi_flutter.config"` (new).

**Rationale:** Matches plan §4; fragments already exist for base/systemd/network/npu. OneStepping EVB defconfig in place would be harder to maintain.

**Alternatives considered:**
- Fork entire upstream defconfig inline — rejected (merge pain on SDK updates).
- Separate defconfig per SoC — rejected (3566/3568/3568B2 share one rootfs per plan §3.0).

### 2. EVB package removal — omission, not negative Kconfig in fragments

**Choice:** Simply **do not `#include`** weston, chromium, camera, benchmark, test, gst/audio, can/pci, ntfs/exfat configs. Use `lws_hmi_base.config` to unset adbd/getty.

**Rationale:** Rockchip defconfigs compose via `#include`; omitting files is cleaner than overriding dozens of `BR2_PACKAGE_*=y` lines.

### 3. flutter-pi Buildroot integration — in-tree package under lws-hmi overlay

**Choice:** Add `overlay/buildroot/package/flutter-pi/` (Config.in, `.mk`, version pin matching a known from-source build) and `lws_hmi_flutter.config` enabling `BR2_PACKAGE_FLUTTER_PI=y` plus dependencies (`libdrm`, `libgbm`, `rockchip-mali`, `fontconfig`, `libinput`).

**Rationale:** Plan §9 recommends P1 packages flutter-pi binary in Buildroot; host only builds the Dart AOT bundle. Pin engine version in package and document in `app/` README.

**Alternatives considered:**
- Prebuilt binary drop in overlay only — rejected (no version tracking, harder CI).
- Build flutter engine in Buildroot — rejected (build time, complexity).

### 4. Flutter app deployment — rootfs overlay for P1

**Choice:** Place release artifacts under `overlay/board/.../lws-hmi-fs-overlay/opt/hmi/` (or `lws-hmi-app/` subtree copied by post-hook). `hmi.service` ExecStart unchanged: `/usr/bin/flutter-pi --release /opt/hmi`.

**Rationale:** Simplest P1 path; OTA via `/oem/hmi` deferred to P5.

**Alternatives considered:**
- oem partition mount — deferred (extra fstab/mount latency per plan §14.3).

### 5. Boot splash — U-Boot logo + kernel early logo

**Choice:** Use **`board/logo/splash_icon.png`** (512×512 PNG, product source asset) as the canonical boot logo. During image build, convert it to **`board/logo/logo.bmp`** (24-bit BMP for Rockchip U-Boot resource packaging — scale/center on 800×1280 canvas with rotation aligned to ynh960 MIPI `@ 90°`). Wire the generated BMP via existing ynh960 board logo mechanism in SDK. Optionally reuse the same PNG in Flutter app assets for in-app splash consistency. Enable kernel `CONFIG_LOGO` / Rockchip bootlogo if not already on ynh960 DTS profile.

**Asset layout:**

```
board/logo/
  splash_icon.png   # source (committed)
  logo.bmp          # generated at build time (gitignored or produced by scripts/build-boot-logo.sh)
```

**Rationale:** Plan §5.2; no Plymouth/Weston. Single checked-in source avoids duplicate art; BMP is a build artifact because U-Boot expects it. flutter-pi takes over same DRM connector — minimize black flash.

### 6. systemd Plan A — reuse existing units and post-hook

**Choice:** Keep `hmi.service` as-is (`After=local-fs.target` only). Post-hook enables hmi, disables mediamtx/sshd/bluetooth. journald volatile overlay already present.

**Rationale:** Already implemented in repo; matches KPI requirements §6.4.

### 7. Board SDK config — extend ynh960_defconfig

**Choice:** Add to `board/ynh960_defconfig` (via overlay apply):
```
RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"
# RK_RECOVERY is not set
RK_WIFIBT=y
```
(`RK_BUILDROOT_CFG` resolves to `rockchip_rk3566_rk3568_lws_hmi` via SDK Kconfig.)

**Rationale:** Plan §4 / §13 compile flow.

### 8. Flutter project layout — `app/lws_hmi_app`

**Choice:** Standard `flutter create` app with flutter-pi custom device / `flutterpi_tool` per upstream docs. Minimal home: centered "Hello, lws-hmi" text, no plugins on first frame (KPI §14.3 C).

**Rationale:** Keeps `app.so` small; defers FrostUI and network plugins to P4/P5.

### 9. USB firmware flash — Makefile + upgrade_tool (macOS host)

**Choice:** Host-side `scripts/flash-usb.sh` invoked by Makefile targets; Rockchip **upgrade_tool** v2.44 for macOS (`~/Downloads/upgrade_tool_v2.44_for_mac`, overridable via `LWS_HMI_UPGRADE_TOOL_DIR`). Commands follow `命令行开发工具使用文档.pdf`:

| Make target | upgrade_tool / adb | PDF |
|-------------|-------------------|-----|
| `make devices` | `ld` + `adb devices` | §1.1 (table: MODE / SERIAL / LocationID / USB) |
| `make bootloader` | `adb reboot loader` | — (RockUSB Loader, not Android `reboot bootloader`) |
| `make loader` | `ul MiniLoaderAll.bin` | §1.3 |
| `make upgrade` | `uf update.img` | §1.6 |

Multi-device: `upgrade_tool -s LocationID` (§1.11). Selection via `SERIAL=` (matches table column; adb + RockUSB SerialNo) or `USB_LOCATION=`. Optional `IMAGE=` overrides default `sdk/output/firmware/update.img`; macOS builds use `make docker-volume-pull` or `LWS_HMI_AUTO_PULL=1` before flash.

**Rationale:** Builds run in Docker; flash runs on host USB. Single `SERIAL` column aligns adb and RockUSB identity on ynh960.

**Alternatives considered:**
- SDK `rkflash.sh` on Linux only — rejected for macOS dev workflow.
- `adb reboot bootloader` — rejected (Android fastboot 0x18d1; upgrade_tool requires RockUSB 0x2207).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| flutter-pi untested on RK356x Mali vs Pi VC4 | Pin known-good flutter-pi + engine tag; validate on ynh960 early; document rotation flags (`front | Test `-o landscape_left` / `-r 90` against ynh960 panel |
| Buildroot flutter-pi package build failure (engine blob) | Start from ardera/flutter-pi Buildroot examples or prebuilt engine tarball in package |
| Rootfs still >400 MB | Run `du -sh target` after first build; trim unused wifibt firmware or font packages if needed |
| Boot KPI >10 s on SD card | Document eMMC as KPI target; SD acceptable for dev only (plan §14.2) |
| Splash → flutter-pi handoff flash | Match resolution/rotation; keep splash until first Flutter frame |
| SDK update breaks overlay paths | Keep fragments in lws-hmi repo; `scripts/apply-overlay.sh` re-applies on setup |

## Migration Plan

1. `make setup` — apply overlays (defconfig, flutter-pi package, board config).
2. Build Hello World on host → `make build-flutter-app` → copy to fs-overlay `/opt/hmi`.
3. `make lunch` → ynh960 → `make build-rootfs` (iterate) → full `make build` when boot splash needed.
4. **Flash (host USB, macOS):** `make devices` → `SERIAL=… make bootloader` (from Android) or MaskROM + hub → `make loader` (if needed) → `make docker-volume-pull` → `make upgrade` (optional `IMAGE=…`).
5. Verify splash, home frame, `systemd-analyze critical-chain hmi.service`.
6. Rollback: revert `RK_BUILDROOT_CFG` to upstream defconfig and rebuild (no data migration in P1).

## Open Questions

- Exact flutter-pi / Flutter engine version pin compatible with current SDK Mali userspace — resolve during package implementation (check ardera releases + RK356x reports).
- Whether ynh960 U-Boot logo packaging uses `logo.bmp` in resource partition or kernel-only splash — confirm against SDK ynh960 board recipe during boot-splash task (source PNG is ready at `board/logo/splash_icon.png`).
- Touch input on ynh960 for P1 — libinput should work if DTS has good touch node; manual tap test optional for Hello World.
