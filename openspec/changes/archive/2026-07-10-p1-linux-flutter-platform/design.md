## Context

lws-hmi wraps the Rockchip RK3566/RK3568 SDK in Docker and applies ynh960 board overlays. The upstream reference Buildroot defconfig (`rockchip_rk3566_rk3568_defconfig`) targets an EVB demo system (~1.5–2 GB rootfs) with Weston, Chromium, camera, and benchmark packages — unsuitable for a full-screen flutter-pi HMI.

The repo already scaffolds Plan A systemd (`lws_hmi_systemd.config`, `hmi.service`, `06-lws-hmi-systemd.sh`), display overlays (LCD/MIPI params), and a defconfig skeleton (`overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig`). **P1** completed the wiring: enable flutter-pi in Buildroot, trim EVB packages, add boot splash, build Hello World on the host, deploy to `/opt/hmi`, and optimize boot KPI on ynh960 hardware.

**Constraints:**
- flutter-pi links **`libsystemd.so`** (`sd_event` event loop); this does **not** require systemd as PID 1 at runtime. P1 ships **`BR2_INIT_SYSTEMD=y`** anyway (Buildroot packages libsystemd with the systemd recipe, Rockchip SDK path, unit-based service layout). Busybox-init + libsystemd-only is **方案 B** (experimental), out of P1～P5 scope.
- Flutter app is **not** compiled inside Buildroot; host cross-compiles AOT and overlays into rootfs.
- Baseline board: **ynh960** (**RK3566**, 800×1280 MIPI, `lcd0_rotation=90`). Product line ynh960/961/962 shares **one firmware image** in principle; P1–P5 develop and validate on ynh960 with a single `ynh960_defconfig` lunch target.
- KPI: power-on → Flutter home first frame **≤ 10 s** on eMMC; boot splash visible before KPI end. **Measured ~8.4 s** on ynh960 eMMC (2026-07).

## Goals / Non-Goals

**Goals:**
- Ship a bootable Buildroot image via `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"` with ~220–400 MB rootfs.
- Include platform stack: Mali GPU, flutter-pi, Wi‑Fi/BT userland (boot-deferred), powermanager, Chinese fonts.
- Auto-start `flutter-pi --release -o landscape_left /opt/hmi` via `hmi.service` after `local-fs.target` only.
- Show boot splash logo from U-Boot/kernel until flutter-pi home frame replaces it (~2 s to logo).
- Provide reproducible host build script for Hello World AOT + assets (meta-flutter layout).
- Stable board poweroff via pwrkey without Mali DRM teardown oops.

**Non-Goals:**
- Modbus, GPIO demo, AI (`libai.so`), FrostUI/IME, MediaMTX auto-start, GStreamer in rootfs, eth0 camera scripts, cloud/network UI, OTA.
- Per-SKU firmware splits for ynh961/ynh962 (product line targets one shared image).
- Recovery partition (`RK_RECOVERY` not set for P1).
- Self-compiled U-Boot (use Innohi/SDK prebuilt chain).

## Decisions

### 1. Defconfig composition — single `lws_hmi` defconfig with overlay fragments

**Choice:** Copy `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig` into SDK `buildroot/configs/` and copy chip fragments into `buildroot/configs/rockchip/chips/`. P1 enables `#include "chips/lws_hmi_flutter.config"`. P3+ fragments (`lws_hmi_npu`, `lws_hmi_gst_*`, `lws_hmi_mediamtx`, `lws_hmi_platform`) stay commented until uncommented in git.

**Rationale:** Matches plan §4; fragments already exist for base/systemd/network/npu. OneStepping EVB defconfig in place would be harder to maintain.

**Alternatives considered:**
- Fork entire upstream defconfig inline — rejected (merge pain on SDK updates).
- Separate defconfig per board SKU — rejected for product line (ynh960/961/962 share one firmware; develop on ynh960 defconfig).

### 2. EVB package removal — omission, not negative Kconfig in fragments

**Choice:** Simply **do not `#include`** weston, chromium, camera, benchmark, test, gst/audio, can/pci, ntfs/exfat configs. Use `lws_hmi_base.config` to unset adbd/getty.

**Rationale:** Rockchip defconfigs compose via `#include`; omitting files is cleaner than overriding dozens of `BR2_PACKAGE_*=y` lines.

### 3. flutter-pi Buildroot integration — overlay prebuilt packages

