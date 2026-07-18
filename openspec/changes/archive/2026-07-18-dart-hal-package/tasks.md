## 1. Supersede Rust HAL design

- [x] 1.1 Mark `openspec/changes/rust-hal-and-phase-realign` SUPERSEDED for Rust/`hald` (point to `dart-hal-package`)
- [x] 1.2 Update `docs/flutter-pi-hmi-plan.md` §1 P3.1 + §1.4 to state **Dart HAL package** (no Rust hald)
- [x] 1.3 Align AGENTS.md / README phase blurb if they still say Rust HAL
- [x] 1.4 Record decision: **enable systemd-networkd** + wpa D-Bus; migrate eth0/wlan0 L3 off scripts (design D11)
- [x] 1.5 Record backend taxonomy (D12) + gpio/modbus config schemas (D13/D14) in proposal/design/specs
- [x] 1.6 Record keyboard layout decision (D15): XKB pref + **HMI restart** for v1 (hot-reload optional later)
- [x] 1.7 Record mouse decision (D16): formalize existing `mouse.conf` + `apply-mouse-settings` contract
- [x] 1.8 Drop `hal/http` and `hal/device_info`; add `hal/sys_info` (D17: identity + CPU/mem/storage/thermal/runtime; no Modbus)
- [x] 1.9 Reorganize network as `hal/network` {ethernet, wifi, proxy} (D18); proxy multi-scheme + CLI-env-visible apply
- [x] 1.10 Drop `hal/orientation` (D19); remove Demo orientation settings; launch `-o` stays board/image-fixed
- [x] 1.11 Merge LAN SSH + USB OTG debug into `hal/debug` (D20)
- [x] 1.12 Group `hal/output` {backlight,volume} + `hal/input` {keyboard,mouse} (D21); keep `hal/gpio` + `hal/modbus` as separate top-level modules

## 2. Package scaffold (start here for code)

- [x] 2.1 Package name decided: **`cyber_hal`**
- [x] 2.2 Create `packages/cyber_hal/` with pubspec + core + `boards/ynh960` profile stubs; entrypoint layout per D21 (`hal/output/*`, `hal/input/*`, `hal/debug/*`, `hal/gpio`, `hal/modbus`, `hal/sys_info`, `hal/datetime`, `hal/bluetooth`; network stubs OK empty)
- [x] 2.3 Ship `boards/ynh960/gpio.json` + `boards/ynh960/modbus.json` matching current Demo maps
- [x] 2.4 Wire `app/hmi` path dependency on `cyber_hal`; package README (module map + persist paths)
- [x] 2.5 `flutter analyze` / smoke that App still builds

## 3. Lift easy modules (little OS churn)

Prefer `git mv` of existing `app/hmi/lib/platform/**` — keep current Linux helpers; rename toward HAL APIs gradually.

- [x] 3.1 `hal/output`: backlight + volume (sysfs / amixer + existing helpers)
- [x] 3.2 `hal/input/mouse`: presence + `mouse.conf` / `apply-mouse-settings` (D16)
- [x] 3.3 `hal/input/keyboard`: presence + layout get/set/list; persist XKB pref; **apply via flutter-pi/hmi restart**; App restores previous route after relaunch (D15 v1)
- [x] 3.4 `hal/debug`: ssh + usb (existing controllers)
- [x] 3.5 `hal/datetime`: existing date/time controller
- [x] 3.6 `hal/sys_info`: SN + expand CPU/mem/storage/thermal/uptime (D17); start with SN/kernel/app if incremental
- [x] 3.7 Demo cutover for §3 modules (incl. US↔RU layout); analyze/tests

## 4. Config-driven gpio + modbus (medium)

