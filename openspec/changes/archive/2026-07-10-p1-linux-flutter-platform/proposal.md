## Why

lws-hmi must replace the Rockchip EVB reference rootfs (Weston, Chromium, camera demos) with a lean **Buildroot + flutter-pi** HMI platform before any product features (Modbus, AI, FrostUI, business pages) can land. **P1** establishes the minimum viable Linux image and a **Hello World** Flutter app on **ynh960** (**RK3566**), proving display, GPU, systemd boot chain, and flutter-pi end-to-end — aligned with `docs/flutter-pi-hmi-plan.md` §1 / §12. The ynh960/961/962 product line targets **one shared firmware image**; P1–P5 develop and validate on ynh960 without per-SKU defconfig forks.

**Status: P1 complete** (2026-07). Hardware acceptance on ynh960 eMMC; boot KPI ~8.4 s to first home frame. Optimization details in `docs/boot-kpi-optimization.md`.

## What Changes

- Add and wire **`rockchip_rk3566_rk3568_lws_hmi_defconfig`** into the SDK Buildroot tree, composing existing `lws_hmi_{base,systemd,network,flutter}.config` overlays plus Mali / libdrm. **P3+ fragments** (`lws_hmi_npu`, `lws_hmi_gst_*`, `lws_hmi_mediamtx`, `lws_hmi_platform`) remain commented out until those phases land.
- **Remove** Weston, Chromium, camera, benchmark, test, adbd, and other EVB demo packages from the HMI defconfig (not included via `#include`).
- Enable **flutter-pi + flutter-engine** via `lws_hmi_flutter.config`; overlay packages install from **prebuilt** only (`prebuilt/flutter-*`), pinned to Flutter **3.24.4** / flutter-pi **37bd977**.
- Integrate **boot splash logo** (SDK `boot.its` FIT + kernel early logo) for ynh960 MIPI 800×1280 rotation.
- Deploy a **Flutter Hello World** release build (meta-flutter layout: `lib/libapp.so` + assets) to `/opt/hmi` via rootfs overlay.
- Enable **Plan A systemd boot chain**: `hmi.service` + Innohi `mainserver.service` + `lws-hmi-performance.service` + `lws-hmi-pwrkey-poweroff.service`; defer Wi‑Fi/BT/network at boot; keep mediamtx / sshd / bluetoothd **disabled**.
- Set **`RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"`** on ynh960 board config for P1 builds (resolves to `rockchip_rk3566_rk3568_lws_hmi`).
- Create **`app/lws_hmi`** Flutter project with `flutterpi_tool` for ARM64 release AOT (meta-flutter bundle).
- Add **P1 runtime dependency prep** via `make build-all-deps`: prebuilt Flutter, GStreamer/MPP, MediaMTX, OpenCV, RKNN runtime (`prebuilt/`); host dev via `build-dev-deps`. Product **features** still phased P2–P5; defconfig `#include` lines gate what actually enters rootfs.
- Add **boot KPI optimization** overlay: `boot-verify.sh`, kernel trim, eMMC noatime, deferred networking, stable pwrkey poweroff.

**Non-goals (P1)**: Modbus/GPIO (P2), libai.so (P3), FrostUI/IME (P4), MediaMTX/video/network UI (P5), eth0 camera scripting, business pages.

## Capabilities

### New Capabilities

- `buildroot-lws-hmi-image`: Lean Buildroot defconfig, chip Kconfig fragments, flutter-pi/Mali/Wi‑Fi/BT stack, prebuilt-first packages, SDK integration, EVB package removal, USB flash tooling.
- `boot-splash-display`: U-Boot FIT + kernel early logo on ynh960 MIPI panel; seamless handoff to flutter-pi without prolonged black screen.
- `hmi-systemd-boot`: Plan A minimal systemd, `hmi.service` auto-start, boot KPI services, journald volatile, post-hook unit enable/disable, boot-verify acceptance, boot KPI ≤10 s to first home frame.
- `flutter-hello-world-app`: Flutter project (`app/lws_hmi`), flutter-pi meta-flutter release build, deployment layout under `/opt/hmi`, acceptance on target hardware.

### Modified Capabilities

_(none — no existing openspec specs in this repo)_

## Impact

- **Buildroot / SDK**: defconfig, prebuilt flutter-pi/engine overlay packages, `lws_hmi_flutter.config`, board logo assets, ynh960 `RK_BUILDROOT_BASE_CFG` update, kernel trim fragment.
- **Overlay**: Rootfs overlay for `/opt/hmi` Hello World artifacts; U-Boot logo under `board/logo/`; systemd units and helper scripts under `usr/lib/lws-hmi/`.
- **App**: `app/lws_hmi/` Flutter project and `scripts/build-flutter-app.sh` (host-side, not Buildroot-compiled).
- **Host flash**: `scripts/flash-usb.sh`, Makefile `devices` / `bootloader` / `loader` / `upgrade` / `flash`; `tools/upgrade_tool/` (Rockchip upgrade_tool v2.44).
- **Existing overlays reused**: `lws_hmi_{base,systemd,network}.config`, `hmi.service`, `06-lws-hmi-systemd.sh`, `08-lws-hmi-systemd-finalize.sh`, LCD/MIPI display overlay.
- **Downstream phases**: P2–P5 depend on P1 display stack, systemd boot chain, and `/opt/hmi` deployment pattern. Uncomment defconfig `#include` lines as each phase lands.
