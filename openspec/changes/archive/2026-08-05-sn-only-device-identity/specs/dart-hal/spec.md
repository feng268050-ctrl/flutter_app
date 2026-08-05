## MODIFIED Requirements

### Requirement: System info host inventory

The HAL SHALL provide `hal/sys_info` exposing a structured host snapshot including at least: board serial number (product SN); chip ID; product `brand` and product `model` when sourced from product identity (Vendor Storage via `ProductInfo`); Linux kernel version; Flutter app version information; CPU core count and frequency summary; memory total (and available when obtainable); primary flash/storage capacity (and free space when obtainable for documented mount points); thermal zone temperatures when sysfs thermal is present; and uptime. Board/DT model and image/`os-release` build id SHOULD be included when available (DT model remains distinct from product `model`). Board serial number SHALL resolve via product identity SN rules (non-empty Vendor Storage SN, else chip ID). Chip ID SHALL be the chip/board serial and MUST NOT use a stale `properties.ini` `sn` key. Chip ID on the snapshot remains available to Apps for diagnostics and secrets binding; it is **not** an operator host-selection identity (`make devices` / `SN=`). `hal/sys_info` MUST NOT include Modbus- or lower-device-derived fields; those SHALL use `hal/modbus` attributes. Opaque product tunables beyond built-in identity SHALL remain on `ProductInfo.get`, not as required snapshot fields.

#### Scenario: SN and kernel from host

- **WHEN** the App requests a sys_info snapshot on device
- **THEN** serial number SHALL come from product identity SN resolution (Vendor Storage SN or chip ID) and kernel version from the running Linux kernel, not from Modbus registers

#### Scenario: Chip ID on snapshot

- **WHEN** the App requests a sys_info snapshot and chip serial is available
- **THEN** the snapshot SHALL include `chipId` equal to the chip serial even when a stale ini `sn` line exists

#### Scenario: Brand and model on snapshot

- **WHEN** Vendor Storage holds brand and model and the App requests a sys_info snapshot
- **THEN** the snapshot SHALL include those brand and model values from product identity
