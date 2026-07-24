## MODIFIED Requirements

### Requirement: Industry-style public API

Portable HAL public types SHALL use system-service vocabulary including at least: `Capabilities` / `BoardInfo`; under `hal/network`: network device/role APIs plus `ProxySettings` and **`SshDebug`** (LAN SSH); under `hal/output`: **display** (`Backlight`, `AutoSleep`, **`Orientation`**) and **sound** (`Volume`, `ButtonFeedback`); under `hal/input`: keyboard and mouse; `hal/gpio`; `hal/modbus`; under **`hal/usb_otg`**: OTG mode (`debug`/`mtp`/`host`) without attach/detach product APIs; `BluetoothManager` / related; `TimeService`; `SysInfo`. Implementation types (`Linux*`, `*Backend`) MUST NOT be required by product App code. Temporary `*Controller` wrappers MAY exist during migration. The HAL package MUST NOT expose a top-level `hal/http` module. Long-term public layout SHALL use grouped packages where decided (`hal/output`, `hal/input`, `hal/network`) plus top-level `hal/usb_otg`, `hal/gpio` / `hal/modbus` (not under an `io`/`media` umbrella). A long-term **`hal/debug`** barrel for SSH+USB MUST NOT remain. URL probe UI stays in the App. System proxy policy SHALL live under `hal/network/proxy`. Panel orientation SHALL live under `hal/output/display` (not a top-level `hal/orientation` entrypoint). Embedder/stack detection (`DisplayStack`) SHALL live under `hal/sys_info`. The package MUST NOT expose a top-level `hal/display` / `package:cyber_hal/display.dart` entrypoint.

#### Scenario: New integration uses network module

- **WHEN** a new Settings page integrates Wi‑Fi through HAL
- **THEN** documented imports SHALL be under `package:cyber_hal/network` (e.g. wifi subpackage), not a new portable type whose primary name is `WifiController`

#### Scenario: Orientation under output display

- **WHEN** a product App sets panel orientation
- **THEN** it SHALL import `package:cyber_hal/output/display/orientation.dart` (or `output/display.dart`) and MUST NOT use a top-level `hal/orientation` module

#### Scenario: LAN SSH under network

- **WHEN** a product App toggles LAN SSH debug
- **THEN** it SHALL import `SshDebug` from `package:cyber_hal/network` (or `network/ssh_debug.dart`) and MUST NOT require `hal/debug`

### Requirement: Network module grouping

Ethernet, Wi‑Fi, system proxy, and **LAN SSH debug (`SshDebug`)** SHALL be grouped under `hal/network` with optional subpackage imports (`ethernet`, `wifi`, `proxy`, `ssh_debug`). Apps MUST NOT be required to import bluetooth or unrelated modules to use network APIs.

#### Scenario: Import wifi only

- **WHEN** a product App needs only Wi‑Fi APIs
- **THEN** it SHALL be able to import `package:cyber_hal/network/wifi.dart` without importing proxy or bluetooth

#### Scenario: Import ssh debug with proxy peer

- **WHEN** a product App needs LAN SSH debug
- **THEN** it SHALL be able to import `package:cyber_hal/network/ssh_debug.dart` (or network barrel) without importing `hal/usb_otg`

### Requirement: Domain package grouping

Related capabilities SHALL be grouped under domain packages with optional sub-imports where naming fits: `hal/network` {ethernet, wifi, proxy, **ssh_debug**}; `hal/output` {**display** {backlight, auto-sleep, **orientation**}, **sound** {volume, button-feedback}}; `hal/input` {keyboard, mouse}; **`hal/usb_otg`**. `hal/gpio` and `hal/modbus` SHALL remain separate top-level modules. Apps MUST be able to import a single subpackage without pulling unused siblings. **`hal/debug` MUST NOT** be the long-term home for SSH or USB OTG.

#### Scenario: Volume without backlight

- **WHEN** a product App needs only volume
- **THEN** it SHALL be able to import `hal/output/sound/volume` (or `hal/output/sound`) without importing backlight / auto-sleep / orientation

#### Scenario: Orientation without volume

- **WHEN** a product App needs only panel orientation
- **THEN** it SHALL be able to import `hal/output/display/orientation` (or `hal/output/display`) without importing volume / button-feedback

#### Scenario: Gpio without modbus

- **WHEN** a product App needs only gpio lines
- **THEN** it SHALL import `hal/gpio` and MUST NOT be required to depend on `hal/modbus`

#### Scenario: UsbOtg without wifi

- **WHEN** a product App needs only OTG mode control
- **THEN** it SHALL import `hal/usb_otg` without importing wifi

### Requirement: Cross-module portability (D22)

Linux backends outside `hal/network` ethernet/wifi apply SHALL meet the same reuse bar as D11b: board-specific Process paths and vendor sysfs nodes MUST be injectable (via `BoardProfile` and/or constructors). `BoardProfile` MUST be usable as live wiring for backends, not only in unit tests.

- **`hal/bluetooth`:** device/adapter APIs SHALL use BlueZ D-Bus as the portable core. Stack bring-up, A2DP sink orchestration, pairing agent ensure, and HID heal SHALL go through an injected board port (`BtStack` or equivalent). HAL MUST NOT leave heal or A2DP helper paths as non-overridable private constants.
- **Kind C helpers** (`hal/datetime` sync, **`hal/network` SSH debug**, backlight/volume/mouse apply, volume A2DP): every default argv/path MUST be overridable. HAL default names SHOULD avoid iface prefixes (e.g. prefer `sync-time` over `wlan0-time-sync.sh`).
- **`hal/usb_otg`:** OTG mode apply SHALL use injectable helpers and/or sysfs role paths; boards without materials fail closed. Attach/detach watching MUST NOT be required.
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

## REMOVED Requirements

### Requirement: Debug module grouping

**Reason:** LAN SSH moves under `hal/network`; USB OTG becomes `hal/usb_otg`; `hal/debug` is retired.
**Migration:** Import `SshDebug` from `network`; import `UsbOtg` from `usb_otg`; delete `UsbDebug` / `hal/debug` usages.
