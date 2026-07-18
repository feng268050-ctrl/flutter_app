## Why

The prior Rust `hald` design over-complicated a stack that already works as Dart calling sysfs, D-Bus, and OS components. We need a **portable Dart HAL package** (parallel to CyberUI): Apps import only the modules they need; the package owns Linux backends, board/gpio/modbus config, and persist cohesion—without a second language or IPC daemon.

## What Changes

- **BREAKING (design):** Supersede `rust-hal-and-phase-realign`’s Rust/`hald` Platform API. No HAL systemd daemon.
- Introduce a **Dart HAL package** with optional modules: **`hal/network`** {ethernet, wifi, proxy}, **`hal/debug`** {ssh, usb}, **`hal/output`** {backlight, volume}, **`hal/input`** {keyboard, mouse}, **`hal/gpio`**, **`hal/modbus`**, `hal/bluetooth`, `hal/sys_info`, `hal/datetime` as needed.
- **Out of HAL:** App-level HTTP *clients* / URL *probes* (UI); Modbus-derived product identity; **display orientation API** (fixed at flutter-pi launch / board default; in-app video rotation = App). System proxy policy is IN HAL (`hal/network/proxy`).
- **Classify every module by backend kind** (normative for implementers):
  - **Device/sysfs (or char-dev I/O):** backlight, gpio, modbus serial, usb OTG bits, HID presence (read)
  - **D-Bus:** bluetooth (now); `hal/network` ethernet + wifi L2/L3 **after** stack switch (networkd + wpa)
  - **OS component / CLI helper:** volume (`amixer`), playback (`mpg123`), mouse settings, datetime, **`hal/debug`** (SSH/USB helpers), **network proxy apply**—not “write a volume device node”
- **BREAKING (OS):** Enable **systemd-networkd** for L3; **wpa_supplicant D-Bus** for Wi‑Fi L2. Legacy eth0/wlan0 L3 scripts are **deleted** or **rewritten as networkd-only wrappers**. Camera eth0 dynamic addressing reconfigures networkd.
- **BREAKING (HAL portability — D11b):** `hal/network` MUST NOT hard-depend on ynh960 `/usr/libexec/{network,wpa}/eth0-*|wlan0-*|wifi-stack-*` as the default apply path. **L3 apply** and **Wi‑Fi L2 commands** live in the Dart package (networkd drop-ins + D-Bus / `networkctl`; wpa D-Bus Scan/AddNetwork). Board packs inject only **radio bring-up**, `NetRole`→iface, route-metric policy, and pref roots. Demo MUST consume `package:cyber_hal/network` (no parallel script controllers as the product path). No HTTP connectivity probe; dual-default prefers Wi‑Fi via metrics.
- **BREAKING (HAL portability — D22):** Same reuse bar for **non-network** modules. `BoardProfile` (or equivalent injectors) MUST wire Linux backends — not only exist in tests. **Bluetooth** stack/A2DP/agent/HID-heal defaults MUST NOT hard-require `/usr/libexec/bluetooth/bt-*` as non-injectable paths (inject `BtStack` / heal ports; BlueZ D-Bus stays portable core). Rename/remove iface-named defaults (e.g. `wlan0-time-sync.sh`). Volume A2DP helper and USB OTG PHY paths injectable; USB debug SHOULD prefer sysfs (kind A) where possible. gpio/modbus remain config-OK; Demo already on HAL for these.
- **Three-layer config:**
  1. **Board profile** — capabilities + net roles → iface + pointers to gpio/modbus files
  2. **gpio config** — named lines (product LEDs = lines with roles); constructor-bound
  3. **modbus config** — RTU transport + **poll groups** + attribute catalog (regs + **alarm bits → readable ids**); App uses attribute ids + HAL watch (change-only)