- [x] 4.1 Implement `hal/gpio` from config; replace `GpioLedConfig` constants in Demo
- [x] 4.2 Implement `hal/modbus` one-shot attribute catalog + RTU; replace `*RegisterAddress` in Demo
- [x] 4.3 Golden tests for ynh960 gpio/modbus JSON vs current maps
- [x] 4.4 Expand `modbus.json` schema: `poll` (interval default 100ms), `groups` (status/data/info), bit→attribute alarm maps (lws-ui parity)
- [x] 4.5 Implement HAL scheduler: contiguous group reads, `command_interval_ms`, discard-if-busy, `startPolling`/`stopPolling`/`exclusiveSession`
- [x] 4.6 Implement `watchAttributes` — emit list of **only changed** attributes per cycle; optional `watchHealth` for C001 input
- [x] 4.7 Demo/product cutover: subscribe watch (no App Timer poll); alarm UI binds readable attribute ids
- [x] 4.8 Board smoke: continuous status+data poll + change callbacks on device

## 5. Bluetooth (extend in place)

- [x] 5.1 Move BlueZ path into `hal/bluetooth`; keep Demo behavior
- [x] 5.2 Keyboard battery keepalive (periodic) as designed
- [x] 5.3 Demo cutover + smoke

## 6. Network stack + `hal/network` (largest; do last)

OS cutover first, then Dart modules against the new stack. Until then Demo may keep legacy ethernet/wifi/http-proxy paths behind thin façades or stay in App.

- [x] 6.1 Enable `BR2_PACKAGE_SYSTEMD_NETWORKD`; drop “networkd must stay off” long-term
- [x] 6.2 Ship wpa_supplicant with D-Bus (`BR2_PACKAGE_WPA_SUPPLICANT_DBUS`); `run-wpa.sh` **requires** `-u` (no soft-fallback); document L2=wpa / L3=networkd split
- [x] 6.2b Rebuild image so staged `wpa_supplicant` advertises `-u` and `systemd-networkd`/`networkctl`/`systemd-resolved` are present (`br-make-packages`, not overlay-only). **Gate:** `verify-rootfs-overlay` + on-device `verify-env` MUST FAIL without networkd/resolved/wpa D-Bus; no udhcpc/dhcpcd L3 fallback; no helper-written resolv.conf.
- [x] 6.2c Enable `BR2_PACKAGE_SYSTEMD_RESOLVED`; `/etc/resolv.conf` → resolved; drop hand-written resolv sync from `networkd-apply-ipv4.sh`
- [x] 6.3 Replace or delete eth0/wlan0 L3 scripts (networkd-only wrappers or remove)
- [x] 6.4 Rewrite `restore-settings` / wanted markers for networkd+wpa
- [x] 6.5 Board smoke: DHCP/static eth + Wi‑Fi assoc+IP; no address flapping
- [x] 6.6 Implement `apply-proxy` (multi-scheme, CLI-env-visible); migrate off `/var/lib/hmi/http-proxy`
- [x] 6.7 Accept proxy without requiring `curl` on the image: enable → new shell / sourced env shows `http(s)_proxy` (and friends) so **CLI tools that honor standard proxy env** use it; clear removes vars; reboot restore via HMI `LinuxProxy.restoreFromDisk` (no rootfs `apply-proxy` script; conf `/var/lib/network/proxy.conf`, env `/etc/network/proxy.env` + profile.d + `/etc/environment` + systemd `DefaultEnvironment`). **Board 2026-07-19:** A/B/C env open+clear+reapply PASS; image has BusyBox `wget`, no `curl`.
- [x] 6.8 Implement `hal/network` {ethernet, wifi} helpers; **live status via D-Bus** (wpa + networkd PropertiesChanged) — Timer/`wpa_cli`/`ip` poll MUST NOT be primary
- [x] 6.8b Wire Demo Wi‑Fi/Ethernet controllers to D-Bus status (same contract as HAL)
- [x] 6.9 Implement `hal/network/proxy`; Demo curl-based probe (App façade may still use legacy store until cutover)
- [x] 6.10 Spec/note camera eth0 via networkd reconfigure (P4/P5) — see `docs/network-stack.md`

### 6b. Portable apply (D11b) — unblock multi-product reuse

Tighten contract: apply in `cyber_hal`, not ynh960 iface-named scripts. No HTTP connectivity probe; Wi‑Fi preferred via RouteMetric.

