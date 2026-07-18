## ADDED Requirements

### Requirement: Dart HAL package
The system SHALL provide a Dart HAL package (git submodule or `packages/` tree), independent of any single product App and parallel to CyberUI, that exposes portable hardware/platform APIs. Product Apps SHALL depend on this package rather than embedding board-specific Linux paths or Process helpers for migrated capabilities. The package SHALL NOT require a Rust `hald` or equivalent IPC daemon as the Platform API.

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
- **THEN** documented imports SHALL be under `hal/network` (e.g. wifi subpackage), not a new portable type whose primary name is `WifiController`

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
The appliance image for HAL network modules SHALL enable systemd-networkd as the Layer-3 owner for ethernet and Wi‑Fi interfaces used by the product. Wi‑Fi Layer-2 association SHALL use wpa_supplicant D-Bus. The same interface MUST NOT be co-managed by dhcpcd or ad-hoc `ip addr` scripts while networkd is managing it. Camera eth0 dynamic addressing, when required, SHALL reconfigure networkd rather than bypassing it.

#### Scenario: No dual managers on eth0
- **WHEN** networkd is enabled and managing eth0
- **THEN** legacy `eth0-*.sh` / `ip addr` primary control paths MUST be removed or rewritten to only reconfigure networkd (D-Bus / networkctl / drop-ins)

#### Scenario: Wi‑Fi split
- **WHEN** the device associates to an AP
- **THEN** association SHALL go through wpa_supplicant and IPv4/IPv6 configuration for that iface SHALL go through networkd

#### Scenario: Remaining shell helpers
- **WHEN** a boot or camera helper script still exists after the networkd cutover
- **THEN** it SHALL apply L3 changes only via networkd and MUST NOT bypass networkd with raw `ip addr` or dhcpcd on the same iface

### Requirement: Persist cohesion with existing FHS
HAL mid-session writes SHALL use the existing `/var/lib/{wpa_supplicant,network,bluetooth,hmi}/` (and documented helpers) schema. HAL SHALL NOT introduce a parallel preference tree that breaks `settings-restore.service`. Boot restore of Wi‑Fi, ethernet, Bluetooth, backlight, volume, and **system proxy** MAY remain shell/systemd-owned. System proxy persist SHALL live under `/var/lib/network/` (see `hal-network-proxy`), not only under `/var/lib/hmi/http-proxy`.

#### Scenario: Reboot still restores Wi‑Fi
- **WHEN** Wi‑Fi was enabled via HAL and the device reboots
- **THEN** existing restore hooks SHALL still bring the stack back when `wifi-wanted` (or equivalent) is set

### Requirement: Config-driven GPIO and Modbus
`hal/gpio` and `hal/modbus` SHALL be constructed from a versioned config file (or parsed config object). Product indicator LEDs SHALL be expressed as named gpio lines in gpio config. Modbus register maps SHALL be expressed as named attributes in modbus config. Product Apps MUST NOT hard-code ynh960 pin numbers or Modbus addresses as the long-term pattern after cutover. GPIO and Modbus SHALL remain separate top-level modules (not under `hal/io`).

#### Scenario: Demo LEDs via gpio config
- **WHEN** the Demo toggles panel LEDs after gpio cutover
- **THEN** it SHALL open lines by config id (e.g. `led_red`) through `hal/gpio` and SHALL NOT embed `GPIO_5` paths in App Dart constants

#### Scenario: Demo Modbus via attribute ids
- **WHEN** the Demo reads firmware version after modbus cutover
- **THEN** it SHALL call `readAttribute("device.firmware_version")` (or equivalent id from config) and SHALL NOT embed register `0x0002` in App Dart constants

### Requirement: Physical keyboard layout via XKB pref
Physical USB/BT HID keyboard layout SHALL be applied through flutter-pi / libxkbcommon (XKB). `hal/input/keyboard` SHALL expose get/set/list layout APIs that persist layout (via `/etc/default/keyboard` and/or `/var/lib/hmi/keyboard.conf`). For v1, applying a new layout SHALL take effect by restarting flutter-pi / `hmi.service` so XKB is rebuilt at keyboard init. After that restart, the product App SHALL restore navigation to the previous route/page (brief flash is acceptable; most devices rarely change layout). Soft-keyboard layouts remain CyberIME and MUST NOT be implemented as Dart remapping of HID scancodes. A flutter-pi mtime hot-reload path MAY be added later as a non-blocking enhancement.

