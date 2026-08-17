# gpt-provision-partition Specification

## Purpose
TBD - created by archiving change gpt-provision-partition. Update Purpose after archive.
## Requirements
### Requirement: GPT provision partition exists and geometry is frozen

The product GPT in `board/parameter-buildroot-fit.txt` (and packaged `parameter.txt`) SHALL include a partition named **`provision`** with `PARTLABEL=provision`, placed **before** the grow `userdata` entry. Default size for the ynh960 product line SHALL be **4 MiB** (`0x2000` 512-byte sectors). After first production adoption, start LBA and size of `provision` SHALL be treated as a **frozen ABI** (same policy as `vendor0`–`vendor3`). Subsequent parameter revisions MUST NOT move or shrink `provision` without an explicit documented migration that accepts provision data loss.

#### Scenario: Parameter lists provision before userdata grow

- **WHEN** an operator inspects the product `parameter` CMDLINE after this change
- **THEN** it SHALL contain `provision` with fixed size before `-@…(userdata:grow)`

#### Scenario: Geometry freeze

- **WHEN** a later change proposes altering `provision` start or size
- **THEN** the change MUST document migration / data-loss impact and MUST NOT be treated as a silent compatible edit

### Requirement: Rockchip boards use Vendor Storage plus provision

For boards whose SoC family is Rockchip (`compat.soc_family` `rk356x` or equivalent Rockchip profile), the platform SHALL persist:

- **Vendor Storage** (IDs per `vendor-storage-identity`): `brand`, `model`, `sn`, sealed cloud Ed25519 (ID 22), HUK-wrapped seal KEK (ID 23).
- **provision partition:** `properties.ini` and future factory tunables files only — **not** authoritative identity on Rockchip.

Rockchip boards MUST retain `vendor0`–`vendor3` in GPT and MUST NOT move product identity authority to OEM or userdata. Vendor Storage SHALL remain the path recognized by Rockchip Loader/Maskrom SN tooling (`upgrade_tool SN` / `RSN`).

#### Scenario: Rockchip dual layer after provision

- **WHEN** a ynh960-class board has provisioned VS SN and `properties.ini` on provision
- **THEN** `read-identity sn` SHALL return the VS SN
- **AND** `ProductInfo.get('camera_ip')` SHALL read from provision-bound `properties.ini`
- **AND** Loader/Maskrom SN read SHALL match VS SN when VS is provisioned

#### Scenario: provision does not override Rockchip identity

- **WHEN** `provision/identity.env` contains `sn=FROM-PROVISION` and Vendor Storage SN is `FROM-VS`
- **THEN** `ProductInfo.sn` and `read-identity sn` SHALL be `FROM-VS`

### Requirement: Non-Rockchip boards use provision only

For boards without Rockchip Vendor Storage, all provision data SHALL live on the `provision` partition: `identity.env` (`brand` / `model` / `sn`), `properties.ini`, sealed cloud Ed25519 blob at **`/mnt/provision/cloud-ed25519.sealed`**, and seal KEK wrap file at **`/mnt/provision/seal-kek.wrap`**. `make write-identity` SHALL write `identity.env` on provision (not fail solely because `/dev/vendor_storage` is absent).

Board helpers `read-cloud-ed25519-sealed` / `write-cloud-ed25519-sealed` SHALL route storage by availability: when `/dev/vendor_storage` is present, read/write Vendor Storage ID **22**; otherwise read/write the provision file above. Helpers MUST store **opaque Secrets-sealed ciphertext only** (never plaintext private keys). HAL `CloudEd25519SealedStore` continues to shell these helpers — no duplicate VS/provision routing in Dart.

#### Scenario: write-identity on non-Rockchip

- **WHEN** the operator runs `make write-identity` on a board without `/dev/vendor_storage` but with mounted provision
- **THEN** `provision/identity.env` SHALL hold the written brand, model, and SN
- **AND** readback via `read-identity` SHALL match

#### Scenario: Cloud Ed25519 sealed blob on provision when VS absent

- **WHEN** the guest or board has no `/dev/vendor_storage`, mounted provision, non-empty product SN, and 云服务 enabled
- **AND** `CloudEd25519Identity.ensureLocalKey` seals a new identity
- **THEN** `write-cloud-ed25519-sealed` SHALL persist to `/mnt/provision/cloud-ed25519.sealed`
- **AND** `read-cloud-ed25519-sealed --present` SHALL exit 0
- **AND** subsequent reboots SHALL load the same blob from provision (not regenerate)

#### Scenario: Rockchip cloud key stays on Vendor Storage

