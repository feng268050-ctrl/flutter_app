## MODIFIED Requirements

### Requirement: System info host inventory

The HAL SHALL provide `hal/sys_info` exposing a structured host snapshot including at least: board serial number (product SN); chip ID; product `brand` and product `model` when sourced from product identity (`product.ini` / `ProductInfo`); Linux kernel version; Flutter app version information; CPU core count and frequency summary; memory total (and available when obtainable); primary flash/storage capacity (and free space when obtainable for documented mount points); thermal zone temperatures when sysfs thermal is present; and uptime. Board/DT model and image/`os-release` build id SHOULD be included when available (DT model remains distinct from product `model`). Board serial number SHALL resolve via product identity SN rules (non-empty `product.ini` `sn`, else chip ID). Chip ID SHALL be the chip/board serial and MUST NOT use the factory `product.ini` `sn` key. `hal/sys_info` MUST NOT include Modbus- or lower-device-derived fields; those SHALL use `hal/modbus` attributes. Extended product tunables (`camera_ip`, `camera_type`, `focus_scale_ref`, `control_card_comm_alarm_mode`, and future keys) SHALL be exposed via HAL `ProductInfo` accessors, not as required `SysInfoSnapshot` inventory fields. A portable `hal/device_info` or `hal/http` module SHALL NOT be introduced. Live Wi‑Fi/ethernet addressing SHALL remain under `hal/network`, not sys_info. Missing sensors or nodes SHALL yield unavailable/null fields rather than failing the whole snapshot; missing product brand/model SHALL yield empty strings on the product identity surface. `SysInfo.watch` SHALL emit a primed snapshot then change-only updates when volatile fields (thermal, CPU freq, available memory, load) change.

#### Scenario: SN and kernel from host

- **WHEN** the App requests a sys_info snapshot on device
- **THEN** serial number SHALL come from product identity SN resolution (product.ini `sn` or chip ID) and kernel version from the running Linux kernel, not from Modbus registers

#### Scenario: Chip ID on snapshot

- **WHEN** the App requests a sys_info snapshot and chip serial is available
- **THEN** the snapshot SHALL include `chipId` equal to the chip serial even when product.ini overrides SN

#### Scenario: Brand and model on snapshot

- **WHEN** `product.ini` defines `brand` and `model` and the App requests a sys_info snapshot
- **THEN** the snapshot SHALL include those product brand and model strings

#### Scenario: CPU memory storage thermal

- **WHEN** the App requests a sys_info snapshot on a typical RK356x image
- **THEN** the snapshot SHALL include CPU core count, a memory total, a storage capacity for the primary flash, and thermal readings when thermal zones exist

#### Scenario: Lower-device firmware not in sys_info

- **WHEN** a product shows laser/gun firmware from Modbus
- **THEN** those values SHALL be read via modbus attribute ids and MUST NOT appear as fields on `SysInfo`

#### Scenario: Extended tunables via ProductInfo

- **WHEN** the App needs `camera_ip` or `control_card_comm_alarm_mode`
- **THEN** it SHALL read them from HAL `ProductInfo` accessors rather than from `SysInfoSnapshot` inventory fields
