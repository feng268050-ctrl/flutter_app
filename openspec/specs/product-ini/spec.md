# product-ini Specification

## Purpose
Factory product identity and tunables for Linux HMI: `/var/lib/hmi/product.ini`, HAL `ProductInfo`, Device Information display rules, host `make devices` SN/ChipID selection, and `make set-prop` / `del-prop`.

## Requirements
### Requirement: Product.ini file location and format

The system SHALL treat `/var/lib/hal/product.ini` as the product identity and factory-tunable configuration file (path injectable in HAL tests). The file SHALL be a flat `key=value` text format: blank lines ignored; lines whose first non-whitespace character is `#` treated as comments. Missing file SHALL be equivalent to an empty map (all keys absent).

#### Scenario: Missing product.ini yields empty product fields

- **WHEN** `/var/lib/hal/product.ini` does not exist
- **THEN** product built-in properties and extended accessors SHALL return empty strings (except `sn`, which SHALL apply chip-serial fallback)

#### Scenario: Comment and blank lines ignored

- **WHEN** the file contains blank lines and `#` comment lines mixed with `brand=Acme`
- **THEN** `brand` SHALL resolve to `Acme` and comments SHALL NOT produce keys

### Requirement: Built-in product identity properties

The HAL SHALL expose a `ProductInfo` (or equivalent) type with built-in string properties `brand`, `model`, `sn`, and `chipId`. Absent or blank keys in `product.ini` SHALL yield the empty string for `brand` and `model`. `chipId` SHALL be the chip/board serial from DT → `/proc/cpuinfo` Serial → documented fallbacks (never the factory `product.ini` `sn` key). For `sn`: if `product.ini` contains a non-empty `sn` value, that value SHALL be used; otherwise `sn` SHALL equal `chipId`. Apps MUST obtain these values from HAL, not by reading the file directly. `SysInfoSnapshot` SHALL expose `serialNumber` (product SN) and `chipId`.

#### Scenario: Brand and model from ini

- **WHEN** `product.ini` contains `brand=Innohi` and `model=YNH960`
- **THEN** `ProductInfo.brand` SHALL be `Innohi` and `ProductInfo.model` SHALL be `YNH960`

#### Scenario: Factory sn preferred over chip serial

- **WHEN** `product.ini` contains a non-empty `sn=FACTORY-001` and a chip serial is also available
- **THEN** `ProductInfo.sn` SHALL be `FACTORY-001`
- **AND** `ProductInfo.chipId` SHALL be the chip serial (not `FACTORY-001`)

#### Scenario: Chip serial when sn key absent

- **WHEN** `product.ini` has no `sn` key (or blank `sn`) and chip/board serial resolves to `ABC123`
- **THEN** `ProductInfo.sn` and `ProductInfo.chipId` SHALL both be `ABC123`

### Requirement: Extended product keys via accessors

The HAL `ProductInfo` SHALL provide accessors (functions/methods) for at least: `camera_ip`, `camera_type`, `focus_scale_ref`, and `control_card_comm_alarm_mode`. Each SHALL return the trimmed ini value or empty string when absent. Typed accessors for `camera_type` SHALL accept only `1` or `2` (otherwise empty). Typed accessors for `control_card_comm_alarm_mode` SHALL accept only `slide_window` or `immediate` (otherwise empty). A generic `get(key)` SHALL return the raw trimmed value or empty string for any key (including unknown future keys).

The product App SHALL apply a non-empty `control_card_comm_alarm_mode` to Modbus HAL via `applyHealthWindowMode` when continuous poll starts (C001 window mode). When the key is absent or empty, HAL SHALL keep the product `modbus.json` `poll.health.mode` default (`slide_window`). Host `make set-prop CONTROL_CARD_COMM_ALARM_MODE=…` SHALL write the lowercase key and restart HMI so the mode reloads.

#### Scenario: Extended key present

- **WHEN** `product.ini` contains `camera_ip=192.168.1.50` and `camera_type=2`
- **THEN** the camera IP accessor SHALL return `192.168.1.50` and the camera type accessor SHALL return `2`

#### Scenario: Invalid enum yields empty typed value

- **WHEN** `product.ini` contains `camera_type=9`
- **THEN** the typed camera type accessor SHALL return the empty string
- **AND** `get('camera_type')` SHALL still return `9`

#### Scenario: Unknown key via generic get

- **WHEN** `product.ini` contains `custom_factory_flag=yes`
- **THEN** `get('custom_factory_flag')` SHALL return `yes` without requiring a HAL API change

#### Scenario: Comm alarm mode drives C001 window

- **WHEN** `product.ini` contains `control_card_comm_alarm_mode=immediate` and Modbus live poll starts
- **THEN** the App SHALL call HAL `applyHealthWindowMode('immediate')` so C001 uses immediate mode

### Requirement: Host SN matches ProductInfo sn

