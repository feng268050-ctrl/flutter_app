# vendor-storage-identity Specification

## Purpose

Rockchip Vendor Storage GPT layout, frozen ID map for product identity (SN /
brand / model), sealed cloud Ed25519 (ID 22), and HUK-wrapped OP-TEE seal KEK
(ID 23). Factory images MUST NOT overwrite vendor partitions so provisioned
identity and secrets survive flash.
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

`make build-img` / factory packaging SHALL include Vendor Storage partitions in GPT via `parameter` but MUST NOT add `vendor0`–`vendor3` or **`provision`** entries to `package-file` and MUST NOT embed `vendor*.img` or `provision.img` in `factory.img` / `update.img`. Build or verify tooling SHALL fail closed if package-file lists those partitions or if such images appear in factory staging. Compliant `make flash` with unchanged geometry SHALL preserve Vendor Storage and provision contents.

#### Scenario: Repeat flash preserves provision tunables

- **WHEN** `properties.ini` on provision holds `camera_ip=10.0.0.50` before a second compliant `make flash`
- **THEN** after reboot `camera_ip` SHALL still be `10.0.0.50`

### Requirement: Vendor Storage ID map for brand, model, and sn

Per-unit identity SHALL be stored in Rockchip Vendor Storage with this ID map: **SN** → `VENDOR_SN_ID` (1); **BRAND** → product ID **20**; **MODEL** → product ID **21**. Values SHALL be trimmed ASCII strings without newline characters. **Stored product SN** SHALL match **`[A-Za-z0-9]+`**. Operator input MAY include **`-`**, which host and board write helpers MUST strip before store (e.g. `L1P-S-001` → `L1PS001`); other non-alphanumeric characters MUST be rejected. Rationale: Rockchip U-Boot `rockchip_set_serialno` copies `VENDOR_SN_ID` into env `serial#` / FDT `serial-number` and truncates at the first non-alphanumeric character. The repository SHALL document these IDs in a single source of truth consumed by board helpers and host tooling. Empty or missing SN in Vendor Storage SHALL cause product SN resolution to fall back to chip/board serial (same fallback chain as today’s chip ID), while brand and model SHALL be empty strings when absent.

#### Scenario: Provisioned triple is readable

- **WHEN** Vendor Storage holds SN at ID 1, brand at ID 20, and model at ID 21
- **THEN** board identity helpers and HAL product identity SHALL expose those three string values

#### Scenario: Empty SN falls back to chip ID

- **WHEN** Vendor Storage has no SN (or blank) and chip/board serial resolves to `ABC123`
- **THEN** product SN SHALL equal `ABC123` and chip ID SHALL remain the chip serial

### Requirement: Host make write-identity provisions Vendor Storage

The host build system SHALL provide `make write-identity` that writes `BRAND`, `MODEL`, and product serial onto the selected board over USB-SSH or registered SSH (same device selection rules as `push-app` / `shell`: `SN=` / `IP=` for selection; **`CHIP_ID=` MUST NOT be accepted**). The identity serial value SHALL be passed as **`PRODUCT_SN=`** so it is not confused with device-selection `SN=`. The host SHALL invoke on-board Vendor Storage write helpers (not package identity into `factory.img`). If a non-empty SN is already stored and `FORCE` is not `1`, the command SHALL refuse to overwrite and exit non-zero. After a successful write, tooling SHALL verify readback of the three fields and SHOULD restart `hmi.service` so the App reloads identity.

#### Scenario: First-time write

- **WHEN** Vendor Storage SN is empty and the operator runs `SN=ABC123 make write-identity BRAND=LaserCyber MODEL=L1 Pro PRODUCT_SN=LC-001`
- **THEN** the board SHALL store brand/model and SN `LC001` (hyphens stripped) in Vendor Storage and readback SHALL match

#### Scenario: Strip hyphens from PRODUCT_SN

- **WHEN** the operator runs `make write-identity` with `PRODUCT_SN=L1P-S-001`
- **THEN** the stored SN SHALL be `L1PS001`

#### Scenario: Reject other non-alphanumeric PRODUCT_SN

- **WHEN** the operator runs `make write-identity` with `PRODUCT_SN=L1P_S_001` (underscore or other non-alnum besides `-`)
- **THEN** the command SHALL fail without writing Vendor Storage

#### Scenario: Refuse overwrite without FORCE

- **WHEN** Vendor Storage already has a non-empty SN and the operator runs `make write-identity` with a different `PRODUCT_SN` without `FORCE=1`
- **THEN** the command SHALL fail without changing stored identity

#### Scenario: FORCE overwrites

- **WHEN** Vendor Storage already has a non-empty SN and the operator runs the same write with `FORCE=1`
- **THEN** the command SHALL replace brand, model, and SN with the new values after successful write

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

#### Scenario: Cloud Ed25519 helpers without VS

- **WHEN** `/dev/vendor_storage` is absent and provision is mounted
- **THEN** `read-cloud-ed25519-sealed` / `write-cloud-ed25519-sealed` SHALL use `/mnt/provision/cloud-ed25519.sealed`
- **AND** SHALL NOT fail solely because Vendor Storage is missing (unlike pre-provision emulator behavior)

