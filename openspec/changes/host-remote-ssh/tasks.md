## 1. SSH registry + session helpers

- [x] 1.1 Add `scripts/ssh-devices.sh` (connect / disconnect / list TSV / select) with registry under `.cache/lws-hmi/ssh-devices.tsv`
- [x] 1.2 Extend shared session helpers so USB-SSH and registered SSH share select / ssh / scp / wait / reboot paths (`TRANSPORT`, optional `IFACE`, `TARGET_ADDR`)

## 2. Wire host make targets

- [x] 2.1 Add `make connect` / `make disconnect` (positional IP and `IP=`), pass `IP` through `WITH_DOTENV`
- [x] 2.2 Merge SSH registry rows into `make devices` (`flash-usb.sh`)
- [x] 2.3 Update `push-app`, `shell`, `logs`, `reboot` to use shared selection (SSH + USB-SSH); keep `reboot-loader` USB-SSH/adb only
- [x] 2.4 Update debug-app / custom-device adapters for `IP=` and SSH transport (including `debug-host-prepare` so IDE/`make debug-app` do not force USB ECM when `MODE=SSH`)

## 3. Host docs

- [x] 3.1 Update Makefile help and README Common Env / debug sections for connect, disconnect, `IP=`, and SSH mode

## 4. On-device LAN/WLAN sshd (P2.1)

- [x] 4.1 Split sshd_config.d (auth vs USB listen); add `enable-ssh-debug.sh` / `disable-ssh-debug.sh` (+ status)
- [x] 4.2 Update `usb-plug-ssh-start.sh` / stop path for LAN coexistence; adjust `boot-verify` / `verify-rootfs-overlay` / `apply-overlay`
- [x] 4.3 Move LAN sshd into P2.1 in `docs/flutter-pi-hmi-plan.md` (§1 / §7.7 / checklists)

## 5. Demo UI

- [x] 5.1 Add Dart SSH debug controller + Demo section after HTTP / Proxy; wire `p2_demo_page.dart`
- [x] 5.2 Add unit/widget tests for controller parsing/toggle behavior where practical
