## MODIFIED Requirements

### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that selects a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SN=` / `IP=`), **first ensures an OTA zip via `make ota-package`**, uploads that **single zip** (containing the required **Ed25519-signed** firmware images and matching `*.img.sig`, plus orchestration manifest) into **`/userdata/ota/`** over SSH, triggers the **same** on-device staged extract-verify-and-apply pipeline used by product/cloud OTA, and returns successfully as soon as board reboot-after-arm is requested. It SHALL NOT wait for SSH disconnect, post-reboot SSH, or claim that boot health was verified.

For the upload path, the host SHALL: run **`make ota-package`** (or equivalent Make dependency) so the zip exists and matches the selected slot set; preflight the active/inactive letter and refuse unsafe slot state; trigger the on-device HMI to enter the dedicated upgrade page **before or at the start of** zip transfer so upload bytes can be shown as download/transfer progress; upload the OTA zip built for inactive letter FIT + **`rootfs.img`** from `output/firmware/<APP>/` (default `APP=lws_hmi`) and optional oem when packaged; show upload progress on the host console; then let on-device apply (HMI/`cyber_ota` or board helper) extract, verify, and burn. Default full-system mode MUST update the inactive **boot and rootfs** letter pair (kernel + rootfs).

**`make upgrade` MUST** stage the OTA zip under `/userdata/ota/` (unlike the retired stream-to-partition default). **`make upgrade` MUST NOT** enter RockUSB loader mode or invoke Rockchip `upgrade_tool uf` / `flash-usb.sh` upgrade. **`make upgrade` MUST NOT** skip Ed25519 verification on the device for full-system images.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs via staged apply

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after successful signed kernel/rootfs builds
- **THEN** `make ota-package` produces a zip, that zip is uploaded under `/userdata/ota/`, on-device extract-verify-and-apply writes the inactive rootfs and try-boot FIT path, the board requests reboot without using RockUSB, and the command returns as soon as reboot-after-arm is started without waiting for SSH disconnect or for SSH to become reachable again

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the packaged zip upload + staged apply full-system upgrade is performed against that registered IP over SSH without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SN=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SN` or `IP`

### Requirement: make upgrade depends on ota-package

`make upgrade` SHALL automatically invoke **`make ota-package`** (as a Make prerequisite or equivalent first step) before transferring anything to the device. Future **`make publish`** SHALL be documented and designed to require the same `ota-package` artifact as its prerequisite (publish implementation MAY land later). The package SHALL contain the signed images required for the selected upgrade mode in one compressed archive to reduce storage and transfer size relative to shipping loose images.

#### Scenario: upgrade runs packaging first

- **WHEN** the operator runs `make upgrade` and required signed images exist
- **THEN** an OTA zip is produced (or refreshed) via `ota-package` before SSH upload begins

#### Scenario: publish prerequisite is the same package

- **WHEN** a developer reads Make/docs for future cloud publish
- **THEN** `make ota-package` (or its output zip) is documented as the required prerequisite artifact for `make publish`

### Requirement: Host refuses upgrade when required bundle images are missing

Before packaging/uploading, the host upgrade command SHALL verify that required **signed** artifacts exist for the inactive letter: **`output/firmware/<APP>/rootfs.img`** and **`rootfs.img.sig`** (default `APP=lws_hmi`), the inactive letter’s FIT and its `.sig` under shared `output/firmware/`, and that image sizes fit GPT slot capacities. It SHALL fail fast with a clear error if images or signatures are missing (e.g. instruct to run `make build-kernel` / `APP=<APP> make build-rootfs`), and MUST NOT upload a partial or unsigned package.

#### Scenario: Missing boot.img

- **WHEN** the host runs full-system `make upgrade`, preflight selects inactive letter A, and `boot.img` is absent from the expected firmware output path
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `output/firmware/<APP>/rootfs.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device and MUST mention `build-rootfs`

#### Scenario: Missing signature refuses package and upload apply

- **WHEN** a required `.img` exists but its sibling `.img.sig` is missing
- **THEN** `make ota-package` / `make upgrade` exits non-zero before relying on an unsigned apply

### Requirement: Host reports apply failure without claiming success

If preflight refuses the slot state, packaging fails, upload fails, on-device verification fails, write/arm fails, or the trigger cannot start apply, the host command SHALL exit non-zero and MUST NOT report a successful letter switch. Try-boot MUST NOT be armed after a failed or incomplete apply.

