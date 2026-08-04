# oem-pack Specification

## Purpose
OEM board×screen packs: source layout under oem/, on-device /oem compose into /run/hmi, ext4 oem.img via make build-oem, and FACTORY_SKU selection for factory.img.
## Requirements
### Requirement: OEM pack source layout

The repository SHALL provide an `oem/` tree with `packs/<pack_id>/manifest.json`, `boards/<board_id>/` (at least `board_profile.json`), and `screens/<screen_id>/` (at least `screen.json`). Pack selection SHALL be compile-time / factory (`FACTORY_SKU` / `OEM_ID`), not arbitrary runtime motherboard autodetection.

#### Scenario: ynh960 pack present

- **WHEN** a developer inspects `oem/packs/ynh960_panel-800x1280/manifest.json`
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

### Requirement: Board helpers live under OEM

OEM board packs SHALL place board-specific bringup scripts under `boards/<board_id>/helpers/` (device path `/oem/boards/<board_id>/helpers/`). OEM `board_profile.json` `helpers` entries for modem bringup and USB OTG mode SHALL use absolute paths under `/oem/boards/<board_id>/helpers/`. Portable stack helpers (wpa/network/bluetooth stack-up, A/B, oem-compose, hmi-launch) SHALL remain on rootfs.

#### Scenario: ynh960 profile points at OEM helpers

- **WHEN** inspecting `oem/boards/ynh960/board_profile.json` after W2
- **THEN** `helpers.wifi_modem`, `helpers.bt_modem`, and `helpers.usb_otg_mode` SHALL reference paths under `/oem/boards/ynh960/helpers/`

#### Scenario: Wi-Fi stack resolves modem from profile

- **WHEN** `wifi-stack-up` runs and `/run/hmi/board_profile.json` (or compose oem.env) provides a modem helper path
- **THEN** it SHALL invoke that path instead of hardcoding only `/usr/libexec/bluetooth/wifibt-bringup.sh`

### Requirement: Screen pack LCD seed files

Screen packs that require Innohi ParamUpdate / private1 LCD tables SHALL ship those files under `screens/<screen_id>/lcd/` and reference them from `screen.json`. Early display-init SHALL seed private1 **only** from the active OEM screen `lcd/` directory (resolved via `/oem/manifest.json` without requiring `/run/hmi`). Missing OEM lcd files SHALL fail visibly; the init MUST NOT seed from `/system/etc` as a fallback.

#### Scenario: OEM lcd seeds private1

- **WHEN** `/oem/manifest.json` is valid and the resolved screen `lcd/` directory contains the required LCD param files
- **THEN** display-init SHALL copy those OEM files into private1

#### Scenario: Missing OEM lcd fails hard

- **WHEN** OEM is missing `manifest.json` or screen `lcd/` lacks required param files
- **THEN** display-init SHALL exit non-zero without copying `/system/etc` LCD tables into private1

### Requirement: HMI launch consumes screen.env defaults

`hmi-launch` SHALL use operator-persisted orientation from `display.conf` when set. When orientation is unset, it SHALL apply `SCREEN_DEFAULT_ORIENTATION` from `/run/hmi/screen.env` (written by oem-compose from `screen.json`). If neither source provides a value, `hmi-launch` SHALL exit non-zero (no hardcoded orientation fallback).

#### Scenario: screen.env used when display.conf empty

- **WHEN** `display.conf` has no orientation key and `/run/hmi/screen.env` sets `SCREEN_DEFAULT_ORIENTATION=landscape_left`
- **THEN** `hmi-launch` SHALL start the HMI with that orientation

#### Scenario: Operator preference wins

- **WHEN** `display.conf` sets `orientation=portrait` and `screen.env` sets a different default
- **THEN** `hmi-launch` SHALL use the operator `portrait` (or mapped) orientation

#### Scenario: Missing orientation fails

- **WHEN** `display.conf` has no orientation and `screen.env` is missing or has an empty `SCREEN_DEFAULT_ORIENTATION`
- **THEN** `hmi-launch` SHALL exit non-zero

### Requirement: Screen pack screen.json

Each screen pack SHALL provide `screen.json` with at least logical `width` / `height` and `default_orientation`. When LCD param tables are required for the panel, `lcd_param_files` SHALL list paths relative to the screen pack (under `lcd/`), not repository `board/*.txt` paths alone. Compose SHALL continue to expose orientation (and related) values in `/run/hmi/screen.env`.

#### Scenario: ynh960 panel screen.json

