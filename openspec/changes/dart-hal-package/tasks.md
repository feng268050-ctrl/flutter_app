## 1. Supersede Rust HAL design

- [x] 1.1 Mark `openspec/changes/rust-hal-and-phase-realign` SUPERSEDED for Rust/`hald` (point to `dart-hal-package`)
- [x] 1.2 Update `docs/flutter-pi-hmi-plan.md` §1 P3.1 + §1.4 to state **Dart HAL package** (no Rust hald)
- [x] 1.3 Align AGENTS.md / README phase blurb if they still say Rust HAL
- [x] 1.4 Record decision: **enable systemd-networkd** + wpa D-Bus; migrate eth0/wlan0 L3 off scripts (design D11)
- [x] 1.5 Record backend taxonomy (D12) + gpio/modbus config schemas (D13/D14) in proposal/design/specs
- [x] 1.6 Record keyboard layout decision (D15): flutter-pi XKB + `/var/lib/hmi/keyboard.conf` hot-reload
- [x] 1.7 Record mouse decision (D16): formalize existing `mouse.conf` + `apply-mouse-settings` contract
- [x] 1.8 Drop `hal/http` and `hal/device_info`; add `hal/sys_info` (D17: identity + CPU/mem/storage/thermal/runtime; no Modbus)
- [x] 1.9 Reorganize network as `hal/network` {ethernet, wifi, proxy} (D18); proxy multi-scheme + curl-visible apply
- [x] 1.10 Drop `hal/orientation` (D19); remove Demo orientation settings; launch `-o` stays board/image-fixed
- [x] 1.11 Merge LAN SSH + USB OTG debug into `hal/debug` (D20)
- [x] 1.12 Group `hal/output` {backlight,volume} + `hal/input` {keyboard,mouse} (D21); keep `hal/gpio` + `hal/modbus` as separate top-level modules

## 2. OS network stack migration (prerequisite for hal/network ethernet + wifi)

- [ ] 2.1 Enable `BR2_PACKAGE_SYSTEMD_NETWORKD` in Buildroot fragments; drop “networkd must stay off” long-term
- [ ] 2.2 Ship wpa_supplicant with D-Bus control; document L2=wpa / L3=networkd split
- [ ] 2.3 Replace or delete eth0/wlan0 L3 scripts: either gone, or thin wrappers that only configure networkd (no raw `ip addr`/dhcpcd as primary)
- [ ] 2.4 Rewrite `restore-settings` / wanted markers for networkd+wpa world
- [ ] 2.5 Board smoke: DHCP/static eth + Wi‑Fi assoc+IP; no address flapping
- [ ] 2.6 Spec note for camera eth0: dynamic address via networkd reconfigure (P4/P5); any remaining script must wrap networkd
- [ ] 2.7 Implement `apply-proxy`: `/var/lib/network/proxy.conf` → profile.d + proxy.env + systemd/environment; schemes http/https/ftp/socks*; migrate off `/var/lib/hmi/http-proxy`
- [ ] 2.8 Accept: enable SOCKS or HTTP proxy → new shell `curl` uses it; disable clears env; reboot restore reapplies

## 3. Package scaffold

- [ ] 3.1 Choose package name (`lws_hal` / `cyber_hal` / …) and create `packages/<name>/` with pubspec
- [ ] 3.2 Add core + `boards/ynh960` profile; entrypoints: `hal/network/*`, `hal/output/*`, `hal/input/*`, `hal/debug/*`, plus top-level `hal/gpio`, `hal/modbus`, `hal/bluetooth`, `hal/sys_info`, `hal/datetime`
- [ ] 3.3 Ship `boards/ynh960/gpio.json` + `boards/ynh960/modbus.json` matching current Demo maps
- [ ] 3.4 Document module map, backend kinds, persist paths, and config schemas in package README

## 4. Move / implement modules

- [ ] 4.1 Move platform code into packages (**D21** output/input; top-level gpio/modbus; **D17** sys_info; **D20** debug)
- [ ] 4.2 Implement `hal/network` ethernet + wifi on networkd/wpa D-Bus after §2
- [ ] 4.3 Implement `hal/network/proxy` against apply-proxy; Demo settings + curl-based probe
- [ ] 4.4 `hal/bluetooth` (+ keyboard battery keepalive)
- [ ] 4.5 Implement config-driven `hal/gpio` + `hal/modbus`; golden tests for ynh960 configs
- [ ] 4.6 Wire `app/hmi` dependency; replace `GpioLedConfig` / `*RegisterAddress` with attribute/line ids; Demo cutover; analyze/tests

## 5. Keyboard layout (D15)

- [ ] 5.1 flutter-pi patch: mtime-watch `/var/lib/hmi/keyboard.conf` and reload XKB (no HUP / no hmi restart)
- [ ] 5.2 `hal/input/keyboard` layout get/set/list + persist; Demo US↔RU (or `us,ru` toggle) smoke
- [ ] 5.3 Wire restore / image default: `/etc/default/keyboard` vs `keyboard.conf` precedence documented and tested

## 6. Follow-ons

- [ ] 6.1 Stub/sim profile for P3.2 emulator
- [ ] 6.2 Archive superseded `rust-hal-and-phase-realign` when convenient
- [ ] 6.3 Decide config install path: Flutter assets only vs also `/usr/share/<hal>/`
- [ ] 6.4 Product list of layout ids to ship beyond `us` / `ru`