Board serial helpers used for USB gadget iSerial and host device listing (`make devices` / SSH registry enrichment) SHALL resolve **SN** with the same rule as `ProductInfo.sn`: non-empty `product.ini` `sn` first, then chip/board serial fallbacks. The `make devices` table SHALL include columns **SN** and **ChipID** (ChipID = chip serial / adb SerialNo / RockUSB SerialNo). Host tooling MUST prefer a live board identity probe over host USB gadget iSerial when both are available. Host device selection SHALL use env **`SN=`** / **`LWS_HMI_SN=`** (matching SN or ChipID). **`CHIPID=`** / **`LWS_HMI_CHIPID=`** SHALL match ChipID only. Deprecated **`SERIAL=`** / **`LWS_HMI_SERIAL=`** SHALL be accepted as aliases for **`SN=`**. Makefile `help`, README, and AGENTS.md SHALL document `SN=` (not `SERIAL=`) as the primary selector.

#### Scenario: make devices shows factory sn and chip id

- **WHEN** the device has `product.ini` with `sn=FACTORY-001`, chip serial is `ABC123`, and the board is reachable via USB-SSH or LAN SSH enrichment
- **THEN** the listed **SN** column SHALL be `FACTORY-001`
- **AND** the listed **ChipID** column SHALL be `ABC123`

#### Scenario: make devices falls back to chip serial for SN

- **WHEN** `product.ini` is missing or has blank `sn` and chip serial is `ABC123`
- **THEN** both **SN** and **ChipID** SHALL be `ABC123`

#### Scenario: android and RockUSB ChipID

- **WHEN** an android adb device or RockUSB loader device is listed
- **THEN** **ChipID** SHALL show the adb serial / upgrade_tool SerialNo (chip identity)
- **AND** **SN** SHALL equal **ChipID** for those modes

#### Scenario: SN env selects board

- **WHEN** multiple boards are listed and the operator sets `SN=FACTORY-001` (or `SN=ABC123`)
- **THEN** host commands that require a single target SHALL select the matching row

#### Scenario: CHIPID env selects one board

- **WHEN** multiple boards are present and the operator runs `CHIPID=ABC123 make set-prop CAMERA_IP=192.168.1.50`
- **THEN** device selection SHALL use ChipID `ABC123` and the product `camera_ip` key SHALL be written

### Requirement: Device Information empty display

When Device Information (or equivalent About UI) displays Device Model, Device SN, Camera Type, or Focus Scale Reference from product identity, an empty or unavailable value SHALL be shown to the user as `-`. Device Model SHALL be formed as `brand + " " + model` with each missing part as `-`; if both parts are missing (computed `- -`), the UI SHALL show a single `-`. Camera Type SHALL map `camera_type` `1` → `Blue Light`, `2` → `Red Light` (invalid/empty → `-`) and SHALL appear immediately before Focus Scale Reference. Device Information SHALL present rows in three groups (identity / versions / platform with Display Stack + Camera Type + Focus Scale Reference), SHALL offer a device identity QR (v2: `SN|2|Model|SystemVersion`), and MUST NOT show Modbus Link.

#### Scenario: Missing brand and model shows single dash

- **WHEN** `ProductInfo.brand` and `ProductInfo.model` are empty and the user opens Device Information
- **THEN** the Device Model row SHALL display `-`

#### Scenario: Missing focus scale shows dash

- **WHEN** `focus_scale_ref` is absent from `product.ini` and the user opens Device Information
- **THEN** Focus Scale Reference SHALL display `-`

### Requirement: Host make set-prop upserts product.ini

The host build system SHALL provide `make set-prop` that upserts one or more product properties on the selected board (USB-SSH or registered SSH device, same selection rules as `push-app` / `shell`). Each assignment SHALL be `UPPERCASE_KEY=value` on the Make command line and SHALL be written to `/var/lib/hal/product.ini` as the corresponding lowercase key (e.g. `CAMERA_IP` → `camera_ip`). Unlike lws-ui’s single-key restriction, **multiple** assignments in one invocation SHALL be applied together via one remote file replace. Make/workflow variables that are not product keys (at least `CHIPID`, `IP`, deprecated `SERIAL`, `SN` as device selection, and other documented host vars) MUST be ignored as property keys. `make set-prop` MUST refuse to write OEM identity keys `brand`, `model`, and `sn` (including `BRAND=` / `MODEL=` / a sole `SN=` product assignment) and MUST fail with an error that points operators to the OEM board `product.ini` seed. After a successful write, the host tooling SHALL restart the on-device HMI service so the App reloads product identity.

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

### Requirement: OEM board pack seeds product.ini

For v1, each OEM board directory MAY include a `product.ini` factory seed (keys such as `brand`, `model`, `sn`, `camera_ip`, and other product tunables). Runtime HAL and host tooling continue to use `/var/lib/hal/product.ini` as the authoritative live file. `make set-prop` / `del-prop` SHALL keep writing the runtime path for non-identity tunables and MUST NOT require writing back into the OEM partition. Identity keys `brand` / `model` / `sn` SHALL be changed only via the OEM seed (then `make build-oem` / compose), not via host mutate commands.

#### Scenario: Seed file in OEM tree

- **WHEN** inspecting `oem/boards/ynh960/product.ini`
- **THEN** the file SHALL be valid `key=value` product.ini syntax and MAY include a non-empty `camera_ip` default

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
