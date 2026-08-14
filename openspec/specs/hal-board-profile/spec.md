# hal-board-profile Specification

## Purpose
Board profiles declare capability flags, net role→iface maps, helpers, and pointers to product gpio/modbus config assets for `package:cyber_hal`.
## Requirements
### Requirement: Board profile for Dart HAL

Each supported product image/App SHALL provide product gpio/modbus config assets consumable by the Dart HAL package. Hardware board profile (capability flags, network role→iface map, helpers) SHALL be supplied at runtime from the OEM pack (filesystem / compose export) for shipping images. Optional fields MAY include a **fixed launch orientation hint** for image/board packaging (consumed by `hmi-launch` / eLinux HMI `-o`, not by a HAL orientation API), audio route hints, and radio bringup notes. Fine-grained pin and register maps SHALL live in App gpio/modbus configs (see `hal-gpio-config` / `hal-modbus-config`), not as opaque constants inside App Dart and not as OEM-owned product catalogs. Capability flags `keyboard` and `mouse` SHALL indicate HAL API availability; they MUST NOT imply physical keyboard or mouse are enabled — that policy lives in `/var/lib/hal/input.conf` (see `physical-input-policy`).

#### Scenario: Product profile present

- **WHEN** the product HMI App uses HAL on a device with a composed OEM profile
- **THEN** the App SHALL load that OEM board profile and merge its App gpio/modbus assets so advertised capabilities match what the product ships

### Requirement: Product gpio/modbus configs are App-owned

Product `gpio.json` and `modbus.json` catalogs SHALL live in the **product App** (or product pack), not under `oem/boards/<board_id>/` and not under `packages/cyber_hal/boards/<board_id>/` as the product authority. The same motherboard MAY ship different pin/register maps across products. After merge, `BoardProfile` gpio/modbus paths SHALL point at Flutter asset URIs (typically `assets/hal/gpio.json` / `assets/hal/modbus.json`). Absolute `assets/…` and `packages/…` paths SHALL resolve as-is; relative paths MAY resolve under `packages/cyber_hal/` for package example profiles only (`sim`, `portable-smoke`).

#### Scenario: LWS HMI pack

- **WHEN** loading the lws-hmi profile with product configs merged
- **THEN** `resolvedGpioAsset` / `resolvedModbusAsset` SHALL be App assets under `assets/hal/` and MUST NOT require OEM or `packages/cyber_hal/boards/ynh960/…` for those catalogs

### Requirement: Compile-time or pack selection
Board profile selection SHALL be determined by product/image configuration (build-time pack or explicit config), not by requiring runtime detection of arbitrary motherboards.

#### Scenario: Wrong profile not silent
- **WHEN** an App is built for board A
- **THEN** it SHALL not silently load board B’s role map as the active profile

### Requirement: Headless and partial SKUs
Profiles for products without display, audio, or network SHALL omit those capabilities. Screen-specific data MAY live in a screen section or adjacent screen pack file only when a display exists.

#### Scenario: No Wi‑Fi SKU
- **WHEN** profile omits Wi‑Fi
- **THEN** HAL capability discovery SHALL report Wi‑Fi absent and SHALL NOT require wpa_supplicant for HAL initialization of other modules

### Requirement: Load board profile from filesystem

`package:cyber_hal` SHALL provide `BoardProfile.loadFile` (or equivalent) that reads a UTF-8 JSON board profile from an absolute filesystem path and returns a `BoardProfile`. `loadAsset` SHALL remain available for tests and hosts without an OEM mount.

#### Scenario: loadFile reads OEM profile

- **WHEN** a valid OEM `board_profile.json` exists at a known path
- **THEN** `BoardProfile.loadFile` SHALL return a profile whose `board_id` matches the file

### Requirement: Merge product gpio/modbus configs onto OEM profile

`BoardProfile` SHALL provide an API (e.g. `withProductConfigs`) that returns a profile copy with gpio/modbus config asset paths set to App-owned Flutter asset URIs. OEM profiles without product catalogs SHALL become usable for gpio/modbus only after this merge (or explicit constructor injection).

#### Scenario: App merges catalogs

- **WHEN** an OEM profile has no gpio/modbus config paths and the App calls `withProductConfigs` with `assets/hal/gpio.json` and `assets/hal/modbus.json`
- **THEN** `resolvedGpioAsset` / `resolvedModbusAsset` SHALL resolve to those App assets

### Requirement: Runtime profile prefers OEM compose export

On Linux HMI startup, the product App SHALL load board profile from `/run/hmi/board_profile.json` when present, else from `/oem/boards/<board_id>/board_profile.json` when compose/OEM provides it, then merge App gpio/modbus assets. Only when OEM/compose profile is unavailable MAY the App fall back to the bundled `assets/hal/board_profile.json` during the documented migration window (with a log warning).

#### Scenario: Compose export wins over App asset

- **WHEN** `/run/hmi/board_profile.json` exists and App assets also contain `board_profile.json`
- **THEN** the running App SHALL use the compose-exported profile (plus App gpio/modbus merge), not the App-bundled board profile as the hardware authority

### Requirement: sim board_id does not imply Stub backends

`resolveHalBackend` SHALL select Stub backends only when `HAL_BACKEND` is explicitly `stub`. The board id `sim` alone MUST resolve to Linux backends so QEMU/guest profiles can use Linux HAL modules.

#### Scenario: sim board uses Linux by default

- **WHEN** `resolveHalBackend(boardId: 'sim')` is called with `HAL_BACKEND` unset or empty
- **THEN** the result SHALL be Linux (not Stub)

#### Scenario: Explicit stub env

- **WHEN** `HAL_BACKEND=stub` is set
- **THEN** `resolveHalBackend` SHALL return Stub regardless of board id

### Requirement: Package sim profile matches guest contract

`packages/cyber_hal/boards/sim.json` SHALL be upgraded to declare guest-oriented capabilities and `net_roles` for product ethernet and wifi (aligned with OEM sim board profile). It MUST omit `usbOtg`. It remains a package example/fixture; product gpio/modbus authority stays in the App.

#### Scenario: sim.json has product net roles

- **WHEN** loading `packages/cyber_hal/boards/sim.json`
- **THEN** `net_roles` SHALL include `ethernet.primary` and `wifi.station` and capabilities SHALL omit `usbOtg`