- **WHEN** `/dev/vendor_storage` is present on a Rockchip board
- **THEN** `read-cloud-ed25519-sealed` / `write-cloud-ed25519-sealed` SHALL use Vendor Storage ID **22**
- **AND** SHALL NOT treat `provision/cloud-ed25519.sealed` as authoritative over VS

### Requirement: make flash MUST NOT package provision payloads

`make build-img` / factory packaging SHALL define `provision` in `parameter` but MUST NOT add a `provision` row to `package-file` and MUST NOT embed `provision.img` in `factory.img` / `update.img`. Build or verify tooling SHALL fail closed if `package-file` lists `provision` or if a `provision.img` is present in factory staging inputs. The same omission contract applies to `vendor0`–`vendor3` (see `vendor-storage-identity`).

#### Scenario: package-file has no provision row

- **WHEN** inspecting the ynh960 Linux A/B `package-file` used by `build-img`
- **THEN** it SHALL NOT contain a `provision` payload row

#### Scenario: Accidental provision image fails the build

- **WHEN** `provision.img` is present in factory staging or package-file references `provision`
- **THEN** `make build-img` (or its verify step) SHALL exit non-zero before producing a releasable `factory.img`

#### Scenario: Repeat compliant flash preserves provision data

- **WHEN** a board has a non-empty `properties.ini` on provision and compliant `parameter` geometry is unchanged
- **AND** the operator runs `make flash` twice with compliant factory images
- **THEN** after the second flash `properties.ini` on provision SHALL still contain the same tunable keys
- **AND** on Rockchip boards Vendor Storage identity SHALL remain unchanged

### Requirement: provision mounted before HAL tunables bind

The appliance SHALL mount `PARTLABEL=provision` early in boot (before `bind-prefs` and before HAL/App reads tunables). Mount path SHALL be `/mnt/provision` (or documented equivalent). When the partition has no filesystem, the platform MAY `mkfs.ext4` once and mount — **only** when the partition is unformatted. Factory-reset and compliant flash MUST NOT format an already-mounted provision filesystem.

`/var/lib/hal/properties.ini` SHALL resolve to the provision-backed file (bind or symlink), not to `/userdata/hal/properties.ini`.

#### Scenario: properties.ini on provision after boot

- **WHEN** the board has booted with GPT `provision` present
- **THEN** `/var/lib/hal/properties.ini` SHALL be the same content as `/mnt/provision/properties.ini`

#### Scenario: One-time migration from userdata

- **WHEN** first boot after upgrade finds `properties.ini` only under `/userdata/hal/` and provision has no file
- **THEN** the platform SHALL copy tunables to `/mnt/provision/properties.ini` before Apps read tunables

#### Scenario: GPT adoption with stale superblock

- **WHEN** `PARTLABEL=provision` exists but the partition carries a stale or wrong ext4 superblock (e.g. old `LABEL=userdata` after repartition)
- **THEN** `provision-mount` SHALL `mkfs.ext4 -L provision` once and mount successfully
- **AND** SHALL bind `/var/lib/hal/properties.ini` to `/mnt/provision/properties.ini`

### Requirement: Factory-reset and userdata wipe MUST NOT erase provision

User factory-reset and full userdata wipe (flash hygiene or `/usr/bin/factory-reset`) SHALL erase **all** operator content on the **userdata** partition. They MUST NOT `mkfs`, `dd`, or delete files on `PARTLABEL=provision`. They MUST NOT clear Rockchip Vendor Storage IDs **1** / **20** / **21** / **22** / **23** on Rockchip boards.

#### Scenario: Factory-reset clears userdata only

- **WHEN** factory-reset completes on a provisioned board
- **THEN** userdata operator trees are empty or freshly formatted
- **AND** `/mnt/provision/properties.ini` is unchanged
- **AND** on Rockchip boards VS identity and ID 22/23 are unchanged

### Requirement: Emulator virtio provision disk

The P3.2 QEMU guest (`sim-virt`) SHALL use a host-side **`provision.img`** virtio disk (not baked into shared `rootfs.img` or OEM). `make build-emulator` SHALL stage or create `output/firmware/emulator/provision.img`. `make emulator` SHALL attach it so the guest mounts it as `provision`. Per-unit emulator identity when Vendor Storage is absent SHALL be stored in `provision/identity.env` on that disk. OEM packs MUST NOT ship per-unit `identity.env`.

#### Scenario: Emulator provision is per host instance

- **WHEN** two developers use separate `provision.img` files with the same `rootfs.img`
- **THEN** `read-identity sn` MAY differ between guests
- **AND** neither SN is sourced from OEM `boards/sim/identity.env`

#### Scenario: OEM sim identity stub removed

- **WHEN** inspecting `oem/boards/sim/` after this change
- **THEN** `identity.env` SHALL NOT be present in the OEM source tree

