## 1. Buildroot defconfig and SDK wiring

- [x] 1.1 Copy `overlay/buildroot/chips/lws_hmi_*.config` into SDK `buildroot/configs/rockchip/chips/` via `apply-overlay.sh` (verify base, systemd, network, npu fragments)
- [x] 1.2 Add `overlay/buildroot/chips/lws_hmi_flutter.config` enabling flutter-pi and GPU/display dependencies (Mali, libdrm, libgbm, fontconfig, libinput)
- [x] 1.3 Finalize `rockchip_rk3566_rk3568_lws_hmi_defconfig`: enable `lws_hmi_flutter.config`, confirm EVB packages (weston/chromium/camera/benchmark/test) are not included
- [x] 1.4 Install defconfig into SDK `buildroot/configs/rockchip_rk3566_rk3568_lws_hmi_defconfig` and wire `BR2_ROOTFS_OVERLAY` to `lws-hmi-fs-overlay`
- [x] 1.5 Update `board/ynh960_defconfig` overlay with `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"`, `# RK_RECOVERY is not set`, `RK_WIFIBT=y`
- [x] 1.6 Run `make setup && make lunch` and confirm SDK `.config` picks up lws_hmi Buildroot profile (verify in Docker: `RK_BUILDROOT_BASE_CFG="rk3566_rk3568_lws_hmi"`)

## 2. flutter-pi Buildroot package

- [x] 2.1 Use SDK in-tree `buildroot/package/flutter-pi/` (v37bd977) enabled via `lws_hmi_flutter.config` — no overlay package fork needed
- [x] 2.2 Enable flutter-pi via defconfig fragment (`BR2_PACKAGE_FLUTTER_PI=y`); SDK `Config.in` already registers the package
- [x] 2.3 Document engine/flutter-pi version alignment in `app/README.md` (Flutter engine 3.24.4 / flutterpi_tool)
- [ ] 2.4 Build rootfs iteratively until `/usr/bin/flutter-pi` appears in target (fix deps: systemd, Mali, libdrm) — **run `make build-rootfs` (first build: hours)**

## 3. Boot splash (ynh960)

- [x] 3.1 Add product logo source at `board/logo/splash_icon.png` (512×512 PNG)
- [x] 3.2 Add `scripts/build-boot-logo.sh` (or Makefile target) to convert `splash_icon.png` → `board/logo/logo.bmp` (24-bit BMP, scaled/centered for 800×1280 MIPI @ 90° rotation)
- [x] 3.3 Wire generated `logo.bmp` into ynh960 U-Boot board packaging (resource partition or SDK-equivalent mechanism)
- [x] 3.4 Verify kernel early splash / bootlogo on ynh960 DTS profile; enable Kconfig if missing
- [ ] 3.5 Acceptance: power-on shows logo within 2 s; no prolonged black screen before flutter-pi home — **requires `make upgrade` + hardware**

## 4. Flutter Hello World app

- [x] 4.1 Create `app/lws_hmi_app` with `flutter create`; minimal home screen ("Hello, lws-hmi")
- [x] 4.2 Configure flutter-pi custom device / build tooling for ARM64 release AOT
- [x] 4.3 Add `scripts/build-flutter-app.sh` (or Makefile target) producing meta-flutter bundle under `/opt/hmi`
- [x] 4.4 Ensure `main()` has no video/WebSocket/FFI init before first frame (KPI)
- [x] 4.5 Copy release artifacts into `lws-hmi-fs-overlay/opt/hmi/` before rootfs build

## 5. systemd boot chain (Plan A)

- [x] 5.1 Verify `hmi.service` ExecStart and `After=local-fs.target` only (no network/mediamtx deps)
- [x] 5.2 Confirm `06-lws-hmi-systemd.sh` post-hook enables hmi and disables mediamtx/sshd/bluetooth
- [x] 5.3 Confirm journald volatile overlay is installed
- [x] 5.4 Add flutter-pi rotation flags to `hmi.service` Environment or ExecStart if needed for ynh960 (`-o landscape_left` or `-r 90`)
- [ ] 5.5 On device: `systemd-analyze critical-chain hmi.service` — no network-online / mediamtx / udev-settle — **requires hardware**

## 6. Integration build and acceptance

- [ ] 6.1 Run full `make build-rootfs` with Hello World overlay; record rootfs size (`du -sh target/`)
- [ ] 6.2 Run `make build`; `make docker-volume-pull` (macOS); flash via `make devices` → `SERIAL=… make bootloader` → `make upgrade` (or MaskROM + `make loader` first)
- [ ] 6.3 Verify auto-start: boot → splash → Hello World without manual `systemctl start hmi`
- [ ] 6.4 Verify absent packages: no weston, chromium, adbd, rknn_common_test on target
- [ ] 6.5 Verify present stack: flutter-pi, librknnrt.so, wpa_supplicant, LCD params under `/system/etc/`
- [ ] 6.6 KPI: power-on to first home frame ≤ 10 s on eMMC (record measurement in change notes)
- [x] 6.7 Update `README.md` with P1 build/flash/verify commands referencing lws_hmi defconfig

## 7. Host USB flash (upgrade_tool)

- [x] 7.1 Add `scripts/flash-usb.sh` — `upgrade_tool ld` / `ul` / `uf`; multi-device `-s LocationID` (PDF §1.11); run from tool dir with `config.ini`
- [x] 7.2 Makefile targets: `devices` (table: MODE / SERIAL / LocationID / USB), `bootloader` (`adb reboot loader`), `loader`, `upgrade`
- [x] 7.3 Selection env: `SERIAL`, `USB_LOCATION`, `IMAGE=`; optional `LWS_HMI_AUTO_PULL=1` on macOS
- [x] 7.4 Document in `README.md` and `make help`; vendored at `tools/upgrade_tool/`
- [ ] 7.5 Hardware acceptance: `make upgrade` with built `update.img` on ynh960 eMMC
