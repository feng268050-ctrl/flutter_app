# dart-hal Specification

## Purpose
Portable Dart HAL (`cyber_hal`) for Buildroot / flutter-pi **Linux** appliances. Product Apps import modules on demand. Scope is Linux backends (`Linux*`) plus stub/sim — **not** Android platform adapters (P5.0 APK uses App-side Android / `YNHAPI`; Android already has its own HAL).

## Requirements
### Requirement: Dart HAL package
The system SHALL provide a Dart HAL package (git submodule or `packages/` tree), independent of any single product App and parallel to CyberUI, that exposes portable hardware/platform APIs for the **Linux** appliance image. Product Apps on Linux SHALL depend on this package rather than embedding board-specific Linux paths or Process helpers for migrated capabilities. The package SHALL NOT require a Rust `hald` or equivalent IPC daemon as the Platform API. The package SHALL NOT implement Android-specific backends; Android product compatibility remains App-layer.

#### Scenario: App imports network module only
- **WHEN** a product App needs Wi‑Fi/ethernet APIs
- **THEN** it SHALL be able to import the HAL network entrypoint without being required to import bluetooth, audio, or display modules

#### Scenario: No hald required
- **WHEN** the HMI runs on device with HAL-backed brightness
- **THEN** brightness control SHALL work via the Dart HAL talking to existing OS helpers/sysfs without a separate HAL systemd API daemon

### Requirement: Backend taxonomy
Every HAL module SHALL declare exactly one primary backend kind: **device/sysfs**, **D-Bus**, or **OS component/helper**. Volume SHALL bind ALSA mixer (card/control) plus preference path, NOT a volume device node. Prefs under `/var/lib/hmi/*` SHALL be treated as policy storage for restore, not as device files.

#### Scenario: Volume is mixer not device
- **WHEN** an App constructs the volume API
- **THEN** constructor/bindings SHALL accept ALSA card/control (and optional pref path) and MUST NOT require a char-device path for volume

### Requirement: Industry-style public API
Portable HAL public types SHALL use system-service vocabulary including at least: `Capabilities` / `BoardInfo`; under `hal/network`: network device/role APIs plus `ProxySettings`; under `hal/output`: backlight and volume; under `hal/input`: keyboard and mouse; `hal/gpio`; `hal/modbus`; under `hal/debug`: SSH and USB debug; `BluetoothManager` / related; `TimeService`; `SysInfo`. Implementation types (`Linux*`, `*Backend`) MUST NOT be required by product App code. Temporary `*Controller` wrappers MAY exist during migration. The HAL package MUST NOT expose a top-level `hal/http` module or a `DisplayOrientation` / `hal/orientation` API. Long-term public layout SHALL use grouped packages where decided (`hal/output`, `hal/input`, `hal/network`, `hal/debug`) and top-level `hal/gpio` / `hal/modbus` (not under an `io`/`media` umbrella). URL probe UI stays in the App. System proxy policy SHALL live under `hal/network/proxy`. Panel orientation is launch/board-fixed (D19).

#### Scenario: New integration uses network module
- **WHEN** a new Settings page integrates Wi‑Fi through HAL
- **THEN** documented imports SHALL be under `package:cyber_hal/network` (e.g. wifi subpackage), not a new portable type whose primary name is `WifiController`

### Requirement: Optional capabilities
Every HAL domain SHALL be optional. The package SHALL expose capability discovery from board profile (and optional runtime probes). Invoking an absent capability SHALL fail with a structured unsupported error. Valid products include no display, no audio, and/or no network.

#### Scenario: Headless build
- **WHEN** board profile omits display/backlight
- **THEN** importing unused display APIs MAY be avoided by the App, and brightness APIs SHALL report unsupported if called

### Requirement: Network roles not ifaces in App code
Network APIs SHALL address devices by `NetRole`. Board profile SHALL map roles to interface names. Product App code MUST NOT hard-code `eth0` / `wlan0` as the long-term pattern.

#### Scenario: ynh960 role map
- **WHEN** using the ynh960 profile
- **THEN** roles such as `ethernet.primary` and `wifi.station` MAY map to `eth0` and `wlan0` while App code addresses roles only