- [x] 6.11 Record D11b in design/proposal/specs: in-package L3 apply + wpa D-Bus L2 commands; inject `WifiRadio`; Demo must use `cyber_hal/network` only
- [x] 6.12 Implement portable L3 apply in HAL (write `.network` + `networkctl`/network1; RouteMetric from board profile; replace defaults that call `eth0-*` / `wlan0-*` / `networkd-apply-ipv4.sh`)
- [x] 6.13 Implement wpa D-Bus Scan / AddNetwork / Select / Disconnect / Remove in HAL; remove product-default `wpa_cli` paths
- [x] 6.14 Add `WifiRadio` port; ynh960 adapter may call existing `wifi-stack-up/down`; HAL `setEnabled` uses the port only
- [x] 6.15 Wire `NetRole` / metrics / pref roots from `BoardProfile`; stop hard-coding `eth0`/`wlan0` paths in HAL defaults
- [x] 6.16 Demo cutover to HAL Streams/APIs; delete or stop shipping iface-named L3 wrappers from product path; update `restore-settings` to generic apply or HAL-equivalent; update `docs/network-stack.md`
  - **P0 single-stack (2026-07-18):** Demo Wi‑Fi/Ethernet Stream controllers live in `cyber_hal` (`LinuxWifiSession` / `LinuxEthernetSession`); Demo uses `BoardBindings.wifiSession()` / `ethernetSession()`; App platform paths are thin re-exports; proxy prefs via `LinuxProxy` + `apply-proxy`. Lifecycle: disconnect ≠ forget (no RemoveAllNetworks on disconnect).
- [x] 6.16b Delete iface-named L3 wrappers from overlay once restore uses HAL/`NetworkdIpv4Apply` (boot restore uses `networkd-apply-ipv4.sh`; thin iface aliases may remain for legacy units)
- [x] 6.17 Accept: second profile or smoke doc proves apply works with injected radio + stock networkd/wpa and **without** `eth0-dhcp.sh` / `wlan0-dhcp.sh` / `wifi-stack-up.sh` as HAL defaults

## 7. Follow-ons

- [x] 7.1 Stub/sim profile for P3.2 emulator
- [x] 7.2 Archive superseded `rust-hal-and-phase-realign` → `openspec/changes/archive/2026-07-18-rust-hal-and-phase-realign/`
- [x] 7.3 Decide config install path: Flutter assets only vs also `/usr/share/cyber_hal/`
- [x] 7.4 Product list of layout ids to ship beyond `us` / `ru`
- [x] 7.5 Optional: flutter-pi keyboard.conf mtime hot-reload (no HMI restart) — **skipped** (not required for v1; D15 restart path stays)

## 8. Cross-module portability (D22)

Audit follow-on: bluetooth / datetime / volume A2DP / usb-debug / BoardProfile wiring (non-network).

- [x] 8.1 Record D22 in design/proposal/specs (audit table + `BtStack` / injectable helpers / profile live wiring)
- [x] 8.2 Wire `BoardProfile` (or shared injectors) into Linux backends for datetime, debug, output, input, sys_info, bluetooth; Demo constructs via profile where practical
- [x] 8.3 Introduce `BtStack` (or equivalent) port; move `bt-stack-*` / A2DP / agent / alias / **hid-heal** defaults behind injection; remove non-injectable `static const` heal paths
- [x] 8.3a Make HID heal / status / hold paths constructor-injectable (partial D22; full `BtStack` port remains 8.3)
- [x] 8.4 Make volume A2DP helper path injectable; rename datetime default away from `wlan0-time-sync.sh` (keep board symlink `/usr/bin/sync-time`)
- [x] 8.5 `hal/debug/usb`: injectable OTG sysfs path + Dart kind-A path (helper optional fallback)
- [x] 8.6 gpio/modbus/sys_info: Demo uses profile asset/mount pointers instead of only `kYnh960*` / fixed mounts
- [x] 8.7 Accept: document or smoke that a second board profile can override all board Process paths without editing `cyber_hal` source defaults