- **WHEN** compose succeeds for the ynh960 panel pack
- **THEN** `/run/hmi/screen.env` SHALL expose orientation (and related) values derived from that `screen.json`

#### Scenario: lcd_param_files under screen pack

- **WHEN** inspecting `oem/screens/panel-ynh960-800x1280/screen.json`
- **THEN** `lcd_param_files` entries SHALL refer to files under that screen pack's `lcd/` directory

### Requirement: oem-compose early boot

Rootfs SHALL include `/usr/libexec/hmi/oem-compose.sh` and an `oem-compose.service` ordered before HMI. Compose SHALL ensure `PARTLABEL=oem` is mounted at `/oem`, validate manifest, and write at least `/run/hmi/oem.env` and `/run/hmi/board_profile.json` (and screen env) with `OEM_SOURCE=partition`. On missing or invalid OEM content it SHALL fail visibly in the journal and MUST NOT load a rootfs-bundled fallback pack or silently swap boards. Rootfs MUST NOT ship `/usr/share/hmi/oem-fallback`.

#### Scenario: Valid OEM exports run files

- **WHEN** a valid oem partition is mounted and `oem-compose` runs
- **THEN** `/run/hmi/oem.env` and `/run/hmi/board_profile.json` exist before `hmi.service` starts and `OEM_SOURCE=partition`

#### Scenario: Corrupt OEM does not swap boards

- **WHEN** `/oem/manifest.json` exists but `board_path` is missing
- **THEN** compose SHALL exit non-zero without writing another board's profile as success

#### Scenario: Missing OEM fails hard

- **WHEN** `/oem/manifest.json` is absent after mount attempt
- **THEN** compose SHALL exit non-zero and MUST NOT compose from any rootfs fallback tree

### Requirement: build-oem produces ext4 oem.img

The build system SHALL provide `make build-oem` that resolves `FACTORY_SKU` / `OEM_ID`, assembles the selected pack into a staging tree, and writes an **ext4** image at `oem/out/<oem_id>/oem.img` (or the documented equivalent under that oem_id).

#### Scenario: Default SKU build-oem

- **WHEN** the operator runs `FACTORY_SKU=ynh960-p800 make build-oem` (or the default sku)
- **THEN** `oem/out/ynh960_panel-800x1280/oem.img` (or matching oem_id path) exists and is an ext4 filesystem image

### Requirement: FACTORY_SKU resolves uboot and oem paths

`build-oem`, `build-img`, and `flash` SHALL share one resolver: `FACTORY_SKU` looks up default `UBOOT_ID` and `OEM_ID` from a repo SKU table; `UBOOT_ID` / `OEM_ID` env MAY override. Bootloader inputs SHALL come from `prebuilt/bootloader/<uboot_id>/`. Missing required files SHALL fail the command; the build MUST NOT silently reuse an unrelated leftover uboot/oem from a previous SKU.

#### Scenario: Missing bootloader fails build-img

- **WHEN** `FACTORY_SKU` resolves to a `uboot_id` whose `prebuilt/bootloader/<uboot_id>/uboot.img` is absent
- **THEN** `make build-img` exits non-zero without producing a factory image that mixes in another SKU's uboot

### Requirement: Factory image includes oem

`make build-img` SHALL package the resolved `oem.img` into the factory artifact written under `output/firmware/<APP>/<factory_sku>/factory.img` (default `APP=lws_hmi`), and SHALL write a sibling `manifest.txt` recording resolved `app`, `uboot_id`, `oem_id`, and build identity. During migration, `output/firmware/update.img` MAY be a symlink (or copy) to the selected/default APP + sku's `factory.img`.

#### Scenario: factory.img packs oem

- **WHEN** `make build-oem` then `make build-img` succeed for default APP and `ynh960-p800`
- **THEN** `output/firmware/lws_hmi/ynh960-p800/factory.img` exists and the package includes the oem partition payload

### Requirement: sim_virt OEM pack

The repository SHALL provide OEM pack `sim_virt` with `oem/packs/sim_virt/manifest.json` declaring `board_id` `sim`, `screen_id` `virt`, paths `boards/sim` and `screens/virt`, and `compat.soc_family` of `virt` (not `rk356x`). `OEM_ID=sim_virt make build-oem` SHALL produce `oem/out/sim_virt/oem.img`.

#### Scenario: sim_virt pack present

