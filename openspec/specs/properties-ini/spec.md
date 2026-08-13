# properties-ini Specification

## Purpose
Runtime tunables at `/var/lib/hal/properties.ini`, HAL `ProductInfo` identity (Vendor Storage) + opaque `get(key)`, host `set-prop` / `del-prop`, and migration from legacy `product.ini`. Supersedes `product-ini`.
## Requirements
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

### Requirement: Opaque properties via get only

The HAL `ProductInfo` SHALL expose built-in identity fields only: `brand`, `model`, `sn`, and `chipId`. All other properties.ini entries are **unknown to HAL**: a generic `get(key)` SHALL return the trimmed value or empty string when absent. HAL MUST NOT define product-specific accessors or enums for keys such as `camera_ip`, `camera_type`, `focus_scale_ref`, or `control_card_comm_alarm_mode`. Product Apps own key names, typing, defaults, and Modbus/UI application (e.g. LWS HMI `product_property_defaults.dart`).

#### Scenario: Opaque key via generic get

- **WHEN** `properties.ini` contains `camera_ip=192.168.1.50` and `custom_factory_flag=yes`
- **THEN** `get('camera_ip')` SHALL return `192.168.1.50` and `get('custom_factory_flag')` SHALL return `yes`
- **AND** HAL SHALL NOT require a named `cameraIp()` API

#### Scenario: Missing opaque key is empty

- **WHEN** `camera_type` is absent from `properties.ini`
- **THEN** `get('camera_type')` SHALL return the empty string

#### Scenario: LWS HMI applies product defaults and C001 mode

- **WHEN** the LWS HMI App starts Modbus live poll and `control_card_comm_alarm_mode` is absent
- **THEN** the App SHALL apply its product default `slide_window` (or a set `immediate` value) via `applyHealthWindowMode`
- **AND** HAL `ProductInfo` SHALL only have supplied the raw `get` string (empty when absent)

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

### Requirement: Device Information empty display

When Device Information (or equivalent About UI) displays Device Model, Device SN, Camera Type, or Focus Scale Reference from product identity/tunables, an empty or unavailable value SHALL be shown to the user as `-`. Device Model SHALL be formed as `brand + " " + model` with each missing part as `-`; if both parts are missing (computed `- -`), the UI SHALL show a single `-`. Camera Type SHALL map `camera_type` `1` → `Blue Light`, `2` → `Red Light` (invalid/empty → `-`) and SHALL appear immediately before Focus Scale Reference where that row set is shown. Device Information SHALL present rows in three groups (identity / versions / platform with Display Stack + Camera Type + Focus Scale Reference as applicable), SHALL offer a device identity QR (v2: `SN|2|Model|SystemVersion`), and MUST NOT show Modbus Link.

#### Scenario: Missing brand and model shows single dash

- **WHEN** `ProductInfo.brand` and `ProductInfo.model` are empty and the user opens Device Information
- **THEN** the Device Model row SHALL display `-`

#### Scenario: Missing focus scale uses App default zero

- **WHEN** `focus_scale_ref` is absent from `properties.ini` and the user opens Device Information on LWS HMI
- **THEN** Focus Scale Reference SHALL display `0`

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

### Requirement: No OEM properties seed

OEM board packs MUST NOT ship `product.ini` or `properties.ini` factory seeds. `oem-compose` MUST NOT create, copy, or merge keys into `/var/lib/hal/properties.ini` (or legacy `product.ini`). Tunables SHALL be provisioned only via host `set-prop` / on-device writes to the runtime file (or equivalent operator tooling).

#### Scenario: OEM tree has no properties seed

- **WHEN** inspecting `oem/boards/ynh960/` and `oem/boards/sim/`
- **THEN** those directories MUST NOT contain `product.ini` or `properties.ini`

#### Scenario: Compose does not create properties.ini

- **WHEN** `/var/lib/hal/properties.ini` is absent and oem-compose runs successfully
- **THEN** compose MUST NOT create `/var/lib/hal/properties.ini`

### Requirement: Migrate legacy product.ini basename

On provision mount and before host `set-prop` / `del-prop` mutate, if the provision-backed `properties.ini` is absent and a legacy `product.ini` or userdata copy exists, the system SHALL migrate tunables into `/mnt/provision/properties.ini` (copy from `/userdata/hal/product.ini` or `/userdata/hal/properties.ini` once). If both legacy userdata copies exist, `properties.ini` SHALL win. After migration, userdata copies SHALL NOT remain authoritative.

#### Scenario: Migrate from userdata hal tree

- **WHEN** `/userdata/hal/properties.ini` contains `camera_ip=10.0.0.5` and provision has no file
- **THEN** after first boot migration `/mnt/provision/properties.ini` SHALL contain `camera_ip=10.0.0.5`
- **AND** `/var/lib/hal/properties.ini` SHALL read from provision

