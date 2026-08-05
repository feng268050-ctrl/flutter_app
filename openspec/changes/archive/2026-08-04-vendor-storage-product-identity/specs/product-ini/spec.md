## MODIFIED Requirements

### Requirement: Product.ini file location and format

The system SHALL treat `/var/lib/hal/product.ini` as the **factory-tunable** configuration file (path injectable in HAL tests), not as the authority for per-unit `brand` / `model` / `sn`. The file SHALL be a flat `key=value` text format: blank lines ignored; lines whose first non-whitespace character is `#` treated as comments. Missing file SHALL be equivalent to an empty map (all keys absent). Per-unit identity (`brand`, `model`, `sn`) SHALL be read from Rockchip Vendor Storage per `vendor-storage-identity`, not from this file.

#### Scenario: Missing product.ini yields empty tunable fields

- **WHEN** `/var/lib/hal/product.ini` does not exist
- **THEN** tunable accessors (e.g. `camera_ip`) SHALL return empty strings
- **AND** `brand` / `model` / `sn` SHALL still resolve via Vendor Storage (with chip-serial fallback for empty SN)

#### Scenario: Comment and blank lines ignored

- **WHEN** the file contains blank lines and `#` comment lines mixed with `camera_ip=10.0.0.1`
- **THEN** `camera_ip` SHALL resolve to `10.0.0.1` and comments SHALL NOT produce keys

### Requirement: Built-in product identity properties

The HAL SHALL expose a `ProductInfo` (or equivalent) type with built-in string properties `brand`, `model`, `sn`, and `chipId`. `brand`, `model`, and `sn` SHALL come from Rockchip Vendor Storage (see `vendor-storage-identity` ID map). Absent or blank Vendor Storage brand/model SHALL yield the empty string. `chipId` SHALL be the chip/board serial from DT → `/proc/cpuinfo` Serial → documented fallbacks (never a `product.ini` `sn` key). For `sn`: if Vendor Storage contains a non-empty SN, that value SHALL be used; otherwise `sn` SHALL equal `chipId`. Stale `brand` / `model` / `sn` keys in `product.ini` MUST be ignored. Apps MUST obtain these values from HAL, not by reading Vendor Storage or `product.ini` directly. `SysInfoSnapshot` SHALL expose `serialNumber` (product SN) and `chipId`.

#### Scenario: Brand and model from Vendor Storage

- **WHEN** Vendor Storage holds brand `Innohi` and model `YNH960`
- **THEN** `ProductInfo.brand` SHALL be `Innohi` and `ProductInfo.model` SHALL be `YNH960`

#### Scenario: Factory sn preferred over chip serial

- **WHEN** Vendor Storage contains a non-empty SN `FACTORY-001` and a chip serial is also available
- **THEN** `ProductInfo.sn` SHALL be `FACTORY-001`
- **AND** `ProductInfo.chipId` SHALL be the chip serial (not `FACTORY-001`)

#### Scenario: Chip serial when Vendor Storage sn absent

- **WHEN** Vendor Storage has no SN (or blank) and chip/board serial resolves to `ABC123`
- **THEN** `ProductInfo.sn` and `ProductInfo.chipId` SHALL both be `ABC123`

#### Scenario: product.ini sn ignored

- **WHEN** `product.ini` contains `sn=FROM-INI` and Vendor Storage SN is empty and chip serial is `ABC123`
- **THEN** `ProductInfo.sn` SHALL be `ABC123` (not `FROM-INI`)

### Requirement: Host SN matches ProductInfo sn

Board serial helpers used for USB gadget iSerial and host device listing (`make devices` / SSH registry enrichment) SHALL resolve **SN** with the same rule as `ProductInfo.sn`: non-empty Vendor Storage SN first, then chip/board serial fallbacks. The `make devices` table SHALL include columns **SN** and **ChipID** (ChipID = chip serial / adb SerialNo / RockUSB SerialNo). Host tooling MUST prefer a live board identity probe over host USB gadget iSerial when both are available. Host device selection SHALL use env **`SN=`** (matching SN or ChipID). **`CHIP_ID=`** SHALL match ChipID only. Deprecated **`SERIAL=`** SHALL be accepted as aliases for **`SN=`**. Makefile `help`, README, and AGENTS.md SHALL document `SN=` (not `SERIAL=`) as the primary selector, and SHALL document `make write-identity` for provisioning brand/model/product SN.