- **Modbus dynamic layer (D14, revised):** HAL owns poll/`watchAttributes` (config interval, default 100 ms), contiguous group reads, command gate, exclusive sessions, and dirty-attribute callbacks; App owns alarm dialogs/episodes, not poll timers.- **Binding style:** backlight injects **sysfs/pref paths**; volume injects **ALSA card/control + pref path**; network uses roles + board profile; proxy uses system-wide env contract (D18).
- **Physical keyboard layout (D15):** XKB via `/etc/default/keyboard` (and/or `keyboard.conf`); **v1 apply = restart hmi** (no flutter-pi hot-reload patch required); CyberIME owns soft layouts only.
- **Mouse (D16):** formalize P2.1 contract — `/var/lib/hmi/mouse.conf` + `apply-mouse-settings` + flutter-pi mtime poll; presence via `/dev/input/by-id`; no new pi protocol.
- **Sys info (D17):** `hal/sys_info` host inventory — SN, board/DT model, kernel/image/app versions, CPU cores/freq, RAM, flash capacity/free, thermal zones, uptime/load — **not** Modbus fields; **no** `hal/http` or `hal/device_info`.
- **Network (D18):** single `hal/network` entry with ethernet / wifi / proxy subpackages; proxy is multi-scheme and system-wide (curl-visible).
- **No orientation HAL (D19):** drop `hal/orientation`; Demo has no orientation settings; launch `-o` is board/image fixed; video layout flips are App UI.
- **Debug (D20):** merge LAN SSH + USB OTG debug into one **`hal/debug`** package (optional ssh/usb entrypoints).
- **Grouped domains (D21):** `hal/output` {backlight, volume} (human-facing levels, paired with `hal/input`); `hal/input` {keyboard, mouse}. **GPIO and Modbus stay separate top-level** modules (`hal/gpio`, `hal/modbus`) — no forced `io`/`field` umbrella when naming does not fit.
- P3.1 = Dart HAL package + network stack migration (**implement easy HAL modules first; networkd/`hal/network` last** — see tasks §2–§7).

## Capabilities

### New Capabilities

- `dart-hal`: Package layout, module import rules, backend taxonomy, public APIs, persist rules, migration from `app/hmi/lib/platform`.
- `hal-board-profile`: Board profile (capability flags, net roles→iface, paths to gpio/modbus configs).
- `hal-gpio-config`: Schema for gpio config files consumed by `hal/gpio`.
- `hal-modbus-config`: Schema for modbus configs consumed by `hal/modbus`.
- `hal-network-proxy`: System-wide multi-scheme proxy under `hal/network/proxy`.

### Modified Capabilities

- Intent: existing `linux-*` Demo wiring moves behind the HAL package.
- `linux-gpio-rgb-led`: long-term satisfied by **gpio config** on ynh960, not a separate portable “RGB-only” HAL type.
- Phase docs: P3.1 = Dart HAL + networkd (already partially updated).

## Impact

- **Supersedes:** Rust/`hald` approach in `rust-hal-and-phase-realign` (CyberUI + phase table in docs remain).
- **New package:** **`cyber_hal`** (`packages/cyber_hal/`, parallel naming to CyberUI).
- **App:** consumer of HAL modules; hard-coded pin/register maps leave App where possible; Demo HTTP *probe* may call `curl` (inherits proxy) instead of a private Dart-only proxy.
- **Rootfs:** enable networkd + resolved; wpa D-Bus; thin board radio bring-up only (delete iface-named L3 wrappers once HAL apply lands); restore-settings; **proxy apply helper** (injectable path); no `hald`.
- **HAL reuse:** another product with stock networkd + wpa `-u` SHALL be able to use `cyber_hal` network modules by supplying a board profile + optional `WifiRadio` injector — without shipping this repo’s `eth0-dhcp.sh` / `wlan0-dhcp.sh` / `wifi-stack-up.sh` stack. Non-network modules likewise: BlueZ D-Bus + config-driven gpio/modbus + injectable helpers — without a mandatory full `bt-*` / RK-only tree as non-overridable defaults.
- **Deps:** add `modbus_client` (validate on aarch64/flutter-pi); keep `bluez`/`dbus`.
- **Docs:** plan §7.1 / P3.1; this change’s design D11–D21.
- **flutter-pi:** no new keyboard patch for D15 v1; optional later hot-reload. Mouse prefs already covered by existing patches (D16).
- **App retains:** URL probe UI / optional Dart HttpClient; Modbus attribute **presentation** (alarm dialogs/episodes) via `hal/modbus` watch values — **not** App-owned poll loops. **Proxy policy moves to HAL.**
- **Modbus:** HAL owns poll groups + change-only `watchAttributes`; bit alarms are config-mapped readable attributes (see design D14).
