## ADDED Requirements

### Requirement: Rockchip boards retain Vendor Storage alongside provision

On Rockchip product boards, Vendor Storage SHALL remain the authority for per-unit **brand**, **model**, **sn**, sealed cloud Ed25519 (ID **22**), and HUK-wrapped seal KEK (ID **23**). The GPT **`provision`** partition SHALL hold factory tunables (`properties.ini`) per `gpt-provision-partition`. Identity helpers MUST NOT read OEM `identity.env` or userdata for brand/model/sn on Rockchip boards when `/dev/vendor_storage` exists.

#### Scenario: VS authority on Rockchip

- **WHEN** `/dev/vendor_storage` is present and VS SN is `LC001`
- **THEN** `read-identity sn` SHALL return `LC001` regardless of provision or OEM files

#### Scenario: Loader SN path unchanged

- **WHEN** documentation describes factory identity provisioning after this change
- **THEN** it SHALL state that Rockchip Loader/Maskrom `SN`/`RSN` use Vendor Storage SN ID
- **AND** full brand/model still use `make write-identity` over SSH

## MODIFIED Requirements

### Requirement: HAL and board serial helpers read identity from Vendor Storage

HAL `ProductInfo.brand`, `ProductInfo.model`, and `ProductInfo.sn` on **Rockchip boards** SHALL be loaded from Vendor Storage (IDs above), not from `properties.ini` or OEM identity files. On boards **without** Vendor Storage, identity SHALL be loaded from `provision/identity.env` per `gpt-provision-partition`. `ProductInfo.chipId` SHALL remain chip/board serial. Board helpers for USB gadget iSerial and host `make devices` SHALL use the same product SN rule. Host `make devices` MUST list **SN** only. Stale identity keys in userdata `properties.ini` MUST be ignored.

#### Scenario: Ini stale keys ignored

- **WHEN** userdata or provision `properties.ini` contains `sn=OLD` but Vendor Storage SN is `NEW`
- **THEN** `ProductInfo.sn` and `make devices` SN SHALL be `NEW`

#### Scenario: Emulator without VS uses provision identity

- **WHEN** the QEMU guest has no `/dev/vendor_storage` and `provision/identity.env` has `sn=SIM-A1B2`
- **THEN** `ProductInfo.sn` SHALL be `SIM-A1B2` (not OEM seed)

### Requirement: On-board vendor_storage tooling

The appliance rootfs SHALL include Vendor Storage tooling and board helpers for Rockchip boards. Emulator or environments without Vendor Storage SHALL read identity from **provision** (not OEM stub) and SHALL apply empty-SN → chip-ID fallback on read. `make write-identity` on non-Rockchip or emulator SHALL write provision `identity.env` when VS is unavailable instead of exiting solely for missing `/dev/vendor_storage`.

#### Scenario: Emulator write uses provision

- **WHEN** `make write-identity` targets the QEMU guest without Vendor Storage
- **THEN** the command SHALL succeed by writing `provision/identity.env`
- **AND** SHALL NOT write identity keys into userdata `properties.ini`

#### Scenario: Emulator OEM stub removed

- **WHEN** inspecting OEM source for `boards/sim`
- **THEN** `identity.env` SHALL not be shipped in the pack

### Requirement: make flash MUST NOT package vendor payloads

`make build-img` / factory packaging SHALL include Vendor Storage partitions in GPT via `parameter` but MUST NOT add `vendor0`–`vendor3` or **`provision`** entries to `package-file` and MUST NOT embed `vendor*.img` or `provision.img` in `factory.img` / `update.img`. Build or verify tooling SHALL fail closed if package-file lists those partitions or if such images appear in factory staging. Compliant `make flash` with unchanged geometry SHALL preserve Vendor Storage and provision contents.

#### Scenario: Repeat flash preserves provision tunables

- **WHEN** `properties.ini` on provision holds `camera_ip=10.0.0.50` before a second compliant `make flash`
- **THEN** after reboot `camera_ip` SHALL still be `10.0.0.50`

## REMOVED Requirements

### Requirement: Emulator stub via OEM identity.env

**Reason**: Per-unit identity must not live in shared OEM packs; emulator uses virtio `provision.img`.

**Migration**: Remove `oem/boards/sim/identity.env`; use `provision/identity.env` or `make write-identity` on the guest.
