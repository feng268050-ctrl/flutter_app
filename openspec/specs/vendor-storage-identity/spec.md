# vendor-storage-identity Specification

## Purpose
TBD - created by archiving change vendor-storage-product-identity. Update Purpose after archive.
## Requirements
### Requirement: Vendor Storage GPT partitions exist and are frozen

The product GPT in `board/parameter-buildroot-fit.txt` (and packaged `parameter.txt`) SHALL include four consecutive partitions named `vendor0`, `vendor1`, `vendor2`, and `vendor3`, each **64 KiB** (`0x80` 512-byte sectors). After the first production adoption of this layout, the start LBA and size of each `vendor*` partition SHALL be treated as a frozen ABI: subsequent parameter revisions MUST NOT move or shrink them without an explicit documented migration that accepts identity data loss. The partitions SHALL be placed so that Rockchip Vendor Storage drivers can bind (PARTNAME `vendor0`–`vendor3`).

#### Scenario: Parameter lists vendor0–vendor3

- **WHEN** an operator inspects the product `parameter` CMDLINE after this change
- **THEN** it SHALL contain `vendor0`, `vendor1`, `vendor2`, and `vendor3` each with size `0x80`

#### Scenario: Geometry freeze

- **WHEN** a later change proposes altering any `vendor*` start or size
- **THEN** the change MUST document migration / data-loss impact and MUST NOT be treated as a silent compatible edit

### Requirement: make flash MUST NOT package vendor payloads

`make build-img` / factory packaging SHALL include Vendor Storage partitions in GPT via `parameter` but MUST NOT add `vendor0`–`vendor3` entries to `package-file` and MUST NOT embed `vendor*.img` (or equivalent) in `factory.img` / `update.img`. Build or verify tooling SHALL fail closed if `package-file` lists a vendor partition or if a vendor image is present in the factory staging inputs. `make flash` (`upgrade_tool uf`) therefore SHALL NOT overwrite Vendor Storage contents when flashing a compliant factory image with unchanged vendor geometry.

#### Scenario: package-file has no vendor rows

- **WHEN** inspecting the ynh960 Linux A/B `package-file` used by `build-img`
- **THEN** it SHALL NOT contain `vendor0`, `vendor1`, `vendor2`, or `vendor3` payload rows

#### Scenario: Accidental vendor image fails the build

- **WHEN** a `vendor0.img` (or other `vendor*.img`) is present in factory staging or package-file references a vendor partition
- **THEN** `make build-img` (or its verify step) SHALL exit non-zero before producing a releasable `factory.img`

#### Scenario: Reflash preserves provisioned SN

- **WHEN** a board has a non-empty product SN in Vendor Storage, vendor GPT geometry is unchanged, and the operator runs a compliant `make flash`
- **THEN** after reboot the product SN read path SHALL still return that same SN

### Requirement: Vendor Storage ID map for brand, model, and sn

Per-unit identity SHALL be stored in Rockchip Vendor Storage with this ID map: **SN** → `VENDOR_SN_ID` (1); **BRAND** → product ID **20**; **MODEL** → product ID **21**. Values SHALL be trimmed ASCII strings without newline characters. The repository SHALL document these IDs in a single source of truth consumed by board helpers and host tooling. Empty or missing SN in Vendor Storage SHALL cause product SN resolution to fall back to chip/board serial (same fallback chain as today’s chip ID), while brand and model SHALL be empty strings when absent.

#### Scenario: Provisioned triple is readable

- **WHEN** Vendor Storage holds SN at ID 1, brand at ID 20, and model at ID 21
- **THEN** board identity helpers and HAL product identity SHALL expose those three string values

#### Scenario: Empty SN falls back to chip ID

- **WHEN** Vendor Storage has no SN (or blank) and chip/board serial resolves to `ABC123`
- **THEN** product SN SHALL equal `ABC123` and chip ID SHALL remain the chip serial

### Requirement: Host make write-identity provisions Vendor Storage