### Requirement: systemd-networkd owns L3
The appliance image for HAL network modules SHALL enable systemd-networkd as the Layer-3 owner for ethernet and Wi‑Fi interfaces used by the product. DNS SHALL be provided by **systemd-resolved** (Buildroot `BR2_PACKAGE_SYSTEMD_RESOLVED`), with `/etc/resolv.conf` managed as a symlink into resolved’s runtime resolv file. Network apply helpers MUST NOT write `/etc/resolv.conf` or `/tmp/resolv.conf` themselves. Wi‑Fi Layer-2 association SHALL use wpa_supplicant with the D-Bus control interface enabled (`wpa_supplicant -u`; Buildroot `BR2_PACKAGE_WPA_SUPPLICANT_DBUS`). The same interface MUST NOT be co-managed by dhcpcd or ad-hoc `ip addr` scripts while networkd is managing it. Camera eth0 dynamic addressing, when required, SHALL reconfigure networkd rather than bypassing it.

#### Scenario: No dual managers on eth0
- **WHEN** networkd is enabled and managing eth0
- **THEN** legacy `eth0-*.sh` / `ip addr` primary control paths MUST be removed or rewritten to only reconfigure networkd (D-Bus / networkctl / drop-ins)

#### Scenario: DNS via resolved
- **WHEN** networkd learns DNS from DHCP or a static `.network` `DNS=` entry
- **THEN** name resolution SHALL go through systemd-resolved (not a helper-written resolv.conf)

#### Scenario: Dual default prefers Wi‑Fi
- **WHEN** both eth0 and wlan0 have a default route via networkd
- **THEN** the Wi‑Fi default SHALL have a lower route metric than eth0 so Internet egress prefers wlan0 (eth0 on-link / camera LAN remains usable)

#### Scenario: Wi‑Fi split
- **WHEN** the device associates to an AP
- **THEN** association SHALL go through wpa_supplicant and IPv4/IPv6 configuration for that iface SHALL go through networkd

#### Scenario: Remaining shell helpers
- **WHEN** a boot or camera helper script still exists after the networkd cutover
- **THEN** it SHALL apply L3 changes only via networkd (or call portable HAL/generic apply) and MUST NOT bypass networkd with raw `ip addr` or dhcpcd on the same iface
- **AND** iface-named L3 wrappers (`eth0-dhcp.sh`, `wlan0-dhcp.sh`, …) MUST be removed once D11b HAL apply is the product path

#### Scenario: wpa refuses to start without D-Bus
- **WHEN** `wpa_supplicant` was built without `CONFIG_CTRL_IFACE_DBUS_NEW` (no `-u` in help)
- **THEN** `run-wpa.sh` / `wlan-wpa.service` MUST fail to start and MUST NOT fall back to ctrl_iface-only

### Requirement: Network live status via D-Bus
Live Wi‑Fi and ethernet status presented to the UI / HAL Streams SHALL use **D-Bus** as the primary observation path: Wi‑Fi L2 via `fi.w1.wpa_supplicant1` (Interface `PropertiesChanged` and related signals); ethernet and Wi‑Fi L3 addressing via `org.freedesktop.network1` (Link `PropertiesChanged`). Periodic `Timer` + `wpa_cli status` / `networkctl` / `ip` polling MUST NOT be the primary status path. A one-shot D-Bus Get after subscribe attach or after bus reconnect is allowed for reconciliation.

#### Scenario: Association updates without poll
- **WHEN** wpa_supplicant transitions Interface `State` to `completed`
- **THEN** the HAL/App connection Stream SHALL emit an updated associated/connected state driven by the D-Bus property change, not by a status Timer tick

#### Scenario: DHCP address without poll
- **WHEN** networkd assigns an IPv4 address on the role-mapped iface
- **THEN** the HAL/App link Stream SHALL update from networkd D-Bus (Link `PropertiesChanged` for state; address details via `Link.Describe` JSON and/or the older Link `Addresses` property), not from periodic `ip addr` polling

### Requirement: Portable network apply (D11b)
`hal/network` ethernet and wifi apply paths SHALL be implemented inside `cyber_hal` against stock **systemd-networkd** and **wpa_supplicant D-Bus**, using `BoardProfile` (or constructor injection) for iface names, route metrics, and preference roots. Product Apps and Demo MUST call `package:cyber_hal/network` APIs. HAL defaults MUST NOT invoke board-specific iface-named scripts such as `eth0-dhcp.sh`, `eth0-static.sh`, `eth0-link.sh`, `wlan0-dhcp.sh`, `wlan0-static.sh`, or `wifi-stack-up.sh` / `wifi-stack-down.sh`.

