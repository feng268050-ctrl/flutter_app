# host-remote-upgrade Specification

## Purpose
Developer full-system A/B upgrade (`make upgrade`): SSH stream-to-partition when Linux is up, or RockUSB Loader/Maskrom partition-download (`di`) of OTA-equivalent loose images — not `factory.img` / product OTA.

## Requirements

### Requirement: make upgrade flashes OTA-equivalent images over RockUSB Loader/Maskrom

When `make upgrade` selects a **RockUSB Loader or Maskrom** target (auto-dispatch or forced transport), the host SHALL flash the OTA-equivalent loose images with Rockchip `upgrade_tool` **partition download** (`di` or the documented equivalent), and MUST NOT invoke `upgrade_tool uf` on `factory.img` / `update.img` for this path. Required images for full-system RockUSB upgrade: shared `output/firmware/boot.img` and `boot_b.img`, and `output/firmware/<APP>/rootfs.img` (default `APP=lws_hmi`). Optional oem SHALL follow the same `FACTORY_SKU` / `OEM_ID` / `OEM_IMG` / `OEM_ONLY` rules as the SSH upgrade path. The RockUSB path MUST NOT write U-Boot, MiniLoader **into the storage OTA set**, `misc.img`, or GPT/`parameter` (Maskrom may still `ul` MiniLoader into RAM solely to enable downloads, matching `make flash` bring-up).

The host SHALL download `boot.img` → partition `boot`, `boot_b.img` → `boot_b`, and the same `rootfs.img` → **both** `rootfs_a` and `rootfs_b`. When oem is included, download into partition `oem`. userdata MUST NOT be wiped. Platform constraint: RockUSB upgrade SHALL remain **macOS-only** like `make flash`.

#### Scenario: Loader full-system RockUSB upgrade

- **WHEN** the board is in RockUSB Loader, required boot/boot_b/rootfs images exist, and the operator runs `make upgrade` such that RockUSB transport is selected
- **THEN** the host partition-downloads both FITs and writes `rootfs.img` to both rootfs letters (and oem when enabled) without `uf` of `factory.img`

#### Scenario: Maskrom bring-up then OTA images

- **WHEN** the board is in Maskrom and the operator runs RockUSB `make upgrade`
- **THEN** the host performs Maskrom loader bring-up (`ul` as needed) and then partition-downloads the OTA-equivalent images (not a full factory `uf`)

#### Scenario: OEM-only over RockUSB

- **WHEN** `OEM_ONLY=1` and RockUSB transport is selected and resolved `oem.img` exists
- **THEN** the host downloads only oem and does not write boot or rootfs partitions

#### Scenario: Missing OTA image fails before write

- **WHEN** RockUSB full-system upgrade is selected and `boot.img`, `boot_b.img`, or `output/firmware/<APP>/rootfs.img` is missing
- **THEN** the command exits non-zero without writing those partitions

### Requirement: make upgrade dispatches SSH stream vs RockUSB by device mode

`make upgrade` SHALL keep the existing **SSH stream-to-partition** path when a deployable Linux USB-SSH or registered SSH target is selected. When no such SSH target is selected but a RockUSB Loader/Maskrom device is, it SHALL use the RockUSB OTA-images path. When neither is available, it MUST fail with guidance to use `make devices`, SSH connectivity, `make reboot-loader`, or Maskrom. An optional env override (e.g. `UPGRADE_TRANSPORT=ssh|rockusb`) MAY force one transport; default is auto. Multi-device selection (`SN=` / `CHIP_ID=`) SHALL apply to RockUSB as it does for `make flash`.

#### Scenario: SSH board still streams

- **WHEN** exactly one USB-SSH Linux board is available and no RockUSB force is set
- **THEN** `make upgrade` uses stream-to-partition over SSH and does not RockUSB-download partitions

#### Scenario: Only RockUSB present

- **WHEN** no deployable SSH Linux target is available, one RockUSB Loader/Maskrom device is present, and required images exist
- **THEN** `make upgrade` uses the RockUSB OTA-images path

#### Scenario: No target

- **WHEN** neither SSH nor RockUSB targets are available
- **THEN** `make upgrade` exits non-zero with operator guidance

### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that upgrades Linux HMI firmware using one of two host transports:

1. **SSH stream (default when a Linux SSH target is selected):** select a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SN=` / `IP=`), perform a **stream-to-partition** full-system upgrade over SSH, and return successfully as soon as board `arm-reboot` is started (reboot requested). It SHALL NOT wait for SSH disconnect, post-reboot SSH, or claim that boot health was verified. For the stream path, the host SHALL: preflight the active/inactive letter and refuse unsafe slot state; stream **`rootfs.img`** from `output/firmware/<APP>/rootfs.img` (default `APP=lws_hmi`) into the inactive `rootfs_*` partition while transferring; stream **only the inactive letter’s FIT** (`boot.img` for letter A, `boot_b.img` for letter B) from shared `output/firmware/` into the try-boot FIT path on `boot` after the running FIT is backed up to `boot_b`; optionally stream **oem** when packaged; then arm try-boot and reboot. Default full-system SSH mode MUST update the inactive **boot and rootfs** letter pair (kernel + rootfs). The SSH stream path **MUST NOT** stage full firmware images under `/userdata/ota/` before writing (status/logs/tiny helpers may use that directory). The SSH stream path **MUST NOT** enter RockUSB solely to perform the upgrade and **MUST NOT** invoke Rockchip `upgrade_tool uf` / flash a `factory.img`.

2. **RockUSB OTA-images (when Loader/Maskrom is selected):** flash the OTA-equivalent loose images via partition download as specified in the RockUSB requirements of this capability — **not** product/unified OTA `tar.gz`+Ed25519 staged apply, and **not** `make flash` factory packaging.

Online / product OTA download-then-write remains out of scope for this command’s trust model and SHALL use the separate staged apply path when that product feature exists.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after successful kernel/rootfs builds that produced the dual FITs and `output/firmware/<APP>/rootfs.img`
- **THEN** bytes are written to the inactive rootfs and try-boot FIT path during transfer (not via a post-transfer full-image userdata stage), the board requests reboot without using RockUSB, and the command returns as soon as `arm-reboot` is started without waiting for SSH disconnect or for SSH to become reachable again

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the stream-to-partition full-system upgrade is performed against that registered IP over SSH without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SN=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SN` or `IP`