#### Scenario: Board rejects bad package

- **WHEN** on-device Ed25519 verification fails or apply refuses unsafe slot state
- **THEN** `make upgrade` exits non-zero, try-boot is not armed, and the board remains on its previous active letter

### Requirement: Documentation contrasts upgrade vs flash

Host/docs SHALL state that full-system `make upgrade` **packages and uploads a signed OTA zip** (boot + rootfs, and optional oem when packaged) over SSH into `/userdata/ota/` and runs the **same Ed25519-verified staged apply** as online OTA, while **`make flash`** remains required for GPT changes, U-Boot/MiniLoader, and factory reset. Docs SHALL state that online OTA differs only by downloading the zip instead of host upload, and that device UI transfer progress is download progress for both.

#### Scenario: Help or README mentions unified staged upgrade

- **WHEN** a developer reads Makefile `help` or README Make-commands for `upgrade`
- **THEN** the text indicates full-system upgrade runs `ota-package`, uploads a signed zip, uses staged verified apply shared with OTA, and is not an unsigned stream-to-partition path

### Requirement: make upgrade presents transfer progress unified with device download UX

`make upgrade` SHALL present **upload** progress on the host console for bytes transferred to `/userdata/ota/` such that the operator can see transfer completion. Concurrently, the on-device HMI SHALL already be on the **dedicated upgrade page** and SHALL map those transfer bytes into **download/transferring** progress via `cyber_ota` callbacks; after the zip arrives, the same page drives extract/verify/burn. The host MAY additionally echo apply progress if a status file is available. The operator MUST NOT be left believing a silent post-upload apply with no progress channel exists.

#### Scenario: Progress covers upload on host and download on device

- **WHEN** the operator runs `make upgrade` and watches the console and the device UI
- **THEN** host progress advances while the OTA zip is uploaded
- **AND** the device upgrade page shows the corresponding download/transfer progress

#### Scenario: Safe upgrade page during and after upload

- **WHEN** zip upload is in progress or has completed and apply continues on device
- **THEN** the device HMI is on the dedicated upgrade page (after safe shutdown from any work screen) and shows burn progress for the write phase after verify
- **AND** laser/work sessions are not left running across the apply

### Requirement: make upgrade streams OEM when available

After resolving `FACTORY_SKU` / `OEM_ID` (same resolver as `build-oem`), `make ota-package` / `make upgrade` SHALL include signed `oem.img` (+ `.sig`) in the OTA zip and staged apply to the device `oem` partition when the resolved image exists, unless the operator explicitly disables OEM update via environment variable `OEM_IMG` set empty (e.g. `OEM_IMG= make upgrade`). OEM upgrade controls SHALL be environment variables (`OEM_IMG`, `OEM_ONLY`), loadable from repo-root `.env` via `WITH_DOTENV`, with command-line env overriding `.env`. When `OEM_ONLY=1`, the package/command SHALL include/apply only `oem.img` (requiring image + signature), SHALL NOT write boot/rootfs, and SHALL plain-reboot without arming an A/B letter switch. When the resolved oem image is missing and `OEM_ONLY` is not `1`, full-system boot/rootfs upgrade MAY still proceed with a clear warning that OEM was skipped. `make upgrade` MUST NOT use `factory.img` / RockUSB for the A/B staged path.

#### Scenario: Default upgrade writes oem

- **WHEN** `oem/out/<oem_id>/oem.img` and `oem.img.sig` exist for the resolved sku and the operator runs `make upgrade` without disabling OEM
- **THEN** the OTA package includes that oem image and apply writes `PARTLABEL=oem` in addition to inactive boot/rootfs

#### Scenario: OEM-only upgrade

- **WHEN** the operator runs `OEM_ONLY=1 make upgrade` (or has `OEM_ONLY=1` in `.env`) after `make build-oem`
- **THEN** the host packages/uploads/applies only signed `oem.img` to `PARTLABEL=oem` and requests a plain reboot without changing the A/B active letter

#### Scenario: Missing oem warns but upgrades OS

- **WHEN** resolved `oem.img` is absent, `OEM_ONLY` is not `1`, and the operator runs `make upgrade`
- **THEN** the command MAY complete boot/rootfs upgrade after warning that OEM was not updated
