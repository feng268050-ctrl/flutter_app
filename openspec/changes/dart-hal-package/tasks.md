## 1. Supersede Rust HAL design

- [x] 1.1 Mark `openspec/changes/rust-hal-and-phase-realign` SUPERSEDED for Rust/`hald` (point to `dart-hal-package`)
- [x] 1.2 Update `docs/flutter-pi-hmi-plan.md` §1 P3.1 + §1.4 to state **Dart HAL package** (no Rust hald)
- [x] 1.3 Align AGENTS.md / README phase blurb if they still say Rust HAL
- [x] 1.4 Record decision: **enable systemd-networkd** + wpa D-Bus; migrate eth0/wlan0 L3 off scripts (design D11)
- [x] 1.5 Record backend taxonomy (D12) + gpio/modbus config schemas (D13/D14) in proposal/design/specs
- [x] 1.6 Record keyboard layout decision (D15): XKB pref + **HMI restart** for v1 (hot-reload optional later)
- [x] 1.7 Record mouse decision (D16): formalize existing `mouse.conf` + `apply-mouse-settings` contract
- [x] 1.8 Drop `hal/http` and `hal/device_info`; add `hal/sys_info` (D17: identity + CPU/mem/storage/thermal/runtime; no Modbus)
- [x] 1.9 Reorganize network as `hal/network` {ethernet, wifi, proxy} (D18); proxy multi-scheme + curl-visible apply
- [x] 1.10 Drop `hal/orientation` (D19); remove Demo orientation settings; launch `-o` stays board/image-fixed
- [x] 1.11 Merge LAN SSH + USB OTG debug into `hal/debug` (D20)
- [x] 1.12 Group `hal/output` {backlight,volume} + `hal/input` {keyboard,mouse} (D21); keep `hal/gpio` + `hal/modbus` as separate top-level modules

## 2. Package scaffold (start here for code)

- [x] 2.1 Package name decided: **`cyber_hal`**
- [ ] 2.2 Create `packages/cyber_hal/` with pubspec + core + `boards/ynh960` profile stubs; entrypoint layout per D21 (`hal/output/*`, `hal/input/*`, `hal/debug/*`, `hal/gpio`, `hal/modbus`, `hal/sys_info`, `hal/datetime`, `hal/bluetooth`; network stubs OK empty)
- [ ] 2.3 Ship `boards/ynh960/gpio.json` + `boards/ynh960/modbus.json` matching current Demo maps
- [ ] 2.4 Wire `app/hmi` path dependency on `cyber_hal`; package README (module map + persist paths)
- [ ] 2.5 `flutter analyze` / smoke that App still builds

## 3. Lift easy modules (little OS churn)

Prefer `git mv` of existing `app/hmi/lib/platform/**` — keep current Linux helpers; rename toward HAL APIs gradually.

- [ ] 3.1 `hal/output`: backlight + volume (sysfs / amixer + existing helpers)
- [ ] 3.2 `hal/input/mouse`: presence + `mouse.conf` / `apply-mouse-settings` (D16)
- [ ] 3.3 `hal/input/keyboard`: presence + layout get/set/list; persist XKB pref; **apply via flutter-pi/hmi restart**; App restores previous route after relaunch (D15 v1)
- [ ] 3.4 `hal/debug`: ssh + usb (existing controllers)
- [ ] 3.5 `hal/datetime`: existing date/time controller
- [ ] 3.6 `hal/sys_info`: SN + expand CPU/mem/storage/thermal/uptime (D17); start with SN/kernel/app if incremental
- [ ] 3.7 Demo cutover for §3 modules (incl. US↔RU layout); analyze/tests

## 4. Config-driven gpio + modbus (medium)

- [ ] 4.1 Implement `hal/gpio` from config; replace `GpioLedConfig` constants in Demo
- [ ] 4.2 Implement `hal/modbus` (`modbus_client` + attribute catalog); replace `*RegisterAddress` in Demo
- [ ] 4.3 Golden tests for ynh960 gpio/modbus JSON vs current maps
- [ ] 4.4 Validate `modbus_client` on aarch64/flutter-pi early in this wave

## 5. Bluetooth (extend in place)

- [ ] 5.1 Move BlueZ path into `hal/bluetooth`; keep Demo behavior
- [ ] 5.2 Keyboard battery keepalive (periodic) as designed
- [ ] 5.3 Demo cutover + smoke

## 6. Network stack + `hal/network` (largest; do last)

OS cutover first, then Dart modules against the new stack. Until then Demo may keep legacy ethernet/wifi/http-proxy paths behind thin façades or stay in App.

- [ ] 6.1 Enable `BR2_PACKAGE_SYSTEMD_NETWORKD`; drop “networkd must stay off” long-term
- [ ] 6.2 Ship wpa_supplicant with D-Bus control; document L2=wpa / L3=networkd split
- [ ] 6.3 Replace or delete eth0/wlan0 L3 scripts (networkd-only wrappers or remove)
- [ ] 6.4 Rewrite `restore-settings` / wanted markers for networkd+wpa
- [ ] 6.5 Board smoke: DHCP/static eth + Wi‑Fi assoc+IP; no address flapping
- [ ] 6.6 Implement `apply-proxy` (multi-scheme, curl-visible); migrate off `/var/lib/hmi/http-proxy`
- [ ] 6.7 Accept proxy: enable → new shell `curl` uses it; clear; reboot restore
- [ ] 6.8 Implement `hal/network` {ethernet, wifi} on networkd/wpa D-Bus
- [ ] 6.9 Implement `hal/network/proxy`; Demo curl-based probe
- [ ] 6.10 Spec/note camera eth0 via networkd reconfigure (P4/P5)

## 7. Follow-ons

- [ ] 7.1 Stub/sim profile for P3.2 emulator
- [ ] 7.2 Archive superseded `rust-hal-and-phase-realign` when convenient
- [ ] 7.3 Decide config install path: Flutter assets only vs also `/usr/share/cyber_hal/`
- [ ] 7.4 Product list of layout ids to ship beyond `us` / `ru`
- [ ] 7.5 Optional: flutter-pi keyboard.conf mtime hot-reload (no HMI restart)
