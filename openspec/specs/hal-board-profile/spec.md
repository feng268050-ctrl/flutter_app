# hal-board-profile Specification

## Purpose
Board profiles declare capability flags, net role→iface maps, helpers, and pointers to product gpio/modbus config assets for `package:cyber_hal`.

## Requirements
### Requirement: Board profile for Dart HAL
Each supported product image/App SHALL provide a board profile consumable by the Dart HAL package (Flutter asset and/or on-image file), including at least: board id, capability flags, and network role→iface map for advertised network roles. Optional fields MAY include a **fixed launch orientation hint** for image/board packaging (consumed by `hmi-launch` / eLinux HMI `-o`, not by a HAL orientation API), audio route hints, radio bringup notes, and **paths to gpio/modbus config files** (or embedded references). Fine-grained pin and register maps SHALL live in those gpio/modbus configs (see `hal-gpio-config` / `hal-modbus-config`), not as opaque constants inside App Dart.

#### Scenario: Product profile present
- **WHEN** the product HMI App uses HAL
- **THEN** the App SHALL load its board profile asset (e.g. `assets/hal/board_profile.json`) that advertises the capabilities that product actually ships

### Requirement: Product gpio/modbus configs are App-owned
Product `gpio.json` and `modbus.json` catalogs SHALL live in the **product App** (or product pack), not under `packages/cyber_hal/boards/<board_id>/`. The same motherboard MAY ship different pin/register maps across products. `BoardProfile.configs.gpio` / `configs.modbus` SHALL point at Flutter asset URIs (typically `assets/hal/gpio.json` / `assets/hal/modbus.json`). Absolute `assets/…` and `packages/…` paths SHALL resolve as-is; relative paths MAY resolve under `packages/cyber_hal/` for package example profiles only (`sim`, `portable-smoke`).

#### Scenario: LWS HMI pack
- **WHEN** loading the lws-hmi board profile
- **THEN** `resolvedGpioAsset` / `resolvedModbusAsset` SHALL be App assets under `assets/hal/` and MUST NOT require `packages/cyber_hal/boards/ynh960/…`

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