#### Scenario: make devices shows factory sn and chip id

- **WHEN** the device has Vendor Storage SN `FACTORY-001`, chip serial is `ABC123`, and the board is reachable via USB-SSH or LAN SSH enrichment
- **THEN** the listed **SN** column SHALL be `FACTORY-001`
- **AND** the listed **ChipID** column SHALL be `ABC123`

#### Scenario: make devices falls back to chip serial for SN

- **WHEN** Vendor Storage SN is missing or blank and chip serial is `ABC123`
- **THEN** the listed **SN** and **ChipID** columns SHALL both be `ABC123`

#### Scenario: Android or RockUSB row uses chip identity for both columns

- **WHEN** listing an Android adb device or RockUSB loader device with SerialNo `RK123`
- **THEN** **ChipID** SHALL show the adb serial / upgrade_tool SerialNo (chip identity)

### Requirement: Host make set-prop upserts product.ini

The host build system SHALL provide `make set-prop` that upserts one or more product properties on the selected board (USB-SSH or registered SSH device, same selection rules as `push-app` / `shell`). Each assignment SHALL be `UPPERCASE_KEY=value` on the Make command line and SHALL be written to `/var/lib/hal/product.ini` as the corresponding lowercase key (e.g. `CAMERA_IP` → `camera_ip`). Unlike lws-ui’s single-key restriction, **multiple** assignments in one invocation SHALL be applied together via one remote file replace. Make/workflow variables that are not product keys (at least `CHIP_ID`, `IP`, deprecated `SERIAL`, `SN` as device selection, and other documented host vars) MUST be ignored as property keys. `make set-prop` MUST refuse to write identity keys `brand`, `model`, and `sn` (including `BRAND=` / `MODEL=` / a sole `SN=` product assignment) and MUST fail with an error that points operators to **`make write-identity`** (Vendor Storage), not the OEM `product.ini` seed. After a successful write, the host tooling SHALL restart the on-device HMI service so the App reloads tunables.

#### Scenario: Single property upsert

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50` against a reachable board
- **THEN** `/var/lib/hal/product.ini` on the device SHALL contain `camera_ip=192.168.1.50`
- **AND** `hmi.service` SHALL be restarted after the write

#### Scenario: Multiple properties in one set-prop

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50 CAMERA_TYPE=2`
- **THEN** the remote `product.ini` SHALL contain `camera_ip=192.168.1.50` and `camera_type=2` after one successful mutate
- **AND** HMI SHALL be restarted once (not once per key)

#### Scenario: set-prop refuses identity keys

- **WHEN** the operator runs `make set-prop BRAND=Innohi` or `make set-prop MODEL=YNH960` or `make set-prop SN=FACTORY-001`
- **THEN** the command SHALL fail without writing `product.ini`
- **AND** HMI MUST NOT be restarted
- **AND** the error SHALL point to `make write-identity`

#### Scenario: set-prop with no product assignment fails

- **WHEN** the operator runs `make set-prop` with no `UPPERCASE_KEY=value` product assignment
- **THEN** the command SHALL fail with usage guidance and MUST NOT restart HMI

### Requirement: Host make del-prop removes a product.ini key

The host build system SHALL provide `make del-prop` that removes exactly one product key per invocation. The key SHALL be given as an UPPERCASE identifier (as a Make goal or equivalent), mapped to the lowercase file key, and removed from `/var/lib/hal/product.ini` on the selected board. `make del-prop` MUST refuse identity keys `brand`, `model`, and `sn`, with an error that points to Vendor Storage / `write-identity` (not OEM seed editing). If a non-identity key is absent, the command SHALL warn and MUST NOT fail solely for absence. After a successful file update that changes the file contents, tooling SHALL restart HMI. When the key was absent (no file change), tooling MUST NOT fail and SHOULD skip the HMI restart.

