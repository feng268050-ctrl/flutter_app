## MODIFIED Requirements

### Requirement: oem-compose merges product.ini seed (identity from OEM)

On first boot (and subsequent compose runs), `oem-compose` SHALL ensure `/var/lib/hal/product.ini` exists by applying the OEM board seed: if the runtime file is missing, copy the seed. If it exists, for each key in the seed: `brand`, `model`, and `sn` SHALL be written from the OEM seed whenever those keys are present in the seed (overwriting non-empty runtime values). All other seed keys SHALL be written only when the runtime key is absent or blank. Non-empty runtime values for non-identity keys MUST be preserved.

#### Scenario: Operator camera_ip preserved

- **WHEN** `/var/lib/hal/product.ini` already has `camera_ip=10.0.0.5` and OEM seed has `camera_ip=192.168.1.100`
- **THEN** after compose the runtime file SHALL still contain `camera_ip=10.0.0.5`

#### Scenario: OEM brand/model overwrite runtime

- **WHEN** `/var/lib/hal/product.ini` has `brand=Innohi` and `model=YNH960`, and OEM seed has `brand=LaserCyber` and `model=L1 Pro`
- **THEN** after compose the runtime file SHALL contain `brand=LaserCyber` and `model=L1 Pro`

#### Scenario: Missing runtime file seeded

- **WHEN** `/var/lib/hal/product.ini` is absent and OEM seed exists
- **THEN** compose SHALL create `/var/lib/hal/product.ini` with the seed keys

### Requirement: Host make set-prop upserts product.ini

The host build system SHALL provide `make set-prop` that upserts one or more product properties on the selected board (USB-SSH or registered SSH device, same selection rules as `push-app` / `shell`). Each assignment SHALL be `UPPERCASE_KEY=value` on the Make command line and SHALL be written to `/var/lib/hal/product.ini` as the corresponding lowercase key (e.g. `CAMERA_IP` → `camera_ip`). Unlike lws-ui’s single-key restriction, **multiple** assignments in one invocation SHALL be applied together via one remote file replace. Make/workflow variables that are not product keys (at least `CHIP_ID`, `IP`, deprecated `SERIAL`, `SN` as device selection, and other documented host vars) MUST be ignored as property keys. `make set-prop` MUST refuse to write OEM identity keys `brand`, `model`, and `sn` (including `BRAND=` / `MODEL=` / a sole `SN=` product assignment) and MUST fail with an error that points operators to the OEM board `product.ini` seed. After a successful write, the host tooling SHALL restart the on-device HMI service so the App reloads product identity.

#### Scenario: Single property upsert

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50` against a reachable board
- **THEN** `/var/lib/hal/product.ini` on the device SHALL contain `camera_ip=192.168.1.50`
- **AND** `hmi.service` SHALL be restarted after the write

#### Scenario: Multiple properties in one set-prop

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50 CAMERA_TYPE=2`
- **THEN** the remote `product.ini` SHALL contain `camera_ip=192.168.1.50` and `camera_type=2` after one successful mutate
- **AND** HMI SHALL be restarted once (not once per key)

#### Scenario: set-prop refuses OEM identity keys

- **WHEN** the operator runs `make set-prop BRAND=Innohi` or `make set-prop MODEL=YNH960` or `make set-prop SN=FACTORY-001`
- **THEN** the command SHALL fail without writing `product.ini`
- **AND** HMI MUST NOT be restarted

#### Scenario: set-prop with no product assignment fails

- **WHEN** the operator runs `make set-prop` with no `UPPERCASE_KEY=value` product assignment
- **THEN** the command SHALL fail with usage guidance and MUST NOT restart HMI

### Requirement: Host make del-prop removes a product.ini key

The host build system SHALL provide `make del-prop` that removes exactly one product key per invocation. The key SHALL be given as an UPPERCASE identifier (as a Make goal or equivalent), mapped to the lowercase file key, and removed from `/var/lib/hal/product.ini` on the selected board. `make del-prop` MUST refuse OEM identity keys `brand`, `model`, and `sn`. If a non-identity key is absent, the command SHALL warn and MUST NOT fail solely for absence. After a successful file update that changes the file contents, tooling SHALL restart HMI. When the key was absent (no file change), tooling MUST NOT fail and SHOULD skip the HMI restart.

#### Scenario: Delete existing key

- **WHEN** `product.ini` contains `camera_ip=192.168.1.50` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the `camera_ip` line SHALL be removed from the remote `/var/lib/hal/product.ini`
- **AND** HMI SHALL be restarted after the update

#### Scenario: Delete missing key is non-fatal

- **WHEN** `camera_ip` is not present in `product.ini` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the command SHALL report that the key was not present and SHALL exit successfully (non-zero only for transport/auth/IO failures)
- **AND** HMI SHOULD NOT be restarted solely because of a missing-key no-op

#### Scenario: del-prop refuses OEM identity keys

- **WHEN** the operator runs `make del-prop BRAND` or `make del-prop MODEL` or `make del-prop SN`
- **THEN** the command SHALL fail without modifying `product.ini`
- **AND** HMI MUST NOT be restarted