The host build system SHALL provide `make write-identity` that writes `BRAND`, `MODEL`, and product serial onto the selected board over USB-SSH or registered SSH (same device selection rules as `push-app` / `shell`: `SN=` / `CHIP_ID=` / `IP=` for selection). The identity serial value SHALL be passed as **`PRODUCT_SN=`** so it is not confused with device-selection `SN=`. The host SHALL invoke on-board Vendor Storage write helpers (not package identity into `factory.img`). If a non-empty SN is already stored and `FORCE` is not `1`, the command SHALL refuse to overwrite and exit non-zero. After a successful write, tooling SHALL verify readback of the three fields and SHOULD restart `hmi.service` so the App reloads identity.

#### Scenario: First-time write

- **WHEN** Vendor Storage SN is empty and the operator runs `CHIP_ID=ABC123 make write-identity BRAND=LaserCyber MODEL=L1 Pro PRODUCT_SN=LC-001`
- **THEN** the board SHALL store those three values in Vendor Storage and readback SHALL match

#### Scenario: Refuse overwrite without FORCE

- **WHEN** Vendor Storage already has a non-empty SN and the operator runs `make write-identity` with a different `PRODUCT_SN` without `FORCE=1`
- **THEN** the command SHALL fail without changing stored identity

#### Scenario: FORCE overwrites

- **WHEN** Vendor Storage already has a non-empty SN and the operator runs the same write with `FORCE=1`
- **THEN** the command SHALL replace brand, model, and SN with the new values after successful write

### Requirement: HAL and board serial helpers read identity from Vendor Storage

HAL `ProductInfo.brand`, `ProductInfo.model`, and `ProductInfo.sn` SHALL be loaded from Vendor Storage (IDs above), not from `product.ini` keys `brand` / `model` / `sn`. `ProductInfo.chipId` SHALL remain chip/board serial and MUST NEVER equal the product SN key from `product.ini`. Board helpers used for USB gadget iSerial and host `make devices` SN enrichment SHALL use the same product SN rule as `ProductInfo.sn`. Stale `brand`/`model`/`sn` lines in `/var/lib/hal/product.ini` MUST be ignored for these properties.

#### Scenario: Ini stale keys ignored

- **WHEN** `product.ini` contains `sn=OLD` but Vendor Storage SN is `NEW`
- **THEN** `ProductInfo.sn` and `make devices` SN SHALL be `NEW`

#### Scenario: SysInfo still exposes both

- **WHEN** Vendor Storage SN is `FACTORY-001` and chip serial is `ABC123`
- **THEN** `SysInfoSnapshot.serialNumber` SHALL be `FACTORY-001` and `chipId` SHALL be `ABC123`

### Requirement: On-board vendor_storage tooling

The appliance rootfs SHALL include a working Vendor Storage userspace tool (Rockchip `vendor_storage` or equivalent) and thin HMI helpers under `/usr/libexec/hmi/` that read and write the product identity ID map. After GPT adoption, `/dev/vendor_storage` SHALL be usable for these helpers on real hardware. Emulator or environments without Vendor Storage SHALL fail clearly on write and SHALL apply the documented empty-SN → chip-ID fallback on read.

#### Scenario: Device node present on hardware

- **WHEN** a ynh960-class board has adopted the vendor GPT and booted the new rootfs
- **THEN** identity write helpers SHALL be able to open Vendor Storage successfully

#### Scenario: Emulator write fails clearly

- **WHEN** `make write-identity` targets the QEMU emulator without Vendor Storage
- **THEN** the command SHALL exit non-zero with a clear message rather than silently writing `product.ini` identity keys

### Requirement: Optional RockUSB SN-only path documented

Documentation SHALL state that macOS `tools/upgrade_tool` `SN` / `RSN` may write/read the Rockchip SN ID over RockUSB Loader/Maskrom, and that **BRAND** and **MODEL** are not provisioned by that path—full identity uses `make write-identity` after Linux boots. Host automation for full identity MUST NOT require RockUSB write-number for brand/model.

#### Scenario: Docs distinguish paths

- **WHEN** an operator reads Makefile help or README identity guidance after this change
- **THEN** it SHALL describe SSH `write-identity` for brand/model/sn and MAY mention RockUSB `SN`/`RSN` as SN-only

