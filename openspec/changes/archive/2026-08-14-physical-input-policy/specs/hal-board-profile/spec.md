## MODIFIED Requirements

### Requirement: Board profile for Dart HAL

Each supported product image/App SHALL provide product gpio/modbus config assets consumable by the Dart HAL package. Hardware board profile (capability flags, network role→iface map, helpers) SHALL be supplied at runtime from the OEM pack (filesystem / compose export) for shipping images. Optional fields MAY include a **fixed launch orientation hint** for image/board packaging (consumed by `hmi-launch` / eLinux HMI `-o`, not by a HAL orientation API), audio route hints, and radio bringup notes. Fine-grained pin and register maps SHALL live in App gpio/modbus configs (see `hal-gpio-config` / `hal-modbus-config`), not as opaque constants inside App Dart and not as OEM-owned product catalogs. Capability flags `keyboard` and `mouse` SHALL indicate HAL API availability; they MUST NOT imply physical keyboard or mouse are enabled — that policy lives in `/var/lib/hal/input.conf` (see `physical-input-policy`).

#### Scenario: Product profile present

- **WHEN** the product HMI App uses HAL on a device with a composed OEM profile
- **THEN** the App SHALL load that OEM board profile and merge its App gpio/modbus assets so advertised capabilities match what the product ships