#### Scenario: Emulator OEM stub removed

- **WHEN** inspecting OEM source for `boards/sim`
- **THEN** `identity.env` SHALL not be shipped in the pack

### Requirement: Optional RockUSB SN-only path documented

Documentation SHALL state that macOS `tools/upgrade_tool` `SN` / `RSN` may write/read the Rockchip SN ID over RockUSB Loader/Maskrom, and that **BRAND** and **MODEL** are not provisioned by that path—full identity uses `make write-identity` after Linux boots. Host automation for full identity MUST NOT require RockUSB write-number for brand/model.

#### Scenario: Docs distinguish paths

- **WHEN** an operator reads Makefile help or README identity guidance after this change
- **THEN** it SHALL describe SSH `write-identity` for brand/model/sn and MAY mention RockUSB `SN`/`RSN` as SN-only

### Requirement: Vendor Storage ID for sealed cloud Ed25519 private key

The Vendor Storage ID map SHALL include a frozen product custom ID for the **sealed** cloud Ed25519 private-key blob: decimal ID **22** (`VENDOR_CUSTOM_ID_16`). The repository source of truth (`board/vendor-storage-ids.txt` and the on-device copy under `/usr/libexec/board/`) SHALL document this ID alongside SN/brand/model. The stored value SHALL be the opaque Secrets seal ciphertext (not plaintext key material). Plaintext Ed25519 private keys MUST NOT be written to Vendor Storage. This ID SHALL NOT be repurposed after field freeze without an explicit migration.

#### Scenario: ID map documents cloud key slot

- **WHEN** inspecting `board/vendor-storage-ids.txt` after this change
- **THEN** it SHALL define ID **22** for the sealed cloud Ed25519 private-key blob

#### Scenario: No plaintext private key in Vendor Storage

- **WHEN** the cloud key is persisted
- **THEN** the Vendor Storage item at ID **22** MUST contain Secrets-sealed ciphertext only

### Requirement: Vendor Storage ID for HUK-wrapped seal KEK

The Vendor Storage ID map SHALL include a frozen product custom ID for the **HUK-wrapped** OP-TEE seal KEK blob: decimal ID **23** (`VENDOR_CUSTOM_ID_17`). The repository source of truth (`board/vendor-storage-ids.txt` and the on-device copy under `/usr/libexec/board/`) SHALL document this ID alongside SN/brand/model and cloud Ed25519 ID 22. The stored value SHALL be the opaque wrap ciphertext defined by `hal-secrets-kek` (not plaintext KEK). Plaintext seal KEKs MUST NOT be written to Vendor Storage. This ID SHALL NOT be repurposed after field freeze without an explicit migration.

#### Scenario: ID map documents wrapped seal KEK slot

- **WHEN** inspecting `board/vendor-storage-ids.txt` after this change
- **THEN** it SHALL define ID **23** for the HUK-wrapped seal KEK blob

#### Scenario: No plaintext KEK in Vendor Storage

- **WHEN** the seal KEK persistence material is written
- **THEN** the Vendor Storage item at ID **23** MUST contain the opaque wrap blob only

### Requirement: On-board helpers for wrapped seal KEK

The appliance rootfs SHALL provide thin board helpers under `/usr/libexec/board/` to read and write Vendor Storage ID **23** (names parallel to cloud Ed25519 sealed helpers). Helpers SHALL fail clearly when `/dev/vendor_storage` is unavailable (e.g. emulator). Operator or HMI migrate paths MAY invoke these helpers (`make migrate-seal-kek` / `secrets-seal sync-kek`); Apps MUST NOT embed raw Vendor Storage ioctls for this ID.

#### Scenario: Helpers present on product image

- **WHEN** a product image with this change is inspected
- **THEN** read/write helpers for the wrapped seal KEK ID SHALL exist under `/usr/libexec/board/`

### Requirement: Rockchip boards retain Vendor Storage alongside provision

On Rockchip product boards, Vendor Storage SHALL remain the authority for per-unit **brand**, **model**, **sn**, sealed cloud Ed25519 (ID **22**), and HUK-wrapped seal KEK (ID **23**). The GPT **`provision`** partition SHALL hold factory tunables (`properties.ini`) per `gpt-provision-partition`. Identity helpers MUST NOT read OEM `identity.env` or userdata for brand/model/sn on Rockchip boards when `/dev/vendor_storage` exists.

#### Scenario: VS authority on Rockchip

- **WHEN** `/dev/vendor_storage` is present and VS SN is `LC001`
- **THEN** `read-identity sn` SHALL return `LC001` regardless of provision or OEM files

#### Scenario: Loader SN path unchanged

- **WHEN** documentation describes factory identity provisioning after this change
- **THEN** it SHALL state that Rockchip Loader/Maskrom `SN`/`RSN` use Vendor Storage SN ID
- **AND** full brand/model still use `make write-identity` over SSH

