## 1. Kernel and defconfig

- [ ] 1.1 Add `overlay/kernel/rockchip/lws-hmi-usb-gadget.config` (ECM, configfs, dwc3 gadget) and append to `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`
- [ ] 1.2 Retire or merge duplicate options from `lws-hmi-debug-usb.config`; document in fragment comment
- [ ] 1.3 Rebuild kernel on device smoke: `configfs` and `usb_f_ecm` (or module) present after flash

## 2. Target rootfs — USB plug-ssh scripts

- [ ] 2.1 Add `/usr/lib/lws-hmi/usb-plug-ssh-start.sh` — compose ECM gadget, set `iSerial`, bring up `usb0` at `192.168.55.1/24`
- [ ] 2.2 Add `/usr/lib/lws-hmi/usb-plug-ssh-stop.sh` — unbind UDC, remove gadget, down `usb0`
- [ ] 2.3 Add `/usr/lib/lws-hmi/read-device-serial.sh` — stable serial from DT / SoC for `iSerial`
- [ ] 2.4 Add udev rule(s) or systemd path unit for VBUS attach → start, detach → stop
- [ ] 2.5 Add `lws-hmi-usb-plug-ssh.service` (no `[Install]` / not in multi-user wants)

## 3. Target rootfs — sshd usb0-only

- [ ] 3.1 Add `sshd_config.d` drop-in: `ListenAddress 192.168.55.1`, `PasswordAuthentication yes` (usb debug context)
- [ ] 3.2 Start sshd from plug-ssh service (instance or `sshd -D` listener on usb0 only); stop on unplug
- [ ] 3.3 Confirm `99-lws-hmi.preset` still disables boot-time `sshd.service`; plug path does not `systemctl enable sshd`

## 4. Boot verification

- [ ] 4.1 Extend `boot-verify.sh` — USB plug-ssh unit not in `multi-user.target.wants`
- [ ] 4.2 Extend `verify-rootfs-overlay.sh` — required scripts, udev rules, sshd drop-in present
- [ ] 4.3 Extend `08-lws-hmi-systemd-finalize.sh` if SDK re-enables unwanted units

## 5. Host scripts and Makefile

- [ ] 5.1 Add `scripts/usb-ssh-devices.sh` — list USB-SSH rows (SERIAL, LocationID, IFACE, ADDR); map iSerial ↔ host interface (macOS ioreg + Linux sysfs)
- [ ] 5.2 Add `scripts/push-hmi.sh` — host `192.168.55.2`, wait-for-ping, `scp` libapp.so + flutter_assets, `ssh restart hmi`, `SERIAL=` / `BindInterface`
- [ ] 5.3 Add Makefile target `push-hmi`; extend `make devices` to merge RockUSB + USB-SSH rows (`MODE` column)
- [ ] 5.4 Wire `push-hmi` to `build-flutter-app` output paths (overlay staging or build dir)
- [ ] 5.5 Extend `scripts/flash-usb.sh` `run_bootloader`: Linux USB-SSH → `ssh … /usr/lib/lws-hmi/reboot-rockusb-loader`; adb fallback; reuse `SERIAL=` / `BindInterface` / `wait_for_rockusb`
- [ ] 5.6 Update `flash-usb.sh` usage text and `Makefile help` — `make bootloader` works from Linux (USB-SSH) and Android (adb)

## 6. Documentation

- [ ] 6.1 Update `README.md` — `make push-hmi`, `make bootloader` from Linux, multi-device `SERIAL=`, workflow vs `make flash`
- [ ] 6.2 Update `AGENTS.md` — rebuild table row for usb-plug-ssh overlay changes
- [ ] 6.3 Update `docs/flutter-pi-hmi-plan.md` §6.2 / §7.7 — USB plug-to-debug as primary app iteration path
- [ ] 6.4 Update `Makefile` `help` text for new targets

## 7. Hardware acceptance

- [ ] 7.1 Single board: plug USB → `make devices` shows USB-SSH row → `make push-hmi` updates Hello World without reflash
- [ ] 7.2 Two boards: `make push-hmi` without `SERIAL` fails; `SERIAL=… make push-hmi` hits correct device
- [ ] 7.3 Unplug: ssh not reachable; replug restores USB-SSH row
- [ ] 7.4 Boot KPI: `boot-verify.sh` PASS; `systemd-analyze critical-chain hmi.service` unchanged (no USB deps)
- [ ] 7.5 `make flash` / RockUSB Loader still works when device rebooted to bootloader (orthogonal modes)
- [ ] 7.6 Linux runtime: USB plugged → `SERIAL=… make bootloader` → `make devices` shows RockUSB Loader → `make flash` succeeds
