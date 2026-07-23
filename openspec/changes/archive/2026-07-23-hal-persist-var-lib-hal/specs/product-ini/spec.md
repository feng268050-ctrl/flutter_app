## MODIFIED Requirements

### Requirement: Product.ini file location and format

The system SHALL treat `/var/lib/hal/product.ini` as the product identity and factory-tunable configuration file (path injectable in HAL tests). The file SHALL be a flat `key=value` text format: blank lines ignored; lines whose first non-whitespace character is `#` treated as comments. Missing file SHALL be equivalent to an empty map (all keys absent).

#### Scenario: Missing product.ini yields empty product fields

- **WHEN** `/var/lib/hal/product.ini` does not exist
- **THEN** product built-in properties and extended accessors SHALL return empty strings (except `sn`, which SHALL apply chip-serial fallback)

#### Scenario: Comment and blank lines ignored

- **WHEN** the file contains blank lines and `#` comment lines mixed with `brand=Acme`
- **THEN** `brand` SHALL resolve to `Acme` and comments SHALL NOT produce keys

### Requirement: Host make set-prop upserts product.ini

The host build system SHALL provide `make set-prop` that upserts one or more product properties on the selected board (USB-SSH or registered SSH device, same selection rules as `push-app` / `shell`). Each assignment SHALL be `UPPERCASE_KEY=value` on the Make command line and SHALL be written to `/var/lib/hal/product.ini` as the corresponding lowercase key (e.g. `CAMERA_IP` → `camera_ip`). Unlike lws-ui’s single-key restriction, **multiple** assignments in one invocation SHALL be applied together via one remote file replace. Make/workflow variables that are not product keys (at least `CHIPID`, `IP`, deprecated `SERIAL`, and other documented host vars) MUST be ignored as property keys. `SN=` on `make set-prop` SHALL write the product `sn` key and MUST NOT be treated as device selection for that invocation (multi-board: use `CHIPID=` / `IP=` / deprecated `SERIAL=`). After a successful write, the host tooling SHALL restart the on-device HMI service so the App reloads product identity.

#### Scenario: Single property upsert

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50` against a reachable board
- **THEN** `/var/lib/hal/product.ini` on the device SHALL contain `camera_ip=192.168.1.50`
- **AND** `hmi.service` SHALL be restarted after the write

#### Scenario: Multiple properties in one set-prop

- **WHEN** the operator runs `make set-prop BRAND=Innohi MODEL=YNH960 SN=FACTORY-001`
- **THEN** the remote `product.ini` SHALL contain `brand=Innohi`, `model=YNH960`, and `sn=FACTORY-001` after one successful mutate
- **AND** HMI SHALL be restarted once (not once per key)

#### Scenario: set-prop with no product assignment fails

- **WHEN** the operator runs `make set-prop` with no `UPPERCASE_KEY=value` product assignment
- **THEN** the command SHALL fail with usage guidance and MUST NOT restart HMI

### Requirement: Host make del-prop removes a product.ini key

The host build system SHALL provide `make del-prop` that removes exactly one product key per invocation. The key SHALL be given as an UPPERCASE identifier (as a Make goal or equivalent), mapped to the lowercase file key, and removed from `/var/lib/hal/product.ini` on the selected board. If the key is absent, the command SHALL warn and MUST NOT fail solely for absence. After a successful file update that changes the file contents, tooling SHALL restart HMI. When the key was absent (no file change), tooling MUST NOT fail and SHOULD skip the HMI restart.

#### Scenario: Delete existing key

- **WHEN** `product.ini` contains `camera_ip=192.168.1.50` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the `camera_ip` line SHALL be removed from the remote `/var/lib/hal/product.ini`
- **AND** HMI SHALL be restarted after the update

#### Scenario: Delete missing key is non-fatal

- **WHEN** `camera_ip` is not present in `product.ini` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the command SHALL report that the key was not present and SHALL exit successfully (non-zero only for transport/auth/IO failures)
- **AND** HMI SHOULD NOT be restarted solely because of a missing-key no-op