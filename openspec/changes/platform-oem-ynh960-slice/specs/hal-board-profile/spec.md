## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Board profile for Dart HAL

Each supported product image/App SHALL provide product gpio/modbus config assets consumable by the Dart HAL package. Hardware board profile (capability flags, network role→iface map, helpers) SHALL be supplied at runtime from the OEM pack (filesystem / compose export) for shipping images. Optional fields MAY include a **fixed launch orientation hint** for image/board packaging (consumed by `hmi-launch` / eLinux HMI `-o`, not by a HAL orientation API), audio route hints, and radio bringup notes. Fine-grained pin and register maps SHALL live in App gpio/modbus configs (see `hal-gpio-config` / `hal-modbus-config`), not as opaque constants inside App Dart and not as OEM-owned product catalogs.

#### Scenario: Product profile present

- **WHEN** the product HMI App uses HAL on a device with a composed OEM profile
- **THEN** the App SHALL load that OEM board profile and merge its App gpio/modbus assets so advertised capabilities match what the product ships

#### Scenario: Host/test asset profile

- **WHEN** OEM/compose profile files are absent (host test or migration fallback)
- **THEN** the App MAY load a Flutter asset board profile (e.g. `assets/hal/board_profile.json`) for development only

### Requirement: Product gpio/modbus configs are App-owned

Product `gpio.json` and `modbus.json` catalogs SHALL live in the **product App** (or product pack), not under `oem/boards/<board_id>/` and not under `packages/cyber_hal/boards/<board_id>/` as the product authority. The same motherboard MAY ship different pin/register maps across products. After merge, `BoardProfile` gpio/modbus paths SHALL point at Flutter asset URIs (typically `assets/hal/gpio.json` / `assets/hal/modbus.json`). Absolute `assets/…` and `packages/…` paths SHALL resolve as-is; relative paths MAY resolve under `packages/cyber_hal/` for package example profiles only (`sim`, `portable-smoke`).

#### Scenario: LWS HMI pack

- **WHEN** loading the lws-hmi profile with product configs merged
- **THEN** `resolvedGpioAsset` / `resolvedModbusAsset` SHALL be App assets under `assets/hal/` and MUST NOT require OEM or `packages/cyber_hal/boards/ynh960/…` for those catalogs
