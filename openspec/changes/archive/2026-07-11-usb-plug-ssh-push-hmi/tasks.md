## 1. Kernel and defconfig

- [x] 1.1 Add `overlay/kernel/rockchip/ynh960-usb-gadget.config` (ECM, configfs, dwc3 gadget) and append to `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`
- [x] 1.2 Retire or merge duplicate options from `ynh960-usb-gadget.config`; document in fragment comment
- [x] 1.3 Rebuild kernel on device smoke: `configfs` and `usb_f_ecm` (or module) present after flash — validated on ynh960 bench (USB-SSH + push-app)

## 2. Target rootfs — USB plug-ssh scripts

- [x] 2.1 Add `/usr/libexec/hmi/usb-plug-ssh-start.sh` — compose ECM gadget, set `iSerial`, bring up `usb0` at `192.168.55.1/24`
- [x] 2.2 Add `/usr/libexec/hmi/usb-plug-ssh-stop.sh` — unbind UDC, remove gadget, down `usb0`
- [x] 2.3 Add `/usr/libexec/hmi/read-device-serial.sh` — stable serial from DT / SoC for `iSerial`
- [x] 2.4 Add udev rule(s) or systemd path unit for VBUS attach → start, detach → stop
- [x] 2.5 Add `ssh-debug-usb.service` (no `[Install]` / not in multi-user wants; `After=hmi.service` only)

## 3. Target rootfs — sshd usb0-only

- [x] 3.1 Add `sshd_config.d` drop-in: `ListenAddress 192.168.55.1`, `PasswordAuthentication yes` (usb debug context)
- [x] 3.2 Start sshd from plug-ssh service (instance or `sshd -D` listener on usb0 only); stop on unplug
- [x] 3.3 Confirm `99-appliance.preset` still disables boot-time `sshd.service`; plug path does not `systemctl enable sshd`

## 4. Boot verification

- [x] 4.1 Extend `boot-verify.sh` — USB plug-ssh unit not in `multi-user.target.wants`
- [x] 4.2 Extend `verify-rootfs-overlay.sh` — required scripts, udev rules, sshd drop-in present
- [x] 4.3 Extend `08-systemd-appliance-finalize.sh` if SDK re-enables unwanted units

## 5. Host scripts and Makefile

- [x] 5.1 Add `scripts/usb-ssh-devices.sh` — list USB-SSH rows (SERIAL, LocationID, IFACE, ADDR); map iSerial ↔ host interface (macOS ioreg + Linux sysfs)
- [x] 5.2 Add `scripts/push-app.sh` — host `192.168.55.2`, wait-for-ping, stage + install `libapp.so` + `flutter_assets`, sysrq reboot (no `systemctl restart hmi`), `SERIAL=` / `BindInterface`
- [x] 5.3 Add Makefile target `push-app`; extend `make devices` to merge RockUSB + USB-SSH + adb rows (`MODE` column)
- [x] 5.4 Wire `push-app` to `build-app` output paths (overlay staging or build dir)
- [x] 5.5 Extend `scripts/flash-usb.sh` `run_reboot_loader`: Linux USB-SSH → `reboot-rockusb-loader`; adb fallback; reuse `SERIAL=` / `BindInterface` / `wait_for_rockusb`
- [x] 5.6 Update `flash-usb.sh` usage text and `Makefile help` — `make reboot-loader` from Linux (USB-SSH) and Android (adb)
- [x] 5.7 Add `make reboot` — Linux sysrq reboot over USB-SSH; Android `adb reboot`; no Loader wait
- [x] 5.8 Add `scripts/usb-ssh-common.sh` — shared BindInterface, sysrq reboot, `require_sshpass` install hints
- [x] 5.9 Add board `push-app-apply-and-reboot.sh` (staging install + scheduled reboot)

## 6. Documentation

- [x] 6.1 Update `README.md` — `make push-app`, `make reboot` / `make reboot-loader`, multi-device `SERIAL=`, workflow vs `make flash`
- [x] 6.2 Update `AGENTS.md` — rebuild table row for usb-plug-ssh overlay changes
- [x] 6.3 Update `docs/flutter-pi-hmi-plan.md` §6.2 / §7.7 — USB plug-to-debug as primary app iteration path
- [x] 6.4 Update `Makefile` `help` text for new targets

## 7. Hardware acceptance

- [x] 7.1 Single board: plug USB → `make devices` shows USB-SSH row → `make push-app` updates app without rootfs reflash (sysrq reload)
- [x] 7.2 Two boards: `make push-app` without `SERIAL` fails; `SERIAL=… make push-app` hits correct device
- [x] 7.3 Unplug: ssh not reachable; replug restores USB-SSH row
- [x] 7.4 Boot KPI: `boot-verify.sh` PASS; `systemd-analyze critical-chain hmi.service` unchanged (no USB deps)
- [x] 7.5 `make flash` / RockUSB Loader still works when device rebooted to bootloader (orthogonal modes)
- [x] 7.6 Linux runtime: USB plugged → `SERIAL=… make reboot-loader` → `make devices` shows RockUSB Loader → `make flash` succeeds
