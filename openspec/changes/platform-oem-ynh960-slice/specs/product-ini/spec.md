## ADDED Requirements

### Requirement: OEM board pack seeds product.ini

For v1, each OEM board directory MAY include a `product.ini` factory seed (keys such as `brand`, `model`, `camera_ip`, and other product tunables). Runtime HAL and host tooling continue to use `/var/lib/hal/product.ini` as the authoritative live file. `make set-prop` / `del-prop` SHALL keep writing the runtime path and MUST NOT require writing back into the OEM partition.

#### Scenario: Seed file in OEM tree

- **WHEN** inspecting `oem/boards/ynh960/product.ini`
- **THEN** the file SHALL be valid `key=value` product.ini syntax and MAY include a non-empty `camera_ip` default

### Requirement: oem-compose merges product.ini seed without clobber

On first boot (and subsequent compose runs), `oem-compose` SHALL ensure `/var/lib/hal/product.ini` exists by applying the OEM board seed: if the runtime file is missing, copy the seed; if it exists, for each key in the seed, write the seed value only when the runtime key is absent or blank. Non-empty runtime values MUST be preserved.

#### Scenario: Operator camera_ip preserved

- **WHEN** `/var/lib/hal/product.ini` already has `camera_ip=10.0.0.5` and OEM seed has `camera_ip=192.168.1.100`
- **THEN** after compose the runtime file SHALL still contain `camera_ip=10.0.0.5`

#### Scenario: Missing runtime file seeded

- **WHEN** `/var/lib/hal/product.ini` is absent and OEM seed exists
- **THEN** compose SHALL create `/var/lib/hal/product.ini` with the seed keys
