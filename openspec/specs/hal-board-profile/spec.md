# hal-board-profile Specification

## Purpose
TBD - created by archiving change dart-hal-package. Update Purpose after archive.
## Requirements
### Requirement: Board profile for Dart HAL
Each supported motherboard SHALL provide a board profile consumable by the Dart HAL package (asset and/or on-image file), including at least: board id, capability flags, and network role→iface map for advertised network roles. Optional fields MAY include a **fixed launch orientation hint** for image/board packaging (consumed by `hmi-launch` / flutter-pi `-o`, not by a HAL orientation API), audio route hints, radio bringup notes, and **paths to gpio/modbus config files** (or embedded references). Fine-grained pin and register maps SHALL live in those gpio/modbus configs (see `hal-gpio-config` / `hal-modbus-config`), not as opaque constants inside App Dart.

#### Scenario: ynh960 profile present
- **WHEN** the ynh960 image/App uses HAL
- **THEN** the HAL SHALL load a ynh960 profile that advertises the capabilities that product actually ships

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