**Choice:** Overlay `overlay/buildroot/package/flutter-pi/` and `flutter-engine/` with **prebuilt-only** `.mk` files. `build-rootfs` copies from `prebuilt/flutter-pi/<37bd977>/` and `prebuilt/flutter-engine/<3.24.4>/`. Host `make build-flutter-pi` / `make build-flutter-engine` populates prebuilt; `make check-prebuilt` gates `build-rootfs`. `lws_hmi_flutter.config` enables `BR2_PACKAGE_FLUTTER_PI=y` plus dependencies (`libdrm`, `libgbm`, `rockchip-mali`, `fontconfig`, `libinput`) and **meta-flutter** layout.

**Rationale:** Avoids hours-long engine compile in every rootfs build; version pins in `overlay/buildroot/flutter-*.version`. SDK in-tree package sources remain reference for `make build-flutter-pi` host builds.

**Alternatives considered:**
- Compile flutter-pi in Buildroot every rootfs build — rejected (build time).
- SDK in-tree compile only — rejected (Docker build time, prebuilt-first is faster iteration).

### 4. Flutter app deployment — meta-flutter rootfs overlay

**Choice:** Place release artifacts under `overlay/board/.../lws-hmi-fs-overlay/opt/hmi/` via `make build-app` (`flutterpi_tool build --arch=arm64 --release`). Layout:

```
/opt/hmi/lib/libapp.so
/opt/hmi/lib/libflutter_engine.so
/opt/hmi/data/icudtl.dat
/opt/hmi/data/flutter_assets/
```

`hmi.service` ExecStart: `/usr/bin/flutter-pi --release -o landscape_left /opt/hmi`

**Rationale:** Matches Buildroot `FILESYSTEM_LAYOUT=meta-flutter`; `flutterpi_tool` produces the same layout as engine packaging.

**Alternatives considered:**
- Legacy flat layout (`app.so` at bundle root) — superseded by meta-flutter.
- oem partition mount — deferred (extra fstab/mount latency per plan §14.3).

### 5. Boot splash — SDK FIT boot.its + kernel early logo

**Choice:** Use **`board/logo/splash_icon.png`** (512×512 PNG) as canonical source. `scripts/build-boot-logo.sh` converts to **`board/logo/logo.bmp`** for Rockchip resource partition. ynh960 uses SDK **`boot.its`** FIT (`RK_BOOT_FIT_ITS_NAME="boot.its"`), not self-compiled U-Boot. Kernel early logo via ynh960 DTS + `lws-hmi-ynh960-display.config`.

**Rationale:** Innohi-confirmed path; U-Boot self-compile skipped (A-1). Logo holds until `Freeing drm_logo` at flutter-pi first frame.

### 6. systemd Plan A — extended boot chain beyond hmi.service

**Choice:** Post-hook (`06-lws-hmi-systemd.sh`) enables:
- `param-update.service` (sysinit — display params)
- `mainserver.service` (Innohi MainServer display daemon, `Before=hmi.service`)
- `lws-hmi-performance.service` (CPU/DMC/GPU `performance` governors, `Before=hmi.service`)
- `lws-hmi-pwrkey-poweroff.service` (board power key → `shutdown.sh`)
- `hmi.service` (`Nice=-5`, `After=lws-hmi-performance.service`)

Disables at boot: mediamtx, sshd (+ socket), bluetooth, wifibt-init, wpa_supplicant, network, log-guardian. Masks `systemd-network-generator`. `08-lws-hmi-systemd-finalize.sh` undoes SDK post-hook re-enables.

**Rationale:** Boot KPI optimization on hardware showed network/Wi‑Fi at boot unnecessary for Hello World; performance governors and MainServer needed for stable display handoff. See `docs/boot-kpi-optimization.md`.

### 7. Board SDK config — extend ynh960_defconfig

**Choice:** Add to `board/ynh960_defconfig`:
```
RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"
RK_BOOT_FIT_ITS_NAME="boot.its"
RK_KERNEL_CFG_FRAGMENTS="lws-hmi-ynh960-display.config lws-hmi-kernel-trim.config"
RK_WIFIBT=y
```
(`RK_BUILDROOT_CFG` resolves to `rockchip_rk3566_rk3568_lws_hmi` via SDK Kconfig.)

**Rationale:** Plan §4 / §13 compile flow; kernel trim and display fragments applied at build time.

### 8. Flutter project layout — `app/hmi`

**Choice:** Standard `flutter create` app (renamed from `lws_hmi_app`) with `flutterpi_tool` per upstream docs. Minimal home: centered "Hello, lws-hmi" text, no plugins on first frame (KPI §14.3 C). Engine pin: Flutter **3.24.4**.

