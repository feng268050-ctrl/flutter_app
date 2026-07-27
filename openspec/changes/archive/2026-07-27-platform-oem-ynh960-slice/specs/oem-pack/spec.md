## ADDED Requirements

### Requirement: OEM pack source layout

The repository SHALL provide an `oem/` tree with `packs/<pack_id>/manifest.json`, `boards/<board_id>/` (at least `board_profile.json`), and `screens/<screen_id>/` (at least `screen.json`). Pack selection SHALL be compile-time / factory (`FACTORY_SKU` / `OEM_ID`), not arbitrary runtime motherboard autodetection.

#### Scenario: ynh960 pack present

- **WHEN** a developer inspects `oem/packs/ynh960+panel-800x1280/manifest.json`
- **THEN** the manifest SHALL declare `board_id` `ynh960` and a screen id for the 800×1280 panel with paths under `boards/` and `screens/`

### Requirement: OEM manifest schema

On-device `/oem/manifest.json` SHALL include at least: `schema_version`, `pack_id`, `board_id`, `screen_id`, `board_path`, `screen_path`. Optional `compat` MAY include `os_min` and `soc_family`.

#### Scenario: Compose reads pack identity

- **WHEN** `oem-compose` starts and `/oem/manifest.json` is valid
- **THEN** it SHALL resolve `board_path` and `screen_path` relative to `/oem` and refuse to proceed if either path is missing

### Requirement: OEM board profile excludes product gpio/modbus

OEM `board_profile.json` SHALL declare board identity, capabilities, net roles, helpers, storage mounts, and route metrics as needed. It MUST NOT be the authoritative owner of `configs.gpio` / `configs.modbus` product catalogs (those remain App assets).

#### Scenario: OEM profile has no product catalogs

- **WHEN** inspecting `oem/boards/ynh960/board_profile.json`
- **THEN** it SHALL NOT point gpio/modbus configs at OEM-owned pin/register maps as the product authority

### Requirement: Screen pack screen.json

Each screen pack SHALL provide `screen.json` with at least logical `width` / `height` and `default_orientation` (and MAY include display name, lcd param file references, splash notes).

#### Scenario: ynh960 panel screen.json

- **WHEN** compose succeeds for the ynh960 panel pack
- **THEN** `/run/hmi/screen.env` SHALL expose orientation (and related) values derived from that `screen.json`

### Requirement: oem-compose early boot

Rootfs SHALL include `/usr/libexec/hmi/oem-compose.sh` and an `oem-compose.service` ordered before HMI. Compose SHALL ensure `PARTLABEL=oem` is mounted at `/oem`, validate manifest, and write at least `/run/hmi/oem.env` and `/run/hmi/board_profile.json` (and screen env). On invalid OEM content it SHALL fail visibly in the journal and MUST NOT silently load a different board's profile. During the migration window only, a missing `/oem` pack MAY fall back to a documented rootfs-bundled ynh960 default with an explicit deprecation log.

#### Scenario: Valid OEM exports run files

- **WHEN** a valid oem partition is mounted and `oem-compose` runs
- **THEN** `/run/hmi/oem.env` and `/run/hmi/board_profile.json` exist before `hmi.service` starts

#### Scenario: Corrupt OEM does not swap boards

- **WHEN** `/oem/manifest.json` exists but `board_path` is missing
- **THEN** compose SHALL exit non-zero (or mark failure) without writing another board's profile as success

### Requirement: build-oem produces ext4 oem.img

The build system SHALL provide `make build-oem` that resolves `FACTORY_SKU` / `OEM_ID`, assembles the selected pack into a staging tree, and writes an **ext4** image at `oem/out/<oem_id>/oem.img` (or the documented equivalent under that oem_id).

#### Scenario: Default SKU build-oem

- **WHEN** the operator runs `FACTORY_SKU=ynh960-p800 make build-oem` (or the default sku)
- **THEN** `oem/out/ynh960+panel-800x1280/oem.img` (or matching oem_id path) exists and is an ext4 filesystem image

### Requirement: FACTORY_SKU resolves uboot and oem paths

`build-oem`, `build-img`, and `flash` SHALL share one resolver: `FACTORY_SKU` looks up default `UBOOT_ID` and `OEM_ID` from a repo SKU table; `UBOOT_ID` / `OEM_ID` env MAY override. Bootloader inputs SHALL come from `prebuilt/bootloader/<uboot_id>/`. Missing required files SHALL fail the command; the build MUST NOT silently reuse an unrelated leftover uboot/oem from a previous SKU.

#### Scenario: Missing bootloader fails build-img

- **WHEN** `FACTORY_SKU` resolves to a `uboot_id` whose `prebuilt/bootloader/<uboot_id>/uboot.img` is absent
- **THEN** `make build-img` exits non-zero without producing a factory image that mixes in another SKU's uboot

### Requirement: Factory image includes oem

`make build-img` SHALL package the resolved `oem.img` into the factory artifact written under `output/firmware/<factory_sku>/factory.img`, and SHALL write a sibling `manifest.txt` recording resolved `uboot_id`, `oem_id`, and build identity. During migration, `output/firmware/update.img` MAY be a symlink (or copy) to the selected/default sku's `factory.img`.

#### Scenario: factory.img packs oem

- **WHEN** `oem.img` exists for the selected oem_id and the operator runs `FACTORY_SKU=ynh960-p800 make build-img`
- **THEN** `output/firmware/ynh960-p800/factory.img` exists and the package includes the oem partition payload
