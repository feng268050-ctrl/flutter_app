## MODIFIED Requirements

### Requirement: Built-in product identity properties

The HAL SHALL expose a `ProductInfo` (or equivalent) type with built-in string properties `brand`, `model`, `sn`, and `chipId`. `brand`, `model`, and `sn` SHALL come from Rockchip Vendor Storage (see `vendor-storage-identity` ID map). Absent or blank Vendor Storage brand/model SHALL yield the empty string. `chipId` SHALL be the chip/board serial from `/proc/cpuinfo` Serial → DT `serial-number` → documented fallbacks (never a `properties.ini` `sn` key). For `sn`: if Vendor Storage contains a non-empty SN, that value SHALL be used; otherwise `sn` SHALL equal `chipId`. Stale `brand` / `model` / `sn` keys in `properties.ini` MUST be ignored. Apps MUST obtain these values from HAL, not by reading Vendor Storage or `properties.ini` directly. `SysInfoSnapshot` SHALL expose `serialNumber` (product SN) and `chipId`. **Operator host identity** (`make devices`, device selection) SHALL use **SN only**; `chipId` remains a hardware field for Apps, diagnostics, and secrets — it MUST NOT appear as a host device-table column or `CHIP_ID=` selector.

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

#### Scenario: properties.ini sn ignored

- **WHEN** `properties.ini` contains `sn=FROM-INI` and Vendor Storage SN is empty and chip serial is `ABC123`
- **THEN** `ProductInfo.sn` SHALL be `ABC123` (not `FROM-INI`)

### Requirement: Host SN matches ProductInfo sn

Board serial helpers used for USB gadget iSerial and host device listing (`make devices` / SSH registry enrichment) SHALL resolve **SN** with the same rule as `ProductInfo.sn`: non-empty Vendor Storage SN first, then chip/board serial fallbacks. The `make devices` table SHALL include column **SN** and MUST NOT include a **ChipID** column. Host tooling MUST prefer a live board identity probe over host USB gadget iSerial when both are available. Host device selection SHALL use env **`SN=`** matching the listed **SN** only. Deprecated **`SERIAL=`** SHALL be accepted as an alias for **`SN=`**. Host tooling MUST NOT accept **`CHIP_ID=`** as a device selector (if set, commands SHALL fail with a hint to use `SN=`). Makefile `help`, README, and AGENTS.md SHALL document `SN=` (not `SERIAL=` / `CHIP_ID=`) as the primary selector, and SHALL document `make write-identity` for provisioning brand/model/product SN.

#### Scenario: make devices shows factory sn only

- **WHEN** the device has Vendor Storage SN `FACTORY-001`, chip serial is `ABC123`, and the board is reachable via USB-SSH or LAN SSH enrichment
- **THEN** the listed **SN** column SHALL be `FACTORY-001`
- **AND** the table SHALL NOT include a **ChipID** column

#### Scenario: make devices falls back to chip serial for SN

- **WHEN** Vendor Storage SN is missing or blank and chip serial is `ABC123`
- **THEN** the listed **SN** column SHALL be `ABC123`

#### Scenario: Android or RockUSB row uses SerialNo as SN

- **WHEN** listing an Android adb device or RockUSB loader device with SerialNo `RK123`
- **THEN** **SN** SHALL show the adb serial / upgrade_tool SerialNo
- **AND** the table SHALL NOT include a separate ChipID column

### Requirement: Host make set-prop upserts properties.ini

The host build system SHALL provide `make set-prop` that upserts one or more properties on the selected board (USB-SSH or registered SSH device, same selection rules as `push-app` / `shell`). Each assignment SHALL be `UPPERCASE_KEY=value` on the Make command line and SHALL be written to `/var/lib/hal/properties.ini` as the corresponding lowercase key (e.g. `CAMERA_IP` → `camera_ip`). **Multiple** assignments in one invocation SHALL be applied together via one remote file replace. Make/workflow variables that are not property keys (at least `IP`, deprecated `SERIAL`, `SN` as device selection, and other documented host vars) MUST be ignored as property keys. `make set-prop` MUST refuse to write identity keys `brand`, `model`, and `sn` (including `BRAND=` / `MODEL=` / a sole `SN=` property assignment) and MUST fail with an error that points operators to **`make write-identity`** (Vendor Storage). After a successful write, the host tooling SHALL restart the on-device HMI service so the App reloads tunables.

#### Scenario: Single property upsert

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50` against a reachable board
- **THEN** `/var/lib/hal/properties.ini` on the device SHALL contain `camera_ip=192.168.1.50`
- **AND** `hmi.service` SHALL be restarted after the write

#### Scenario: Multiple properties in one set-prop

- **WHEN** the operator runs `make set-prop CAMERA_IP=192.168.1.50 CAMERA_TYPE=2`
- **THEN** the remote `properties.ini` SHALL contain `camera_ip=192.168.1.50` and `camera_type=2` after one successful mutate
- **AND** HMI SHALL be restarted once (not once per key)

#### Scenario: set-prop refuses identity keys

- **WHEN** the operator runs `make set-prop BRAND=Innohi` or `make set-prop MODEL=YNH960` or `make set-prop SN=FACTORY-001`
- **THEN** the command SHALL fail without writing `properties.ini`
- **AND** HMI MUST NOT be restarted
- **AND** the error SHALL point to `make write-identity`

#### Scenario: set-prop with no property assignment fails

- **WHEN** the operator runs `make set-prop` with no `UPPERCASE_KEY=value` property assignment
- **THEN** the command SHALL fail with usage guidance and MUST NOT restart HMI
