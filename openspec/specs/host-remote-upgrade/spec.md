# host-remote-upgrade Specification

## Purpose
Developer SSH full-system A/B upgrade (`make upgrade`): stream firmware into inactive partitions over USB-SSH / LAN SSH without RockUSB.

## Requirements
### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that selects a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SN=` / `IP=`), performs a **stream-to-partition** full-system upgrade over SSH, and returns successfully as soon as board `arm-reboot` is started (reboot requested). It SHALL NOT wait for SSH disconnect, post-reboot SSH, or claim that boot health was verified.

For the stream path, the host SHALL: preflight the active/inactive letter and refuse unsafe slot state; stream **`rootfs.img`** into the inactive `rootfs_*` partition while transferring; stream **only the inactive letter’s FIT** (`boot.img` for letter A, `boot_b.img` for letter B) into the try-boot FIT path on `boot` after the running FIT is backed up to `boot_b`; optionally stream **oem** when packaged; then arm try-boot and reboot. Default full-system mode MUST update the inactive **boot and rootfs** letter pair (kernel + rootfs).

**`make upgrade` MUST NOT** stage full firmware images under `/userdata/ota/` before writing (status/logs/tiny helpers may use that directory). **`make upgrade` MUST NOT** enter RockUSB loader mode or invoke Rockchip `upgrade_tool uf` / `flash-usb.sh` upgrade. Online / product OTA download-then-write is out of scope for this command and SHALL use the separate staged apply path.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after successful kernel/rootfs builds that produced the dual FITs and `rootfs.img`
- **THEN** bytes are written to the inactive rootfs and try-boot FIT path during transfer (not via a post-transfer full-image userdata stage), the board requests reboot without using RockUSB, and the command returns as soon as `arm-reboot` is started without waiting for SSH disconnect or for SSH to become reachable again

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the stream-to-partition full-system upgrade is performed against that registered IP over SSH without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SN=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SN` or `IP`

### Requirement: Host refuses upgrade when required bundle images are missing

Before streaming, the host upgrade command SHALL verify that required artifacts exist for the inactive letter: **`rootfs.img`**, the inactive letter’s FIT (`boot.img` and/or `boot_b.img` as needed after preflight), and that image sizes fit GPT slot capacities. It SHALL fail fast with a clear error if they are missing (e.g. instruct to run `make build-kernel` / `make build-rootfs`).

#### Scenario: Missing boot.img

- **WHEN** the host runs full-system `make upgrade`, preflight selects inactive letter A, and `boot.img` is absent from the expected firmware output path
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `rootfs.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

### Requirement: Host reports apply failure without claiming success

If preflight refuses the slot state, a stream is truncated/fails, or arming fails, the host command SHALL exit non-zero and MUST NOT report a successful letter switch. Try-boot MUST NOT be armed after a failed or incomplete stream.

#### Scenario: Board rejects bad package

- **WHEN** the host stream fails mid-transfer or the board refuses unsafe slot state before write
- **THEN** `make upgrade` exits non-zero, try-boot is not armed, and the board remains on its previous active letter

### Requirement: Documentation contrasts upgrade vs flash

Host/docs SHALL state that full-system `make upgrade` **streams** **boot + rootfs** (and optional oem when packaged) over SSH into the inactive letter, while **`make flash`** remains required for GPT changes, U-Boot/MiniLoader, and factory reset. Docs SHALL also state that **online OTA** uses **download-to-`/userdata/ota/` then staged apply**, which is distinct from `make upgrade` stream-to-partition.

#### Scenario: Help or README mentions kernel in upgrade

- **WHEN** a developer reads Makefile `help` or README Make-commands for `upgrade`
- **THEN** the text indicates full-system upgrade includes the kernel FIT, streams to partitions during transfer, and is not the online OTA staged path

### Requirement: make upgrade presents a single operator wait for stream write

`make upgrade` SHALL present transfer/write progress for the streamed payload such that the operator experiences **one primary wait** ending at reboot request — not a completed full-image upload to userdata followed by a long silent partition `dd`.

#### Scenario: Progress covers partition write

- **WHEN** the operator runs `make upgrade` and watches the console
- **THEN** progress advances while rootfs/FIT bytes are written to the inactive devices, and the command does not idle for a separate post-upload full-image apply phase of comparable duration

### Requirement: make upgrade streams OEM when available

After resolving `FACTORY_SKU` / `OEM_ID` (same resolver as `build-oem`), `make upgrade` SHALL stream `oem.img` into the device `oem` partition when the resolved image exists, unless the operator explicitly disables OEM update via documented env (e.g. empty `OEM_IMG=`). When `OEM_ONLY=1`, the command SHALL stream only `oem.img` (requiring it to exist), SHALL NOT write boot/rootfs, and SHALL plain-reboot without arming an A/B letter switch. When the resolved oem image is missing and `OEM_ONLY` is not set, full-system boot/rootfs upgrade MAY still proceed with a clear warning that OEM was skipped. `make upgrade` MUST NOT use `factory.img` / RockUSB for the A/B stream path.

#### Scenario: Default upgrade writes oem

- **WHEN** `oem/out/<oem_id>/oem.img` exists for the resolved sku and the operator runs `make upgrade` without disabling OEM
- **THEN** the host streams that oem image to `PARTLABEL=oem` in addition to inactive boot/rootfs

#### Scenario: OEM-only upgrade

- **WHEN** the operator runs `make upgrade OEM_ONLY=1` after `make build-oem`
- **THEN** the host streams only `oem.img` to `PARTLABEL=oem` and requests a plain reboot without changing the A/B active letter

#### Scenario: Missing oem warns but upgrades OS

- **WHEN** resolved `oem.img` is absent, `OEM_ONLY` is not `1`, and the operator runs `make upgrade`
- **THEN** the command MAY complete boot/rootfs upgrade after warning that OEM was not updated
