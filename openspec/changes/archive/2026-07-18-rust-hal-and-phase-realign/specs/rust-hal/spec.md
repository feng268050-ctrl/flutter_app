## ADDED Requirements

### Requirement: Industry-style public naming
Portable HAL public API types SHALL use system-service vocabulary: entry `HalClient`; discovery `Capabilities` / `BoardInfo`; network `NetworkManager` / `NetworkDevice` / `Connection` / `LinkState` / `IpConfig` (and Wi‑Fi scan types as needed); Bluetooth `BluetoothManager` / `BluetoothAdapter` / `BluetoothDevice`; display `Brightness` (or `Backlight`) and `DisplayOrientation`; audio `AudioManager` / `Volume`; time `TimeService`; input `InputManager` / `InputDevice` / `MouseSettings`. Implementation types (`*Backend`, `Linux*`) MUST NOT be required by product Apps. Flutter `*Controller` names MAY exist only as temporary App façades during migration.

#### Scenario: Network API does not use Controller suffix
- **WHEN** a new App integrates Wi‑Fi via HAL
- **THEN** the documented HAL surface SHALL be `NetworkManager` / `NetworkDevice` (or equivalent D12 names), not a new portable type named `WifiController`

#### Scenario: Capabilities discovery naming
- **WHEN** a client connects to `hald`
- **THEN** it SHALL obtain a `Capabilities` (or equivalent) set before assuming any optional domain Manager is present

### Requirement: Language-agnostic Platform API
The system SHALL provide a versioned Hardware Abstraction / Platform API implemented in Rust such that product Flutter Apps do not perform board-specific sysfs, D-Bus, or libexec Process calls for migrated capabilities. The API SHALL be consumable by a Dart client package without requiring knowledge of motherboard pin maps or kernel netdev names.

#### Scenario: App uses HAL client for backlight
- **WHEN** a Flutter caller sets display brightness through the HAL Dart client on a device that advertises backlight
- **THEN** the call SHALL reach the Rust HAL implementation (daemon or library) via the brightness/backlight API and SHALL NOT write backlight preference files solely from Dart

#### Scenario: Version negotiation
- **WHEN** a client connects to the HAL service
- **THEN** the service SHALL report an API major/minor version and REJECT incompatible major versions with a structured error

### Requirement: Optional capabilities
Every HAL capability SHALL be optional. At connect time the HAL SHALL advertise which capabilities (and network roles) are present. Clients MUST NOT assume display, audio, Wi‑Fi, ethernet, Bluetooth, Modbus, or HID are available. Invoking an absent capability SHALL return a structured unsupported/unavailable error and MUST NOT crash `hald` or the client process.

#### Scenario: Headless product without volume
- **WHEN** a board profile omits audio/volume capability
- **THEN** capability discovery SHALL report volume absent and a volume set request SHALL fail with unsupported (not a silent no-op success)

#### Scenario: No Wi‑Fi SKU
- **WHEN** a product image has no Wi‑Fi hardware/stack and the profile does not advertise Wi‑Fi
- **THEN** HAL SHALL not require wpa_supplicant to be running for `hald` to start successfully

### Requirement: Network roles not fixed iface names
The HAL Platform API SHALL identify network interfaces by **role** (for example primary ethernet, station Wi‑Fi), not by requiring the kernel names `eth0` or `wlan0`. The board profile SHALL map each advertised role to a concrete netdev name. A given board pack MAY choose to name devices `eth0`/`wlan0` for operational convenience; that naming is pack-local, not a cross-product HAL requirement.

#### Scenario: Role map on ynh960
- **WHEN** HAL loads the ynh960 profile
- **THEN** it MAY map `ethernet.primary`→`eth0` and `wifi.station`→`wlan0` (or documented equivalents) while clients address roles only

#### Scenario: Alternate iface name
- **WHEN** a future board pack maps `ethernet.primary`→`end0` (or another name)
- **THEN** HAL clients using the ethernet role SHALL continue to work without App changes to hard-coded `eth0` strings

### Requirement: HAL packaging as submodule
The HAL SHALL exist as a git submodule or clearly separated package tree under the lws-hmi workspace (parallel to CyberUI), with its own crate/workspace layout, so it can be developed and version-pinned independently of a single product App.

#### Scenario: In-repo layout
- **WHEN** a developer clones lws-hmi with submodules initialized
- **THEN** the HAL sources SHALL be reachable under the documented path (e.g. `hal/`) without copying into `app/hmi/lib/platform`

