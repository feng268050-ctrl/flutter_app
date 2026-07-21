## ADDED Requirements

### Requirement: Product.ini file location and format

The system SHALL treat `/var/lib/hmi/product.ini` as the product identity and factory-tunable configuration file (path injectable in HAL tests). The file SHALL be a flat `key=value` text format: blank lines ignored; lines whose first non-whitespace character is `#` treated as comments. Missing file SHALL be equivalent to an empty map (all keys absent).

#### Scenario: Missing product.ini yields empty product fields

- **WHEN** `/var/lib/hmi/product.ini` does not exist
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

#### Scenario: CHIPID env with set-prop SN

- **WHEN** multiple boards are present and the operator runs `CHIPID=ABC123 make set-prop SN=FACTORY-001`
- **THEN** device selection SHALL use ChipID `ABC123` and the product `sn` key SHALL be written as `FACTORY-001`

### Requirement: Device Information empty display

When Device Information (or equivalent About UI) displays Device Model, Device SN, Camera Type, or Focus Scale Reference from product identity, an empty or unavailable value SHALL be shown to the user as `-`. Device Model SHALL be formed as `brand + " " + model` with each missing part as `-`; if both parts are missing (computed `- -`), the UI SHALL show a single `-`. Camera Type SHALL map `camera_type` `1` → `Blue Light`, `2` → `Red Light` (invalid/empty → `-`) and SHALL appear immediately before Focus Scale Reference. Device Information SHALL present rows in three groups (identity / versions / platform with Display Stack + Camera Type + Focus Scale Reference), SHALL offer a device identity QR (v2: `SN|2|Model|SystemVersion`), and MUST NOT show Modbus Link.

#### Scenario: Missing brand and model shows single dash

- **WHEN** `ProductInfo.brand` and `ProductInfo.model` are empty and the user opens Device Information
- **THEN** the Device Model row SHALL display `-`

#### Scenario: Missing focus scale shows dash

- **WHEN** `focus_scale_ref` is absent from `product.ini` and the user opens Device Information
- **THEN** Focus Scale Reference SHALL display `-`

### Requirement: Host make set-prop upserts product.ini

The host build system SHALL provide `make set-prop` that upserts one or more product properties on the selected board (USB-SSH or registered SSH device, same selection rules as `push-app` / `shell`). Each assignment SHALL be `UPPERCASE_KEY=value` on the Make command line and SHALL be written to `/var/lib/hmi/product.ini` as the corresponding lowercase key (e.g. `CAMERA_IP` → `camera_ip`). Unlike lws-ui’s single-key restriction, **multiple** assignments in one invocation SHALL be applied together via one remote file replace. Make/workflow variables that are not product keys (at least `CHIPID`, `IP`, deprecated `SERIAL`, and other documented host vars) MUST be ignored as property keys. `SN=` on `make set-prop` SHALL write the product `sn` key and MUST NOT be treated as device selection for that invocation (multi-board: use `CHIPID=` / `IP=` / deprecated `SERIAL=`). After a successful write, the host tooling SHALL restart the on-device HMI service so the App reloads product identity.

#### Scenario: Single property upsert

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50` against a reachable board
- **THEN** `/var/lib/hmi/product.ini` on the device SHALL contain `camera_ip=192.168.1.50`
- **AND** `hmi.service` SHALL be restarted after the write

#### Scenario: Multiple properties in one set-prop

- **WHEN** the operator runs `make set-prop BRAND=Innohi MODEL=YNH960 SN=FACTORY-001`
- **THEN** the remote `product.ini` SHALL contain `brand=Innohi`, `model=YNH960`, and `sn=FACTORY-001` after one successful mutate
- **AND** HMI SHALL be restarted once (not once per key)

#### Scenario: set-prop with no product assignment fails

- **WHEN** the operator runs `make set-prop` with no `UPPERCASE_KEY=value` product assignment
- **THEN** the command SHALL fail with usage guidance and MUST NOT restart HMI

### Requirement: Host make del-prop removes a product.ini key

The host build system SHALL provide `make del-prop` that removes exactly one product key per invocation. The key SHALL be given as an UPPERCASE identifier (as a Make goal or equivalent), mapped to the lowercase file key, and removed from `/var/lib/hmi/product.ini` on the selected board. If the key is absent, the command SHALL warn and MUST NOT fail solely for absence. After a successful file update that changes the file contents, tooling SHALL restart HMI. When the key was absent (no file change), tooling MUST NOT fail and SHOULD skip the HMI restart.

#### Scenario: Delete existing key

- **WHEN** `product.ini` contains `camera_ip=192.168.1.50` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the `camera_ip` line SHALL be removed from the remote file
- **AND** HMI SHALL be restarted after the update

#### Scenario: Delete missing key is non-fatal

- **WHEN** `camera_ip` is not present in `product.ini` and the operator runs `make del-prop CAMERA_IP`
- **THEN** the command SHALL report that the key was not present and SHALL exit successfully (non-zero only for transport/auth/IO failures)
- **AND** HMI SHOULD NOT be restarted solely because of a missing-key no-op