#### Scenario: US to Russian
- **WHEN** the App calls setLayout for `ru` (or equivalent) with xkeyboard-config present and flutter-pi has been restarted after persist
- **THEN** subsequent physical key events SHALL produce Russian layout characters

#### Scenario: Apply restarts then returns to prior page
- **WHEN** layout preference is changed via HAL in v1
- **THEN** flutter-pi / HMI SHALL restart to apply XKB, and after relaunch the App SHALL open the previous route/page rather than only the default home

### Requirement: Mouse settings via existing pref contract
`hal/input/mouse` SHALL formalize the P2.1 mouse preference contract: settings persist in `/var/lib/hmi/mouse.conf` and are applied through `apply-mouse-settings` (or equivalent injectable helper); flutter-pi SHALL continue to reload on file mtime without `SIGHUP` or HMI restart. Supported keys SHALL include at least `natural_scroll`, `scroll_speed`, `pointer_speed`, `pointer_size`, `primary_button`, and `pointer_axes`. Presence SHALL be observed via `/dev/input/by-id` (with documented fallbacks). The HAL MUST NOT synthesize pointer events in Dart and MUST NOT introduce a parallel preference tree. Bluetooth pairing/HOGP remains outside mouse (stays bluetooth).

#### Scenario: Settings apply without restart
- **WHEN** the App changes natural scroll or pointer speed via HAL
- **THEN** flutter-pi SHALL pick up `/var/lib/hmi/mouse.conf` via mtime poll and apply without restarting `hmi.service`

#### Scenario: Package migration preserves conf
- **WHEN** Demo migrates to `hal/input/mouse`
- **THEN** existing on-device `mouse.conf` contents SHALL remain valid and readable/writable through the HAL API

### Requirement: System info host inventory
The HAL SHALL provide `hal/sys_info` exposing a structured host snapshot including at least: board serial number; Linux kernel version; Flutter app version information; CPU core count and frequency summary; memory total (and available when obtainable); primary flash/storage capacity (and free space when obtainable for documented mount points); thermal zone temperatures when sysfs thermal is present; and uptime. Board/DT model and image/`os-release` build id SHOULD be included when available. `hal/sys_info` MUST NOT include Modbus- or lower-device-derived fields; those SHALL use `hal/modbus` attributes. A portable `hal/device_info` or `hal/http` module SHALL NOT be introduced. Live Wi‑Fi/ethernet addressing SHALL remain under `hal/network`, not sys_info. Missing sensors or nodes SHALL yield unavailable/null fields rather than failing the whole snapshot.

#### Scenario: SN and kernel from host
- **WHEN** the App requests a sys_info snapshot on device
- **THEN** serial number SHALL come from the board serial helper path and kernel version from the running Linux kernel, not from Modbus registers

#### Scenario: CPU memory storage thermal
- **WHEN** the App requests a sys_info snapshot on a typical RK356x image
- **THEN** the snapshot SHALL include CPU core count, a memory total, a storage capacity for the primary flash, and thermal readings when thermal zones exist

#### Scenario: Lower-device firmware not in sys_info
- **WHEN** a product shows laser/gun firmware from Modbus
- **THEN** those values SHALL be read via modbus attribute ids and MUST NOT appear as fields on `SysInfo`

### Requirement: Network module grouping
Ethernet, Wi‑Fi, and system proxy SHALL be grouped under `hal/network` with optional subpackage imports (`ethernet`, `wifi`, `proxy`). Apps MUST NOT be required to import bluetooth or unrelated modules to use network APIs.

#### Scenario: Import wifi only
- **WHEN** a product App needs only Wi‑Fi APIs
- **THEN** it SHALL be able to import `hal/network/wifi` without importing proxy or bluetooth

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

### Requirement: Migration from in-app platform
Existing `app/hmi/lib/platform/**` Linux backends SHALL be movable into the HAL package with App dependency cutover. After cutover, product App code SHALL NOT construct `LinuxWpaWifiController` (etc.) as the long-term pattern.

#### Scenario: Demo uses package
- **WHEN** migration milestone for a domain is complete
- **THEN** Demo SHALL obtain that domain’s API from the HAL package (directly or via thin façade)