- **L3 apply:** write a standard `.network` drop-in (including DHCP/static and RouteMetric from profile) and apply via `networkctl` and/or `org.freedesktop.network1`. An optional **generic** injectable apply helper (no `eth0`/`wlan0` in the basename) MAY be used only if in-process writes lack privilege.
- **L2 commands:** scan, connect, disconnect, forget, and list saved networks SHALL use wpa D-Bus methods. `wpa_cli` MUST NOT be the product default.
- **Wi‑Fi radio / PHY bring-up:** SHALL go through an injected `WifiRadio` (or equivalent) port. The ynh960 board pack MAY implement that port by calling existing stack scripts; other products supply their own implementation.
- **Proxy:** remains kind C with an **injectable** apply-proxy path.
- **Non-goals:** HTTP connectivity / captive-portal probing in HAL.

#### Scenario: Another product reuses HAL without ynh960 scripts
- **WHEN** a product image provides networkd, resolved, wpa `-u`, a board profile, and a `WifiRadio` implementation
- **THEN** that product SHALL be able to use `cyber_hal` ethernet/wifi apply and status without shipping this repository’s `eth0-*` / `wlan0-*` / `wifi-stack-*` helpers

#### Scenario: Demo does not call libexec network wrappers
- **WHEN** Demo enables ethernet DHCP or connects to Wi‑Fi after D11b cutover
- **THEN** the call stack SHALL go through `cyber_hal` network APIs and MUST NOT `Process.run` iface-named `/usr/libexec/network/eth0-*` or `/usr/libexec/wpa/wlan0-*` scripts

#### Scenario: Scan via D-Bus
- **WHEN** the App requests a Wi‑Fi scan
- **THEN** HAL SHALL use wpa D-Bus scan APIs and MUST NOT require `wpa_cli scan` as the primary path

### Requirement: Persist cohesion with existing FHS
HAL mid-session writes SHALL use the existing `/var/lib/{wpa_supplicant,network,bluetooth,hmi}/` (and documented helpers) schema. HAL SHALL NOT introduce a parallel preference tree that breaks `settings-restore.service`. Boot restore of Wi‑Fi, ethernet, Bluetooth, backlight, volume, and **system proxy** MAY remain shell/systemd-owned. System proxy persist SHALL live under `/var/lib/network/` (see `hal-network-proxy`), not only under `/var/lib/hmi/http-proxy`.

#### Scenario: Reboot still restores Wi‑Fi
- **WHEN** Wi‑Fi was enabled via HAL and the device reboots
- **THEN** existing restore hooks SHALL still bring the stack back when `wifi-wanted` (or equivalent) is set

### Requirement: Config-driven GPIO and Modbus
`hal/gpio` and `hal/modbus` SHALL be constructed from a versioned config file (or parsed config object). Product indicator LEDs SHALL be expressed as named gpio lines in gpio config. Modbus register maps SHALL be expressed as named attributes in modbus config (including bitfield alarms as human-readable attribute ids). Product Apps MUST NOT hard-code ynh960 pin numbers or Modbus addresses/bitmasks as the long-term pattern after cutover. GPIO and Modbus SHALL remain separate top-level modules (not under `hal/io`). **Product** `gpio.json` / `modbus.json` catalogs SHALL be owned by the product App (or pack) and referenced from `BoardProfile.configs`; they MUST NOT be shipped under `packages/cyber_hal/boards/<board_id>/` as the sole product map (the same motherboard may serve multiple products).

#### Scenario: Demo LEDs via gpio config
- **WHEN** the Demo toggles panel LEDs after gpio cutover
- **THEN** it SHALL open lines by config id (e.g. `led_red`) through `hal/gpio` and SHALL NOT embed `GPIO_5` paths in App Dart constants

#### Scenario: Demo Modbus via attribute ids
- **WHEN** the Demo reads control card version after modbus cutover
- **THEN** it SHALL call `readAttribute("device.control_card_version")` (or equivalent id from config) and SHALL NOT embed register `0x0002` in App Dart constants

### Requirement: HAL-owned Modbus observation
`hal/modbus` SHALL own continuous polling for configured continuous groups (interval from config, default 100 ms), contiguous group reads, inter-command spacing, and busy-tick discard. It SHALL expose watch/subscribe APIs that deliver **only changed attributes** (list of dirty attribute id+value pairs per emission). Product Apps MUST NOT implement Modbus poll loops for those groups. Alarm bitfields SHALL be consumed as decoded attributes, not raw words. Dialog/episode policy for alarms remains in the App; HAL supplies attribute values and optional read-health for C001-class faults.

