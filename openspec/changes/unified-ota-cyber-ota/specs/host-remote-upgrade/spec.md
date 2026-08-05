## MODIFIED Requirements

### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that selects a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SN=` / `IP=`), **first ensures an OTA `tar.gz` via `make ota-package`** (unless an alternate package input is documented elsewhere), uploads that **archive** into **`/userdata/ota/`** over SSH, triggers the **on-device staged extract-and-apply** pipeline shared with product OTA **except that host upgrade MUST NOT require Ed25519 verification**, and returns successfully as soon as board reboot-after-arm is requested. It SHALL NOT wait for SSH disconnect, post-reboot SSH, or claim that boot health was verified.

For the upload path, the host SHALL: obtain the `tar.gz`; preflight the active/inactive letter and refuse unsafe slot state; trigger the on-device HMI to enter the dedicated upgrade page **before or at the start of** package transfer; upload the OTA package built for inactive letter FIT + **`rootfs.img`** (and optional oem when packaged); show upload progress on the host console; then let on-device apply extract and burn **without** requiring a `.sig`. Default full-system mode MUST update the inactive **boot and rootfs** letter pair.

**`make upgrade` MUST** stage the OTA package under `/userdata/ota/` (unlike the retired stream-to-partition default). **`make upgrade` MUST NOT** enter RockUSB loader mode or invoke Rockchip `upgrade_tool uf` / `flash-usb.sh` upgrade for the SSH path. **`make upgrade` MUST NOT** require uploading or verifying an Ed25519 `.sig` on device.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs via staged apply

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after packaging
- **THEN** a `tar.gz` is uploaded under `/userdata/ota/`, on-device extract-and-apply writes the inactive rootfs and try-boot FIT path without requiring signature verification, the board requests reboot without using RockUSB, and the command returns as soon as reboot-after-arm is started

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the packaged upload + staged apply full-system upgrade is performed against that registered IP over SSH without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SN=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SN` or `IP`

### Requirement: make upgrade depends on ota-package

`make upgrade` SHALL automatically invoke **`make ota-package`** (as a Make prerequisite or equivalent first step) before transferring anything to the device when no alternate package path is set. Future **`make publish`** SHALL require the same `ota-package` artifact (and its `.sig` for cloud). The package SHALL be one compressed `tar.gz` to reduce transfer size relative to shipping loose images.

#### Scenario: upgrade runs packaging first

- **WHEN** the operator runs `make upgrade` and required images exist
- **THEN** an OTA `tar.gz` is produced (or refreshed) via `ota-package` before SSH upload begins

#### Scenario: publish prerequisite is the same package

- **WHEN** a developer reads Make/docs for future cloud publish
- **THEN** `make ota-package` (output `tar.gz` + `.sig` for publish) is documented as the required prerequisite artifact for `make publish`

### Requirement: Host refuses upgrade when required bundle images are missing

Before packaging/uploading, the host upgrade command SHALL verify that required **image** artifacts exist for the inactive letter: **`output/firmware/<APP>/rootfs.img`** (default `APP=lws_hmi`), the inactive letter’s FIT under shared `output/firmware/`, and that image sizes fit GPT slot capacities. After packaging, it SHALL require the documented **`tar.gz`**. It MUST NOT require a `.sig` for `make upgrade`. It SHALL fail fast if images or the archive are missing.

#### Scenario: Missing boot.img

- **WHEN** the host runs full-system `make upgrade`, preflight selects inactive letter A, and `boot.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `output/firmware/<APP>/rootfs.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot and MUST mention `build-rootfs`

#### Scenario: Missing signature does not block make upgrade

- **WHEN** packaging produced a `tar.gz` but no `.sig` is present
- **THEN** `make upgrade` MAY proceed to upload and apply without treating the missing signature as a hard failure

### Requirement: Host reports apply failure without claiming success

If preflight refuses the slot state, packaging fails, upload fails, write/arm fails, or the trigger cannot start apply, the host command SHALL exit non-zero and MUST NOT report a successful letter switch. Try-boot MUST NOT be armed after a failed or incomplete apply.

#### Scenario: Board rejects unsafe slot state

- **WHEN** on-device apply refuses unsafe slot state
- **THEN** `make upgrade` exits non-zero, try-boot is not armed, and the board remains on its previous active letter

### Requirement: Documentation contrasts upgrade vs flash

Host/docs SHALL state that full-system `make upgrade` **packages and uploads an OTA `tar.gz`** over SSH into `/userdata/ota/` and runs staged extract-and-apply **without Ed25519** (developer path), while **online/cloud OTA** uses the same staging shape **with** Ed25519 verify, and **`make flash`** remains required for GPT / U-Boot / MiniLoader / factory reset. Device UI transfer progress is download progress for both host upload and cloud download.

#### Scenario: Help or README mentions unified staged upgrade

- **WHEN** a developer reads Makefile `help` or README Make-commands for `upgrade`
- **THEN** the text indicates full-system upgrade runs `ota-package`, uploads a `tar.gz`, uses staged apply shared with OTA shape, does not require device signature verify, and is not an unsigned stream-to-partition path

### Requirement: make upgrade presents transfer progress unified with device download UX

`make upgrade` SHALL present **upload** progress on the host console. Concurrently, the on-device HMI SHALL already be on the **dedicated upgrade page** and SHALL map those transfer bytes into **download/transferring** progress; after the package arrives, the same page drives extract/burn (**skipping verify**). The host MAY echo apply progress if a status file is available.

#### Scenario: Progress covers upload on host and download on device

- **WHEN** the operator runs `make upgrade` and watches the console and the device UI
- **THEN** host progress advances while the OTA package is uploaded
- **AND** the device upgrade page shows the corresponding download/transfer progress

#### Scenario: Safe upgrade page during and after upload

- **WHEN** package upload is in progress or has completed and apply continues on device
- **THEN** the device HMI is on the dedicated upgrade page and shows burn progress for the write phase after extract
- **AND** laser/work sessions are not left running across the apply

### Requirement: make upgrade streams OEM when available

After resolving `FACTORY_SKU` / `OEM_ID` (same resolver as `build-oem`), `make ota-package` / `make upgrade` SHALL include `oem.img` in the OTA `tar.gz` and staged apply to the device `oem` partition when the resolved image exists, unless the operator explicitly disables OEM update via `OEM_IMG` set empty. OEM controls SHALL be environment variables (`OEM_IMG`, `OEM_ONLY`), loadable from `.env` via `WITH_DOTENV`, with command-line overriding `.env`. When `OEM_ONLY=1`, the package/command SHALL include/apply only `oem.img`, SHALL NOT write boot/rootfs, and SHALL plain-reboot without arming an A/B letter switch. When the resolved oem image is missing and `OEM_ONLY` is not `1`, full-system boot/rootfs upgrade MAY still proceed with a clear warning that OEM was skipped. `make upgrade` MUST NOT use `factory.img` / RockUSB for the A/B staged SSH path.

#### Scenario: Default upgrade writes oem

- **WHEN** `oem/out/<oem_id>/oem.img` exists for the resolved sku and the operator runs `make upgrade` without disabling OEM
- **THEN** the OTA package includes that oem image and apply writes `PARTLABEL=oem` in addition to inactive boot/rootfs

#### Scenario: OEM-only upgrade

- **WHEN** the operator runs `OEM_ONLY=1 make upgrade` after `make build-oem`
- **THEN** the host packages/uploads/applies only `oem.img` to `PARTLABEL=oem` and requests a plain reboot without changing the A/B active letter

#### Scenario: Missing oem warns but upgrades OS

- **WHEN** resolved `oem.img` is absent, `OEM_ONLY` is not `1`, and the operator runs `make upgrade`
- **THEN** the command MAY complete boot/rootfs upgrade after warning that OEM was not updated
