## MODIFIED Requirements

### Requirement: Properties.ini file location and format

The system SHALL treat `/var/lib/hal/properties.ini` as the **factory/operator tunable** configuration file (path injectable in HAL tests), bound to the **`provision`** partition at `/mnt/provision/properties.ini` per `gpt-provision-partition` — **not** under userdata. The file SHALL be flat `key=value` text: blank lines ignored; `#` comments ignored. Missing file SHALL mean empty tunables. Per-unit identity (`brand`, `model`, `sn`) on Rockchip boards SHALL come from Vendor Storage; on other boards from `provision/identity.env`. OEM packs and `oem-compose` MUST NOT seed or merge this file.

#### Scenario: Missing properties.ini yields empty tunable fields

- **WHEN** provision has no `properties.ini`
- **THEN** `ProductInfo.get('camera_ip')` SHALL return the empty string
- **AND** identity SHALL still resolve via Vendor Storage or provision identity per board family

#### Scenario: properties.ini not on userdata

- **WHEN** factory-reset or flash userdata wipe completes
- **THEN** `/userdata/hal/properties.ini` SHALL NOT be the authoritative tunables store
- **AND** tunables SHALL still be readable from provision when provision file exists

### Requirement: Host make set-prop upserts properties.ini

The host build system SHALL provide `make set-prop` that upserts one or more properties on the selected board (USB-SSH or registered SSH device, same selection rules as `push-app` / `shell`). Each assignment SHALL be `UPPERCASE_KEY=value` on the Make command line and SHALL be written to the **provision-backed** `/var/lib/hal/properties.ini` (→ `/mnt/provision/properties.ini`) as the corresponding lowercase key. **Multiple** assignments in one invocation SHALL be applied together via one remote file replace. Make/workflow variables that are not property keys MUST be ignored as property keys. `make set-prop` MUST refuse identity keys `brand`, `model`, and `sn` and MUST fail with an error pointing to **`make write-identity`**. After a successful write, the host tooling SHALL restart the on-device HMI service so the App reloads tunables.

#### Scenario: Single property upsert on provision

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50` against a reachable board
- **THEN** `/mnt/provision/properties.ini` SHALL contain `camera_ip=192.168.1.50`
- **AND** `hmi.service` SHALL be restarted after the write

#### Scenario: set-prop refuses identity keys

- **WHEN** the operator runs `make set-prop BRAND=Innohi` or `make set-prop MODEL=YNH960` or `make set-prop SN=FACTORY-001`
- **THEN** the command SHALL fail without writing `properties.ini`
- **AND** HMI MUST NOT be restarted
- **AND** the error SHALL point to `make write-identity`

### Requirement: Host make del-prop removes a properties.ini key

The host build system SHALL provide `make del-prop` that removes exactly one property key per invocation from the **provision-backed** `/var/lib/hal/properties.ini`. `make del-prop` MUST refuse identity keys `brand`, `model`, and `sn`. After a successful file update that changes contents, tooling SHALL restart HMI.

#### Scenario: Delete existing key on provision

- **WHEN** `properties.ini` on provision contains `camera_ip=192.168.1.50` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the `camera_ip` line SHALL be removed from `/mnt/provision/properties.ini`
- **AND** HMI SHALL be restarted after the update

### Requirement: Migrate legacy product.ini basename

On provision mount and before host `set-prop` / `del-prop` mutate, if the provision-backed `properties.ini` is absent and a legacy `product.ini` or userdata copy exists, the system SHALL migrate tunables into `/mnt/provision/properties.ini` (copy from `/userdata/hal/product.ini` or `/userdata/hal/properties.ini` once). If both legacy userdata copies exist, `properties.ini` SHALL win. After migration, userdata copies SHALL NOT remain authoritative.

#### Scenario: Migrate from userdata hal tree

- **WHEN** `/userdata/hal/properties.ini` contains `camera_ip=10.0.0.5` and provision has no file
- **THEN** after first boot migration `/mnt/provision/properties.ini` SHALL contain `camera_ip=10.0.0.5`
- **AND** `/var/lib/hal/properties.ini` SHALL read from provision