#### Scenario: Change-only callback
- **WHEN** a poll cycle updates several registers but only two configured attributes change after decode
- **THEN** the watch emission SHALL list exactly those two attributes

#### Scenario: No App Timer poll
- **WHEN** a product screen displays live gun temperature and alarm flags from continuous groups
- **THEN** it SHALL use HAL watch APIs and MUST NOT use a Flutter `Timer` to repeatedly `readAttribute` those ids

### Requirement: Physical keyboard layout via XKB pref
Physical USB/BT HID keyboard layout SHALL be applied through flutter-pi / libxkbcommon (XKB). `hal/input/keyboard` SHALL expose get/set/list layout APIs that persist layout (via `/etc/default/keyboard` and/or `/var/lib/hmi/keyboard.conf`). For v1, applying a new layout SHALL take effect by restarting flutter-pi / `hmi.service` so XKB is rebuilt at keyboard init. After that restart, the product App SHALL restore navigation to the previous route/page (brief flash is acceptable; most devices rarely change layout). Soft-keyboard layouts remain CyberIME and MUST NOT be implemented as Dart remapping of HID scancodes. A flutter-pi mtime hot-reload path MAY be added later as a non-blocking enhancement. **Product Settings SHALL offer at least the US / DE / FR / JP layouts** corresponding to ANSI / QWERTZ / AZERTY / JIS profiles; Demo-only layouts (e.g. `ru`) MAY remain available to Demo surfaces without appearing in the product Segment.

#### Scenario: US to Russian
- **WHEN** the App calls setLayout for `ru` (or equivalent) with xkeyboard-config present and flutter-pi has been restarted after persist
- **THEN** subsequent physical key events SHALL produce Russian layout characters

#### Scenario: Apply restarts then returns to prior page
- **WHEN** layout preference is changed via HAL in v1
- **THEN** flutter-pi / HMI SHALL restart to apply XKB, and after relaunch the App SHALL open the previous route/page rather than only the default home

#### Scenario: Apply German layout from product profile
- **WHEN** the product Keyboard settings applies the ISO DE profile via HAL setLayout
- **THEN** after HMI restart, physical key events follow the German XKB layout

### Requirement: Product physical layouts include US DE FR JP

`hal/input/keyboard` `listLayouts` used by the product Keyboard settings SHALL include XKB layouts covering at least English US (`us`), German (`de`), French (`fr`), and Japanese (`jp`, with model suitable for JIS such as `jp106`). Display names SHOULD align with the product profile labels. Soft-keyboard rendering remains CyberIME; physical text MUST continue to go through XKB, not Dart scancode remapping.

#### Scenario: listLayouts contains four product ids

- **WHEN** the App calls `listLayouts` for product Keyboard settings
- **THEN** the result includes entries whose ids are `us`, `de`, `fr`, and `jp` (or documented aliases mapped 1:1 to those profiles)

### Requirement: Mouse settings via existing pref contract
`hal/input/mouse` SHALL formalize the P2.1 mouse preference contract: settings persist in `/var/lib/hmi/mouse.conf` and are applied through `apply-mouse-settings` (or equivalent injectable helper); flutter-pi SHALL continue to reload on file mtime without `SIGHUP` or HMI restart. Supported keys SHALL include at least `natural_scroll`, `scroll_speed`, `pointer_speed`, `pointer_size`, `primary_button`, and `pointer_axes`. Presence SHALL be observed via `/dev/input/by-id` (with documented fallbacks). The HAL MUST NOT synthesize pointer events in Dart and MUST NOT introduce a parallel preference tree. Bluetooth pairing/HOGP remains outside mouse (stays bluetooth).

#### Scenario: Settings apply without restart
- **WHEN** the App changes natural scroll or pointer speed via HAL
- **THEN** flutter-pi SHALL pick up `/var/lib/hmi/mouse.conf` via mtime poll and apply without restarting `hmi.service`

#### Scenario: Package migration preserves conf
- **WHEN** Demo migrates to `hal/input/mouse`
- **THEN** existing on-device `mouse.conf` contents SHALL remain valid and readable/writable through the HAL API

