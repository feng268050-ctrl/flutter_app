## 1. Buildroot defconfig and SDK wiring

- [x] 1.1 Copy `overlay/buildroot/chips/lws_hmi_*.config` into SDK `buildroot/configs/rockchip/chips/` via `apply-overlay.sh` (verify base, systemd, network, npu fragments)
- [x] 1.2 Add `overlay/buildroot/chips/lws_hmi_flutter.config` enabling flutter-pi and GPU/display dependencies (Mali, libdrm, libgbm, fontconfig, libinput)
- [x] 1.3 Finalize `rockchip_rk3566_rk3568_lws_hmi_defconfig`: enable `lws_hmi_flutter.config`, confirm EVB packages (weston/chromium/camera/benchmark/test) are not included
- [x] 1.4 Install defconfig into SDK `buildroot/configs/rockchip_rk3566_rk3568_lws_hmi_defconfig` and wire `BR2_ROOTFS_OVERLAY` to `rootfs-overlay`
- [x] 1.5 Update `board/ynh960_defconfig` overlay with `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"`, `# RK_RECOVERY is not set`, `RK_WIFIBT=y`
- [x] 1.6 Run `make setup && make lunch` and confirm SDK `.config` picks up lws_hmi Buildroot profile (verify in Docker: `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"`)

## 2. flutter-pi Buildroot package

- [x] 2.1 Use SDK in-tree `buildroot/package/flutter-pi/` (v37bd977) enabled via `lws_hmi_flutter.config` — overlay adds **prebuilt-only** `.mk` (no compile in `build-rootfs`)
- [x] 2.2 Enable flutter-pi via defconfig fragment (`BR2_PACKAGE_FLUTTER_PI=y`); meta-flutter layout (`FILESYSTEM_LAYOUT=meta-flutter`)
- [x] 2.3 Require prebuilt Flutter stack: `make check-prebuilt`; Buildroot copies prebuilt only (no compile fallback)
- [x] 2.4a P1 prep: `make build-all-deps` — runtime (incl. GStreamer/MPP prebuilt for later phases) + dev-host
- [x] 2.4 Build rootfs iteratively until `/usr/bin/flutter-pi` appears in target — **done** (`make build-rootfs` + `verify-rootfs-overlay.sh` PASS)

## 3. Boot splash (ynh960)

- [x] 3.1 Add product logo source at `board/logo/splash_icon.png` (512×512 PNG)
- [x] 3.2 Add `scripts/build-boot-logo.sh` (or Makefile target) to convert `splash_icon.png` → `board/logo/logo.bmp` (24-bit BMP, scaled/centered for 800×1280 MIPI @ 90° rotation)
- [x] 3.3 Wire generated `logo.bmp` into ynh960 U-Boot board packaging (SDK `boot.its` FIT + resource partition)
- [x] 3.4 Verify kernel early splash / bootlogo on ynh960 DTS profile; enable Kconfig if missing
- [x] 3.5 Acceptance: power-on shows logo within ~2 s; logo holds until flutter-pi first frame — **done** on ynh960 hardware (see `docs/boot-kpi-optimization.md` §6)

## 4. Flutter Hello World app

- [x] 4.1 Create `app/hmi` with `flutter create`; minimal home screen ("Hello, lws-hmi") — renamed from `lws_hmi_app`
- [x] 4.2 Configure flutter-pi custom device / build tooling for ARM64 release AOT (`flutterpi_tool`, Flutter 3.24.4 pin)
- [x] 4.3 Add `scripts/build-app.sh` (or Makefile target) producing meta-flutter bundle under `/opt/hmi`
- [x] 4.4 Ensure `main()` has no video/WebSocket/FFI init before first frame (KPI)
- [x] 4.5 Copy release artifacts into `rootfs-overlay/opt/hmi/` before rootfs build

## 5. systemd boot chain (Plan A)

- [x] 5.1 Verify `hmi.service` ExecStart and `After=local-fs.target` only (no network/mediamtx deps); added `After=cpu-performance.service`, `Nice=-5`
- [x] 5.2 Confirm `06-systemd-appliance.sh` post-hook enables hmi + mainserver + performance + pwrkey; disables mediamtx/sshd/bluetooth/wifibt-init/wpa_supplicant/network/log-guardian
- [x] 5.3 Confirm journald volatile overlay is installed
- [x] 5.4 Add flutter-pi rotation flags to `hmi.service` ExecStart (`-o landscape_left` on ynh960)
- [x] 5.5 On device: `/usr/libexec/hmi/boot-verify.sh` — Plan A unit enable/disable (no network-online / mediamtx / udev-settle at boot) — **done**

## 6. Integration build and acceptance

- [x] 6.1 Run full `make build-rootfs` with Hello World overlay; `verify-rootfs-overlay.sh` PASS
- [x] 6.2 Build firmware and flash on ynh960: `make build` (or `make build-img` after incremental changes) → `make audit` → `make flash` (`SERIAL=` when multiple devices; Maskrom auto `ul`+`uf`, Loader `uf` only) — **done**
- [x] 6.3 Verify auto-start: boot → splash → Hello World without manual `systemctl start hmi` — **done** on ynh960
- [x] 6.4 Verify absent packages: no weston, chromium, adbd, rknn_common_test on target — **done**
- [x] 6.5 Verify present stack: flutter-pi, `librknnrt.so`, `rknn_server`, wpa_supplicant, LCD params under `/system/etc/` — **done** on ynh960 (`env-verify.sh` / `boot-verify.sh`)
- [x] 6.6 KPI: power-on to first home frame ≤ 10 s on eMMC — **done** (~8.4 s measured; see `docs/boot-kpi-optimization.md` §6)
- [x] 6.7 Update `README.md` with P1 build/flash/verify commands referencing lws_hmi defconfig

## 7. Host USB flash (upgrade_tool)

- [x] 7.1 Add `scripts/flash-usb.sh` — `upgrade_tool ld` / `ul` / `uf`; multi-device `-s LocationID` (PDF §1.11); run from tool dir with `config.ini`
- [x] 7.2 Makefile targets: `audit` (pre-flight), `devices`, `flash` (unified: auto `ul`+`uf` or `uf`); `bootloader` optional when entering Loader from Android
- [x] 7.3 Selection env: `SERIAL`, `IMAGE=`; macOS auto-pulls output/ before flash
- [x] 7.4 Document in `README.md` and `make help`; vendored at `tools/upgrade_tool/`
- [x] 7.5 Hardware acceptance: `make audit` → `make flash` with `output/firmware/update.img` on ynh960 eMMC — **done**

## 8. Boot KPI optimization (P1 adjustment — beyond original task list)

- [x] 8.1 Single-image policy: remove `lws-hmi-debug-boot`, kernel `ip=` bootargs; no `LWS_HMI_DEV` split
- [x] 8.2 Defer Wi‑Fi/BT/network at boot (`wifibt-init`, `wpa_supplicant`, `network.service` disabled in wants)
- [x] 8.3 `cpu-performance.service` — CPU/DMC/GPU `performance` governors before HMI start
- [x] 8.4 `pwrkey-poweroff.service` + `shutdown.sh` SysRq poweroff (avoid Mali DRM teardown oops)
- [x] 8.5 eMMC `noatime` via fstab (not `rootflags=noatime`)
- [x] 8.6 Kernel `loglevel=4` + `ynh960-kernel-trim.config` fragment
- [x] 8.7 `boot-verify.sh` on device + `verify-rootfs-overlay.sh` at build time
- [x] 8.8 `08-systemd-appliance-finalize.sh` — undo SDK `log-guardian` re-enable after post-hooks