#### Scenario: Delete existing key

- **WHEN** `product.ini` contains `camera_ip=192.168.1.50` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the `camera_ip` line SHALL be removed from the remote `/var/lib/hal/product.ini`
- **AND** HMI SHALL be restarted after the update

#### Scenario: Delete missing key is non-fatal

- **WHEN** `camera_ip` is not present in `product.ini` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the command SHALL report that the key was not present and SHALL exit successfully (non-zero only for transport/auth/IO failures)
- **AND** HMI SHOULD NOT be restarted solely because of a missing-key no-op

#### Scenario: del-prop refuses identity keys

- **WHEN** the operator runs `make del-prop BRAND` or `make del-prop MODEL` or `make del-prop SN`
- **THEN** the command SHALL fail without modifying `product.ini`
- **AND** HMI MUST NOT be restarted

### Requirement: OEM board pack seeds product.ini

Each OEM board directory MAY include a `product.ini` factory seed for **tunables** (keys such as `camera_ip` and other non-identity product settings). Runtime HAL and host tooling continue to use `/var/lib/hal/product.ini` as the authoritative live file for those tunables. `make set-prop` / `del-prop` SHALL keep writing the runtime path for non-identity tunables and MUST NOT require writing back into the OEM partition. Per-unit identity keys `brand` / `model` / `sn` SHALL NOT be provisioned via the OEM seed; they SHALL be changed only via Vendor Storage (`make write-identity` or documented RockUSB SN-only for SN). OEM seed files SHOULD omit `brand` / `model` / `sn`; if present, compose MUST NOT treat them as identity authority.

#### Scenario: Seed file in OEM tree

- **WHEN** inspecting `oem/boards/ynh960/product.ini`
- **THEN** the file SHALL be valid `key=value` product.ini syntax and MAY include a non-empty `camera_ip` default
- **AND** it SHOULD NOT be relied on for per-unit `sn`

### Requirement: oem-compose merges product.ini seed (identity from OEM)

On first boot (and subsequent compose runs), `oem-compose` SHALL ensure `/var/lib/hal/product.ini` exists by applying the OEM board seed: if the runtime file is missing, copy the seed **excluding** identity authority behavior for `brand` / `model` / `sn`. If the runtime file exists, for each key in the seed: keys other than `brand`, `model`, and `sn` SHALL be written only when the runtime key is absent or blank (non-empty runtime tunables MUST be preserved). Compose MUST NOT force-overwrite runtime or Vendor Storage identity from OEM `brand` / `model` / `sn`. If the seed still contains `brand` / `model` / `sn`, compose SHALL ignore those keys for merge (or omit them when copying a missing runtime file) so flash + compose cannot reset per-unit identity.

#### Scenario: Operator camera_ip preserved

- **WHEN** `/var/lib/hal/product.ini` already has `camera_ip=10.0.0.5` and OEM seed has `camera_ip=192.168.1.100`
- **THEN** after compose the runtime file SHALL still contain `camera_ip=10.0.0.5`

#### Scenario: OEM brand/model do not overwrite identity

- **WHEN** Vendor Storage has brand `Innohi` and model `YNH960`, and OEM seed has `brand=LaserCyber` and `model=L1 Pro`
- **THEN** after compose `ProductInfo.brand` / `model` SHALL remain `Innohi` / `YNH960`
- **AND** compose MUST NOT force those OEM values into Vendor Storage or as identity authority in `product.ini`

#### Scenario: Missing runtime file seeded without identity authority

- **WHEN** `/var/lib/hal/product.ini` is absent and OEM seed exists with tunables and optional stale `brand`/`model`/`sn` lines
- **THEN** compose SHALL create `/var/lib/hal/product.ini` with tunable seed keys
- **AND** product identity SHALL still come from Vendor Storage (not from those seed identity lines)