### Requirement: System info host inventory

The HAL SHALL provide `hal/sys_info` exposing a structured host snapshot including at least: board serial number (product SN); chip ID; product `brand` and product `model` when sourced from product identity (`product.ini` / `ProductInfo`); Linux kernel version; Flutter app version information; CPU core count and frequency summary; memory total (and available when obtainable); primary flash/storage capacity (and free space when obtainable for documented mount points); thermal zone temperatures when sysfs thermal is present; and uptime. Board/DT model and image/`os-release` build id SHOULD be included when available (DT model remains distinct from product `model`). Board serial number SHALL resolve via product identity SN rules (non-empty `product.ini` `sn`, else chip ID). Chip ID SHALL be the chip/board serial and MUST NOT use the factory `product.ini` `sn` key. `hal/sys_info` MUST NOT include Modbus- or lower-device-derived fields; those SHALL use `hal/modbus` attributes. Extended product tunables (`camera_ip`, `camera_type`, `focus_scale_ref`, `control_card_comm_alarm_mode`, and future keys) SHALL be exposed via HAL `ProductInfo` accessors, not as required `SysInfoSnapshot` inventory fields. A portable `hal/device_info` or `hal/http` module SHALL NOT be introduced. Live Wi‑Fi/ethernet addressing SHALL remain under `hal/network`, not sys_info. Missing sensors or nodes SHALL yield unavailable/null fields rather than failing the whole snapshot; missing product brand/model SHALL yield empty strings on the product identity surface. `SysInfo.watch` SHALL emit a primed snapshot then change-only updates when volatile fields (thermal, CPU freq, available memory, load) change.

#### Scenario: SN and kernel from host

- **WHEN** the App requests a sys_info snapshot on device
- **THEN** serial number SHALL come from product identity SN resolution (product.ini `sn` or chip ID) and kernel version from the running Linux kernel, not from Modbus registers

#### Scenario: Chip ID on snapshot

- **WHEN** the App requests a sys_info snapshot and chip serial is available
- **THEN** the snapshot SHALL include `chipId` equal to the chip serial even when product.ini overrides SN

#### Scenario: Brand and model on snapshot

- **WHEN** `product.ini` defines `brand` and `model` and the App requests a sys_info snapshot
- **THEN** the snapshot SHALL include those product brand and model strings

#### Scenario: CPU memory storage thermal

- **WHEN** the App requests a sys_info snapshot on a typical RK356x image
- **THEN** the snapshot SHALL include CPU core count, a memory total, a storage capacity for the primary flash, and thermal readings when thermal zones exist

#### Scenario: Lower-device firmware not in sys_info

- **WHEN** a product shows laser/gun firmware from Modbus
- **THEN** those values SHALL be read via modbus attribute ids and MUST NOT appear as fields on `SysInfo`

#### Scenario: Extended tunables via ProductInfo

- **WHEN** the App needs `camera_ip` or `control_card_comm_alarm_mode`
- **THEN** it SHALL read them from HAL `ProductInfo` accessors rather than from `SysInfoSnapshot` inventory fields

#### Scenario: Comm alarm mode applied to Modbus health

- **WHEN** `ProductInfo.controlCardCommAlarmMode()` returns `slide_window` or `immediate`
- **THEN** the App SHALL apply that mode to Modbus HAL health-window override before relying on C001
- **AND** when the accessor returns empty, Modbus SHALL keep `modbus.json` `poll.health.mode`

### Requirement: Network module grouping
Ethernet, Wi‑Fi, and system proxy SHALL be grouped under `hal/network` with optional subpackage imports (`ethernet`, `wifi`, `proxy`). Apps MUST NOT be required to import bluetooth or unrelated modules to use network APIs.

#### Scenario: Import wifi only
- **WHEN** a product App needs only Wi‑Fi APIs
- **THEN** it SHALL be able to import `package:cyber_hal/network/wifi.dart` without importing proxy or bluetooth

### Requirement: No portable orientation HAL
The HAL package MUST NOT expose `hal/orientation` or a portable `DisplayOrientation` Manager for mid-session flutter-pi `-o` changes. Panel orientation SHALL be treated as a fixed board/image launch parameter. Temporary layout changes for media playback SHALL remain product App UI. The P2 Demo MUST NOT include system orientation controls.