### Requirement: Host refuses upgrade when required bundle images are missing

Before streaming or RockUSB download, the host upgrade command SHALL verify that required artifacts exist: **`output/firmware/<APP>/rootfs.img`** (default `APP=lws_hmi`) for full-system mode, both FITs under shared `output/firmware/` when RockUSB full-system is selected (or the inactive letter’s FIT after SSH preflight), and that image sizes fit GPT slot capacities. It SHALL fail fast with a clear error if they are missing (e.g. instruct to run `make build-kernel` / `APP=<APP> make build-rootfs`).

#### Scenario: Missing boot.img

- **WHEN** the host runs full-system `make upgrade`, preflight selects inactive letter A, and `boot.img` is absent from the expected firmware output path
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `output/firmware/<APP>/rootfs.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device and MUST mention `build-rootfs`

### Requirement: Host reports apply failure without claiming success

If preflight refuses the slot state, a stream is truncated/fails, or arming fails, the host command SHALL exit non-zero and MUST NOT report a successful letter switch. Try-boot MUST NOT be armed after a failed or incomplete stream.

#### Scenario: Board rejects bad package

- **WHEN** the host stream fails mid-transfer or the board refuses unsafe slot state before write
- **THEN** `make upgrade` exits non-zero, try-boot is not armed, and the board remains on its previous active letter

### Requirement: Documentation contrasts upgrade vs flash

Host/docs SHALL state that:

- **SSH** `make upgrade` **streams** boot + rootfs (and optional oem when packaged) into the inactive letter;
- **RockUSB** `make upgrade` (Loader/Maskrom) partition-downloads the **OTA-equivalent** image set (`boot`, `boot_b`, both rootfs letters, optional oem) and does **not** rewrite U-Boot / MiniLoader storage / GPT / misc;
- **`make flash`** remains required for GPT changes, U-Boot/MiniLoader, misc/factory packaging via `factory.img`;
- **online / product OTA** (when present) uses download-to-`/userdata/ota/` then staged signed apply, which is distinct from both `make upgrade` transports.

#### Scenario: Help or README mentions kernel in upgrade

- **WHEN** a developer reads Makefile `help` or README Make-commands for `upgrade`
- **THEN** the text indicates full-system upgrade includes the kernel FIT(s), describes SSH stream and RockUSB Loader/Maskrom OTA-image modes, and is not the online OTA staged path nor `make flash` factory `uf`

### Requirement: make upgrade presents a single operator wait for stream write

`make upgrade` SHALL present transfer/write progress for the streamed payload such that the operator experiences **one primary wait** ending at reboot request — not a completed full-image upload to userdata followed by a long silent partition `dd`.

#### Scenario: Progress covers partition write

- **WHEN** the operator runs `make upgrade` and watches the console
- **THEN** progress advances while rootfs/FIT bytes are written to the inactive devices, and the command does not idle for a separate post-upload full-image apply phase of comparable duration

### Requirement: make upgrade streams OEM when available

After resolving `FACTORY_SKU` / `OEM_ID` (same resolver as `build-oem`), `make upgrade` SHALL update `oem.img` into the device `oem` partition when the resolved image exists, unless the operator explicitly disables OEM update via environment variable `OEM_IMG` set empty (e.g. `OEM_IMG= make upgrade`). OEM upgrade controls SHALL be environment variables (`OEM_IMG`, `OEM_ONLY`), loadable from repo-root `.env` via `WITH_DOTENV`, with command-line env overriding `.env`. When `OEM_ONLY=1`, the command SHALL update only `oem.img` (requiring it to exist), SHALL NOT write boot/rootfs, and on the **SSH** path SHALL plain-reboot without arming an A/B letter switch. When the resolved oem image is missing and `OEM_ONLY` is not `1`, full-system boot/rootfs upgrade MAY still proceed with a clear warning that OEM was skipped. The **SSH stream** path MUST NOT use `factory.img` / `upgrade_tool uf` for OEM or OS updates. The **RockUSB** path MAY use `upgrade_tool` partition download for oem/OS images as specified elsewhere in this capability, and still MUST NOT `uf factory.img` for this command.

#### Scenario: Default upgrade writes oem

- **WHEN** `oem/out/<oem_id>/oem.img` exists for the resolved sku and the operator runs `make upgrade` without disabling OEM
- **THEN** the host updates that oem image to `PARTLABEL=oem` (SSH stream or RockUSB download per selected transport) in addition to boot/rootfs when not `OEM_ONLY`

#### Scenario: OEM-only upgrade

- **WHEN** the operator runs `OEM_ONLY=1 make upgrade` (or has `OEM_ONLY=1` in `.env`) after `make build-oem`
- **THEN** the host updates only `oem.img` to oem and, on SSH transport, requests a plain reboot without changing the A/B active letter

#### Scenario: Missing oem warns but upgrades OS

- **WHEN** resolved `oem.img` is absent, `OEM_ONLY` is not `1`, and the operator runs `make upgrade`
- **THEN** the command MAY complete boot/rootfs upgrade after warning that OEM was not updated
