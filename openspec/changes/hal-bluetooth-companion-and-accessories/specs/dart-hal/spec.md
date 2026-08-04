## ADDED Requirements

### Requirement: Bluetooth module exposes companion and accessory-host entrypoints

The `cyber_hal` Bluetooth module SHALL export abstract APIs for the **companion** plane and the **accessory host** plane in addition to the existing adapter/controller surface. Product Apps MUST be able to import companion or accessory-host APIs without depending on Linux concrete classes. Stub backends SHALL exist for host unit tests.

#### Scenario: Abstract companion import

- **WHEN** an App imports the portable Bluetooth companion API
- **THEN** it can reference start/stop session and provision/RPC operations without importing `Linux*` types

#### Scenario: Abstract accessory host import

- **WHEN** an App imports the portable accessory-host API
- **THEN** it can register the HID profile and observe accessories without importing `Linux*` types

### Requirement: Board profile advertises Bluetooth sub-features

`BoardProfile` (or an equivalent binding-side feature object derived from profile JSON) SHALL advertise Bluetooth sub-features for at least `companion`, `accessory_host`, and `a2dp_sink` when `Capability.bluetooth` is present. `BoardBindings` SHALL construct companion and accessory-host backends only when the corresponding sub-feature is advertised; otherwise callers receive structured unsupported behavior. Coarse `Capability.bluetooth` alone MUST NOT imply companion is available.

#### Scenario: Bluetooth without companion

- **WHEN** a profile lists `bluetooth` but omits companion sub-feature
- **THEN** accessory-host and/or adapter APIs MAY still construct while companion start returns unsupported

#### Scenario: ynh960 spike-enabled companion

- **WHEN** ynh960 companion spike is accepted and the OEM profile enables companion
- **THEN** `BoardBindings` can construct a Linux companion backend for that profile

## MODIFIED Requirements

### Requirement: Cross-module portability (D22)

Linux backends outside `hal/network` ethernet/wifi apply SHALL meet the same reuse bar as D11b: board-specific Process paths and vendor sysfs nodes MUST be injectable (via `BoardProfile` and/or constructors). `BoardProfile` MUST be usable as live wiring for backends, not only in unit tests.

- **`hal/bluetooth`:** device/adapter APIs SHALL use BlueZ D-Bus as the portable core. Stack bring-up, A2DP sink orchestration, pairing agent ensure, and HID heal SHALL go through an injected board port (`BtStack` or equivalent). **Companion GATT registration and LE advertising** SHALL use portable BlueZ D-Bus APIs and/or an injectable companion port (helper allowed only if in-process GATT is proven insufficient). **Accessory-host** central control SHALL use the same BlueZ core with profile plugins. HAL MUST NOT leave heal, A2DP, or companion helper paths as non-overridable private constants.
- **Kind C helpers** (`hal/datetime` sync, **`hal/network` SSH debug**, backlight/volume/mouse apply, volume A2DP): every default argv/path MUST be overridable. HAL default names SHOULD avoid iface prefixes (e.g. prefer `sync-time` over `wlan0-time-sync.sh`).
- **`hal/usb_otg`:** OTG mode apply SHALL use injectable helpers and/or sysfs role paths; boards without materials fail closed. Attach/detach watching MUST NOT be required.
- **`hal/gpio` / `hal/modbus` / `hal/sys_info`:** remain config/`/proc`-driven; Demo/App SHALL resolve gpio/modbus assets and storage mounts from the board profile when present. Product catalogs are App assets (e.g. `assets/hal/gpio.json`), not board-named files inside `cyber_hal`.

#### Scenario: Other product without bt-* tree

- **WHEN** a product provides BlueZ and a `BtStack` implementation (or no-op where radio is absent)
- **THEN** it SHALL be able to use `hal/bluetooth` device APIs without shipping this repository’s full `/usr/libexec/bluetooth/bt-*` set as non-overridable HAL defaults

#### Scenario: HID heal path injectable

- **WHEN** constructing the Linux bluetooth backend
- **THEN** HID heal helper and status directory paths SHALL be injectable and MUST NOT exist only as private `static const` values

#### Scenario: Companion port is injectable

- **WHEN** a board cannot host in-process BlueZ GATT server objects
- **THEN** bindings MAY inject a companion helper port while Apps still depend only on the abstract companion API

#### Scenario: Time sync helper without iface name

- **WHEN** using default datetime network sync after D22
- **THEN** the HAL default helper path SHALL NOT be iface-prefixed (`wlan0-…`); ynh960 MAY still ship a symlink or board override to an existing script

#### Scenario: Profile wires gpio asset

- **WHEN** Demo constructs gpio HAL with a loaded `BoardProfile`
- **THEN** it SHALL use the profile’s gpio config asset pointer (App-owned `assets/…` URI) and MUST NOT fall back to a hard-coded `packages/cyber_hal/boards/<board>/gpio.json` constant
