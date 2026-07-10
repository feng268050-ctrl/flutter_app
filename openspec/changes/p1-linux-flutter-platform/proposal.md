## Why

lws-hmi must replace the Rockchip EVB reference rootfs (Weston, Chromium, camera demos) with a lean **Buildroot + flutter-pi** HMI platform before any product features (Modbus, AI, FrostUI, business pages) can land. **P1** establishes the minimum viable Linux image and a **Hello World** Flutter app on **ynh960** (**RK3566**), proving display, GPU, systemd boot chain, and flutter-pi end-to-end — aligned with `docs/flutter-pi-hmi-plan.md` §1 / §12. The ynh960/961/962 product line targets **one shared firmware image**; P1–P5 develop and validate on ynh960 without per-SKU defconfig forks.

## What Changes

- Add and wire **`rockchip_rk3566_rk3568_lws_hmi_defconfig`** into the SDK Buildroot tree, composing existing `lws_hmi_{base,systemd,network,npu}.config` overlays plus **flutter-pi** / Mali / libdrm.
- **Remove** Weston, Chromium, camera, benchmark, test, adbd, and other EVB demo packages from the HMI defconfig (not included via `#include`).
- Add **Buildroot flutter-pi package** (or external recipe) and enable it in `lws_hmi_flutter.config`.
- Integrate **boot splash logo** (U-Boot / kernel early logo) for ynh960 MIPI 800×1280 rotation.
- Deploy a **Flutter Hello World** release build (`app.so` + assets) to `/opt/hmi` via rootfs overlay.
- Enable **`hmi.service`** (already scaffolded) via post-build hook; keep mediamtx / sshd / bluetoothd **disabled**.
- Set **`RK_BUILDROOT_CFG=rockchip_rk3566_rk3568_lws_hmi`** and **`RK_RECOVERY=n`** on ynh960 board config for P1 builds.
- Create **`app/lws_hmi`** Flutter project with flutter-pi target configuration and CI/build script for cross-compiling AOT.
- Add **P1 runtime dependency prep** via `make build-all-deps`: Flutter, **GStreamer/MPP**, MediaMTX, OpenCV, RKNN runtime (`prebuilt/` + Buildroot); host dev via `build-dev-deps` (Flutter SDK, RKNN-Toolkit only). Product **features** (libai UI, MediaMTX auto-start) still phased P3–P5.

**Non-goals (P1)**: Modbus/GPIO (P2), libai.so (P3), FrostUI/IME (P4), MediaMTX/video/network UI (P5), eth0 camera scripting, business pages.

## Capabilities

### New Capabilities

- `buildroot-lws-hmi-image`: Lean Buildroot defconfig, chip Kconfig fragments, flutter-pi/Mali/RKNPU2/Wi‑Fi/BT stack, SDK integration, and EVB package removal.
- `boot-splash-display`: U-Boot and kernel early logo on ynh960 MIPI panel; seamless handoff to flutter-pi without prolonged black screen.
- `hmi-systemd-boot`: Plan A minimal systemd, `hmi.service` auto-start after `local-fs.target`, journald volatile, post-hook unit enable/disable, boot KPI ≤10 s to first home frame.
- `flutter-hello-world-app`: Flutter project, flutter-pi release build, deployment layout under `/opt/hmi`, acceptance on target hardware.

### Modified Capabilities

_(none — no existing openspec specs in this repo)_

## Impact

- **Buildroot / SDK**: New defconfig, flutter-pi package, `lws_hmi_flutter.config`, board logo assets, ynh960 `RK_BUILDROOT_CFG` update.
- **Overlay**: Rootfs overlay for `/opt/hmi` Hello World artifacts; possible U-Boot logo under `board/logo/`.
- **App**: New `app/lws_hmi/` Flutter project and build scripts (host-side, not Buildroot-compiled).
- **Host flash**: `scripts/flash-usb.sh`, Makefile `devices` / `bootloader` / `loader` / `upgrade`; `tools/upgrade_tool/` (Rockchip upgrade_tool v2.44).
- **Existing overlays reused**: `lws_hmi_{base,systemd,network,npu}.config`, `hmi.service`, `06-lws-hmi-systemd.sh`, LCD/MIPI display overlay.
- **Downstream phases**: P2–P5 depend on P1 display stack, systemd boot chain, and `/opt/hmi` deployment pattern.