#### Scenario: Demo has no orientation settings
- **WHEN** the P2 Demo home is shown
- **THEN** it MUST NOT offer Portrait/Landscape controls that persist or restart HMI for flutter-pi orientation

### Requirement: Domain package grouping
Related capabilities SHALL be grouped under domain packages with optional sub-imports where naming fits: `hal/network` {ethernet, wifi, proxy}; `hal/output` {backlight, volume}; `hal/input` {keyboard, mouse}; `hal/debug` {ssh, usb}. `hal/gpio` and `hal/modbus` SHALL remain separate top-level modules. Apps MUST be able to import a single subpackage without pulling unused siblings.

#### Scenario: Volume without backlight
- **WHEN** a product App needs only volume
- **THEN** it SHALL be able to import `hal/output/volume` without importing backlight

#### Scenario: Gpio without modbus
- **WHEN** a product App needs only gpio lines
- **THEN** it SHALL import `hal/gpio` and MUST NOT be required to depend on `hal/modbus`

### Requirement: Debug module grouping
LAN SSH debug and USB OTG / plug-ssh debug SHALL be grouped under `hal/debug`, with optional sub-imports for ssh and usb. Top-level modules named `hal/ssh_debug` or `hal/usb_debug` MUST NOT be the long-term public layout.

#### Scenario: Import usb debug only
- **WHEN** a product App needs only USB debug role control
- **THEN** it SHALL be able to import `hal/debug/usb` (or equivalent) without importing wifi or bluetooth

### Requirement: Cross-module portability (D22)
Linux backends outside `hal/network` SHALL meet the same reuse bar as D11b: board-specific Process paths and vendor sysfs nodes MUST be injectable (via `BoardProfile` and/or constructors). `BoardProfile` MUST be usable as live wiring for backends, not only in unit tests.

- **`hal/bluetooth`:** device/adapter APIs SHALL use BlueZ D-Bus as the portable core. Stack bring-up, A2DP sink orchestration, pairing agent ensure, and HID heal SHALL go through an injected board port (`BtStack` or equivalent). HAL MUST NOT leave heal or A2DP helper paths as non-overridable private constants.
- **Kind C helpers** (`hal/datetime` sync, `hal/debug/ssh`, backlight/volume/mouse apply, volume A2DP): every default argv/path MUST be overridable. HAL default names SHOULD avoid iface prefixes (e.g. prefer `sync-time` over `wlan0-time-sync.sh`).
- **`hal/debug/usb`:** SHOULD prefer OTG role via injectable sysfs (kind A); an optional helper MAY remain as fallback.
- **`hal/gpio` / `hal/modbus` / `hal/sys_info`:** remain config/`/proc`-driven; Demo/App SHALL resolve gpio/modbus assets and storage mounts from the board profile when present. Product catalogs are App assets (e.g. `assets/hal/gpio.json`), not board-named files inside `cyber_hal`.

#### Scenario: Other product without bt-* tree
- **WHEN** a product provides BlueZ and a `BtStack` implementation (or no-op where radio is absent)
- **THEN** it SHALL be able to use `hal/bluetooth` device APIs without shipping this repository’s full `/usr/libexec/bluetooth/bt-*` set as non-overridable HAL defaults

#### Scenario: HID heal path injectable
- **WHEN** constructing the Linux bluetooth backend
- **THEN** HID heal helper and status directory paths SHALL be injectable and MUST NOT exist only as private `static const` values

#### Scenario: Time sync helper without iface name
- **WHEN** using default datetime network sync after D22
- **THEN** the HAL default helper path SHALL NOT be iface-prefixed (`wlan0-…`); ynh960 MAY still ship a symlink or board override to an existing script

#### Scenario: Profile wires gpio asset
- **WHEN** Demo constructs gpio HAL with a loaded `BoardProfile`
- **THEN** it SHALL use the profile’s gpio config asset pointer (App-owned `assets/…` URI) and MUST NOT fall back to a hard-coded `packages/cyber_hal/boards/<board>/gpio.json` constant

### Requirement: Migration from in-app platform
Existing `app/hmi/lib/platform/**` Linux backends SHALL be movable into the HAL package with App dependency cutover. After cutover, product App code SHALL NOT construct `LinuxWpaWifiController` (etc.) as the long-term pattern.

#### Scenario: Demo uses package
- **WHEN** migration milestone for a domain is complete
- **THEN** Demo SHALL obtain that domain’s API from the HAL package (directly or via thin façade)