- **WHEN** a developer inspects `oem/packs/sim_virt/manifest.json`
- **THEN** the manifest SHALL declare `pack_id` `sim_virt`, `board_id` `sim`, `screen_id` `virt`, and `compat.soc_family` `virt`

#### Scenario: build-oem for sim_virt

- **WHEN** `OEM_ID=sim_virt make build-oem` succeeds
- **THEN** `oem/out/sim_virt/oem.img` SHALL exist as an ext4 image containing the pack layout

### Requirement: sim board profile without OTG

OEM `oem/boards/sim/board_profile.json` SHALL declare capabilities for ethernet, wifi, bluetooth, gpio, modbus, sysInfo, datetime, sshDebug, and typical I/O (backlight/volume/keyboard/mouse as applicable). It MUST omit `usbOtg`. It MUST NOT reference ynh960 helper paths. Product gpio/modbus catalogs remain App-owned. For the QEMU guest, helpers MAY include `modbus_rtu_device` remapping Modbus RTU to the USB-serial node (e.g. `/dev/ttyUSB0`) while product `modbus.json` keeps the board UART path for ynh960.

#### Scenario: No usbOtg and no ynh960 helpers

- **WHEN** inspecting `oem/boards/sim/board_profile.json`
- **THEN** capabilities SHALL NOT include `usbOtg` and helpers SHALL NOT point at `/oem/boards/ynh960/`

#### Scenario: Emulator Modbus device remap

- **WHEN** inspecting sim board helpers used by the emulator guest
- **THEN** `modbus_rtu_device` SHALL be present and point at a USB-serial path suitable for host passthrough

### Requirement: virt screen without lcd seed

OEM `oem/screens/virt/screen.json` SHALL declare logical width/height and `default_orientation` for the QEMU virtio display (defaults aligned with emulator `xres`/`yres`). It MUST NOT require `lcd/` ParamUpdate files for compose or HMI launch on the virt guest.

#### Scenario: virt screen.json compose

- **WHEN** oem-compose succeeds for `sim_virt`
- **THEN** `/run/hmi/screen.env` SHALL expose `SCREEN_DEFAULT_ORIENTATION` from virt `screen.json` without requiring lcd param files

### Requirement: OEM board_id aligns with FIT configuration

OEM pack `manifest.json` (and thus on-device `/oem/manifest.json`) SHALL declare `board_id` that corresponds to the FIT configuration name used to boot that SKU. OEM MUST NOT supply the startup device tree. Compose or host verify MAY fail or warn when a pack’s `board_id` is not present in the running OS’s documented FIT board inventory for that OS version.

#### Scenario: Manifest board_id matches FIT conf name

- **WHEN** inspecting `oem/packs/*/manifest.json` for a product pack
- **THEN** `board_id` SHALL be a FIT configuration id expected by `boot-fit-multi-dt` (e.g. `ynh960`)
- **AND** startup DTB files MUST NOT appear under `/oem` as the boot source

#### Scenario: Compose does not load DTB from OEM

- **WHEN** `oem-compose` runs successfully
- **THEN** it SHALL export board profile / screen env as today
- **AND** it MUST NOT replace the kernel’s loaded device tree from OEM contents

### Requirement: build-oem includes board radio firmware when present

When a board pack contains `radio/firmware/`, `make build-oem` SHALL install that tree into the OEM image under the board path so runtime bring-up can read it from `/oem` without relying on rootfs multi-vendor firmware dumps.

#### Scenario: Radio subtree packed into oem.img

- **WHEN** the board pack includes `radio/manifest.json` and `radio/firmware/` and `make build-oem` runs
- **THEN** those paths MUST appear under the corresponding `/oem/boards/<board_id>/radio/` in the oem image

### Requirement: OEM product.ini is not per-unit identity authority

OEM board packs MAY ship a `product.ini` seed for SKU tunables under `boards/<board_id>/product.ini`. That seed MUST NOT be the authority for per-unit `brand`, `model`, or `sn` after Vendor Storage adoption. Per-unit identity SHALL be provisioned and read via Rockchip Vendor Storage (`vendor-storage-identity`). OEM documentation and pack contents SHOULD omit identity keys from the seed; compose MUST NOT use OEM identity keys to overwrite Vendor Storage or to act as the live product SN source.

#### Scenario: ynh960 seed is tunables-oriented

- **WHEN** inspecting `oem/boards/ynh960/product.ini` after this change
- **THEN** the file MAY define tunables such as `camera_ip`
- **AND** operators MUST NOT rely on it to set or preserve a per-unit product SN across `make flash`