**Rationale:** Keeps `libapp.so` small; defers FrostUI and network plugins to P4/P5.

### 9. USB firmware flash — Makefile + upgrade_tool (macOS host)

**Choice:** Host-side `scripts/flash-usb.sh` invoked by Makefile targets; Rockchip **upgrade_tool** v2.44 vendored under `tools/upgrade_tool/`.

| Make target | upgrade_tool / adb | PDF |
|-------------|-------------------|-----|
| `make devices` | `ld` + `adb devices` | §1.1 |
| `make bootloader` | `adb reboot loader` | — |
| `make loader` | `ul MiniLoaderAll.bin` | §1.3 |
| `make upgrade` / `make flash` | `uf update.img` | §1.6 |

Multi-device: `upgrade_tool -s LocationID` (§1.11), resolved from `SERIAL=`. macOS: `make build-img` auto-exports `output/firmware/` to host.

**Rationale:** Builds run in Docker; flash runs on host USB.

### 10. Stable poweroff — SysRq path, no HMI stop

**Choice:** `systemctl` wrapper + `pwrkey-poweroff.sh` → `shutdown.sh` → `sync` + SysRq `s/u/o` (remount-ro, poweroff). Do **not** `systemctl stop hmi.service` before poweroff (triggers Mali DRM oops on ynh960).

**Rationale:** Verified on hardware (P0-8). `systemd-logind` remains disabled.

### 11. RKNPU2 deferred to P3

**Choice:** `lws_hmi_npu.config` exists but is **not** `#include`d in P1 defconfig. `make build-runtime-deps` still prefetches `prebuilt/rknn-rt` for later phases. Uncomment `#include "chips/lws_hmi_npu.config"` when P3 lands.

**Rationale:** Leaner P1 rootfs; NPU runtime not needed until `libai.so` smoke test.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| flutter-pi untested on RK356x Mali vs Pi VC4 | Pin 37bd977 + Flutter 3.24.4; validated on ynh960; `-o landscape_left` confirmed |
| Prebuilt flutter-pi/engine version drift | Version files + `check-prebuilt`; `build-runtime-deps` refreshes |
| Rootfs still >400 MB | `du -sh target` after build; trim unused firmware if needed |
| Boot KPI >10 s on SD card | Document eMMC as KPI target; measured ~8.4 s on eMMC |
| Splash → flutter-pi handoff flash | Logo holds until first Flutter frame; ~1 s EGL init after `Started flutter-pi` |
| Mali DRM oops on poweroff | SysRq poweroff path; never stop hmi before shutdown |
| SDK update breaks overlay paths | Fragments in lws-hmi repo; `scripts/apply-overlay.sh` re-applies on setup |

## Migration Plan

1. `make setup` — apply overlays (defconfig, flutter packages, board config).
2. Build Hello World on host → `make build-app` → copy to fs-overlay `/opt/hmi`.
3. `make lunch` → ynh960 → `make build-rootfs` → `make build-img` (auto-export on macOS).
4. **Flash (host USB):** `make devices` → `SERIAL=… make bootloader` → `make flash`.
5. Verify: `/usr/lib/lws-hmi/boot-verify.sh`, splash, home frame, `systemd-analyze critical-chain hmi.service`.
6. Rollback: revert `RK_BUILDROOT_BASE_CFG` to upstream defconfig and rebuild.

## Open Questions

_(All P1 open questions resolved during implementation.)_

- flutter-pi / Flutter engine pin: **3.24.4** / **37bd977** — validated on ynh960.
- U-Boot logo packaging: SDK **`boot.its`** FIT + resource partition with `logo.bmp`.
- Touch input on ynh960 for P1 — libinput present; Hello World does not require touch interaction.

## P1 Acceptance Summary

| Metric | Target | Result |
|--------|--------|--------|
| Boot splash | ≤2 s | ~2 s |
| First home frame | ≤10 s (eMMC) | ~8.4 s |
| `boot-verify.sh` | ALL PASS | PASS |
| `verify-rootfs-overlay.sh` | PASS | PASS |
| EVB packages absent | weston/chromium/adbd | confirmed |
| Platform stack (§6.5) | flutter-pi, RKNPU runtime, wpa, LCD params | confirmed (`env-verify.sh`) |
| Auto-start HMI | no manual systemctl | confirmed |

Full KPI log: `docs/boot-kpi-optimization.md` §6.