### Requirement: Board profile driven hardware maps
The HAL SHALL load a board (and optional screen) profile that supplies at least: board id, advertised capability set, network role→iface map for present network roles, and—only when the corresponding capability is advertised—Modbus serial device path, default display orientation, radio bringup plugin identifier, and audio route hints. Hardcoded board paths in application Dart SHALL NOT remain the long-term source of truth after cutover for HAL-owned capabilities.

#### Scenario: ynh960 profile without LED map in HAL
- **WHEN** HAL starts on a ynh960 image with the ynh960 board pack installed
- **THEN** Modbus (if advertised) SHALL use the profile’s device path without App-level `/dev/ttyS5` constants, and the HAL profile SHALL NOT be required to define product RGB LED sysfs maps

### Requirement: Product indicator LEDs out of HAL
Portable HAL SHALL NOT expose product RGB / indicator LED control as a shared capability. Product-specific LEDs (paths and pins that vary by vendor) remain in the product App or a product-local adapter outside `hald`’s public API.

#### Scenario: Demo LEDs stay product-local
- **WHEN** the current welder Demo toggles red/yellow/green panel LEDs
- **THEN** that path MAY remain outside HAL and MUST NOT block HAL acceptance for other capabilities

### Requirement: P2 capability coverage (optional catalog)
The HAL capability catalog MAY include facilities already validated in Linux P2 preparation—Modbus RTU parameters, media volume, ethernet, Wi‑Fi, Bluetooth, USB HID keyboard/mouse presence or settings, backlight, display orientation preference, date/time, mouse settings, SSH/USB debug—as **optional** entries. Migration is incremental; a documented matrix SHALL mark each in-scope item `legacy-dart`, `hal-shim`, `hal-native`, or `out-of-hal` (e.g. product LEDs).

#### Scenario: Capability matrix published
- **WHEN** P3.1 HAL work is accepted
- **THEN** documentation SHALL list each P2 Demo-related facility with one of those statuses and SHALL mark product RGB LEDs as `out-of-hal`

### Requirement: Event-oriented observation
For **advertised** capabilities that present live OS state to UI, the Rust HAL SHALL use OS event sources as the **primary** observation path: ethernet via netlink on the role-mapped iface; Wi‑Fi via wpa_supplicant control-interface events; Bluetooth via BlueZ D-Bus PropertiesChanged/ObjectManager; LAN SSH debug via systemd unit property subscription; USB HID keyboard presence via udev; backlight via inotify (or equivalent) on sysfs brightness; media volume via ALSA mixer notification when available; datetime timezone/sync via timedate1 and/or preference file watch (UI one-second clock tick remains presentation-only). Dart clients SHALL observe via Streams fed by HAL events. Primary Timer + `Process.run` status loops SHALL NOT be used for these capabilities after HAL cutover. A rare reconciliation Get after event-channel reconnect is allowed. Absent capabilities SHALL NOT install corresponding watchers.

#### Scenario: External Wi‑Fi change
- **WHEN** Wi‑Fi association state changes outside the Flutter UI after Wi‑Fi is HAL-migrated and advertised
- **THEN** the HAL client Stream SHALL emit an updated snapshot without requiring the operator to re-open Demo

#### Scenario: External ethernet admin down
- **WHEN** an operator downs the role-mapped ethernet iface (or unplugs the cable) after ethernet is HAL-migrated
- **THEN** the Demo/Settings ethernet UI SHALL update through the HAL client Stream without re-entering the page

#### Scenario: No primary bluetoothctl poll
- **WHEN** Bluetooth peer list is shown after Bluetooth is HAL-migrated
- **THEN** the implementation SHALL NOT use a repeating `bluetoothctl` Process poll as the primary status path

### Requirement: Event-driven non-goals
The following SHALL remain outside the HAL event-migration mandate: Modbus request/response telemetry (optional slow UI refresh OK); display orientation mid-session without HMI restart; HTTP probe as on-demand request/response; product indicator LED mode matrices.

#### Scenario: Modbus not forced onto OS event bus
- **WHEN** Demo shows Modbus register values
- **THEN** the system MAY continue request/response polling on the serial bus and SHALL NOT be required to invent a netlink-style event source for those registers

### Requirement: Coexistence with shell persist
Until a capability is fully owned by HAL, boot restore and verb-noun helpers under `/usr/libexec/*` and state under `/var/lib/*` SHALL remain valid for capabilities the image still uses. HAL SHALL NOT invent a parallel preference schema that breaks `settings-restore.service`.

#### Scenario: Reboot restore still works mid-migration
- **WHEN** only backlight is HAL-migrated and the device reboots
- **THEN** persisted Wi‑Fi / ethernet / other non-migrated prefs SHALL still restore via existing shell hooks when those capabilities exist on the image
