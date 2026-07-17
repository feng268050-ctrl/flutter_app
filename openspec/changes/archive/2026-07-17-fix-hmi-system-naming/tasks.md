## 1. Design constants and overlay skeleton

- [x] 1.1 Add shared path constants (shell `paths.sh` and/or Dart module): `wpa_supplicant`, `network`, `bluetooth`, `hmi` state + libexec roots
- [x] 1.2 `git mv` `lws-hmi-fs-overlay/` → `rootfs-overlay/`; de-prefix board/SDK hooks
- [x] 1.3 Create overlay layout: `usr/libexec/{wpa,network,bluetooth,hmi}/`, `var/lib/{wpa_supplicant,network,bluetooth,hmi}/`, `etc/hmi/` — remove monolithic `lws-hmi` dirs

## 2. Split scripts by subsystem

- [x] 2.1 Move Wi‑Fi scripts → `usr/libexec/wpa/`; update paths to `/var/lib/wpa_supplicant/`
- [x] 2.2 Move Ethernet scripts → `usr/libexec/network/`; update paths to `/var/lib/network/`
- [x] 2.3 Move Bluetooth scripts → `usr/libexec/bluetooth/`; update BT prefs to `/var/lib/bluetooth/`
- [x] 2.4 Keep HMI platform scripts in `usr/libexec/hmi/`; HW/UI prefs → `/var/lib/hmi/`
- [x] 2.5 Rewrite `restore-settings.sh` to read four state dirs; rewrite `bind-prefs.sh` for four symlinks + legacy split migration

## 3. systemd, seeds, symlinks

- [x] 3.1 Rename 12 units to functional names; fix all unit `ExecStart` libexec paths
- [x] 3.2 Relocate overlay seed files from `var/lib/lws-hmi/` into subsystem dirs
- [x] 3.3 Update `post-build.sh` `/usr/bin` symlinks for all libexec tiers

## 4. App, verify, docs

- [x] 4.1 Update Dart platform controllers + tests per subsystem paths
- [x] 4.2 Update flutter-pi patches referencing `/var/lib/lws-hmi/mouse.conf`
- [x] 4.3 Update `verify-rootfs-overlay.sh`, `env-verify.sh`, `boot-verify.sh` for split layout (fail on monolithic tree)
- [x] 4.4 Update `docs/storage-layout.md`, `AGENTS.md`, README with four-tree model

## 5. Host scripts

- [x] 5.1 Update `apply-overlay.sh`, `push-app.sh`, `upgrade-remote.sh`, debug/USB-SSH scripts

## 6. Verification

- [x] 6.1 `make apply-overlay` + `verify-rootfs-overlay.sh` pass (requires SDK/docker)
- [x] 6.2 `flutter analyze` + tests in `app/hmi/` (58 pass; 2 pre-existing widget_test flakes unrelated to paths)
- [x] 6.3 Device: full flash factory reset; Wi‑Fi/eth/BT/backlight/mouse prefs on clean userdata
- [x] 6.4 Device: `verify-boot`, `verify-env`; confirm BlueZ cache on userdata after BT bind

## 7. Kernel DTSI / defconfig de-branding

- [x] 7.1 `git mv` 10 DTSI + 6 config files: `lws-hmi-*` → `ynh960-*`; delete retired `lws-hmi-debug-usb.config`
- [x] 7.2 Update `#include` paths, cross-DTSI comments, `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`
- [x] 7.3 Update `apply-overlay.sh`, `prepare-sdk-native.sh`, `gen-ynh960-panel-init-dtsi.sh`, `build-kernel-ab.sh`, `patch-ynh960-dts.sh`; SDK cleanup of legacy kernel artifacts
- [x] 7.4 Update active docs (`README.md`, `docs/kernel-evb-dts-deferred.md`, `docs/ynh960-io-pinmux-ledger.md`, etc.)
- [x] 7.5 `make apply-overlay` + `make build-kernel` + full flash; panel/touch/eth0/USB/WiFi/BT smoke test

## 8. OpenSpec reference sync

- [x] 8.1 Update archived delta specs under `openspec/changes/archive/**/specs/` (and related proposal/design/tasks) to post-rename runtime paths, systemd unit names, kernel `ynh960-*` artifacts, and overlay layout
- [x] 8.2 Update main specs in `openspec/specs/` where stale on-device paths remained (`hmi-systemd-boot`, `linux-settings-persist`, `ab-firmware-slots`, `usb-otg-id-role`)
