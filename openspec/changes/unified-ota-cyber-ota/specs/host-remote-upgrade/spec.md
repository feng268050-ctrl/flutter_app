## MODIFIED Requirements

### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that selects a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SN=` / `IP=`), uploads the required **Ed25519-signed** firmware images (and matching `*.img.sig`) into **`/userdata/ota/`** over SSH, triggers the **same** on-device staged verify-and-apply pipeline used by product/cloud OTA, and returns successfully as soon as board reboot-after-arm is requested. It SHALL NOT wait for SSH disconnect, post-reboot SSH, or claim that boot health was verified.

For the upload path, the host SHALL: preflight the active/inactive letter and refuse unsafe slot state; upload **`rootfs.img`** (+ `.sig`) from `output/firmware/<APP>/rootfs.img` (default `APP=lws_hmi`); upload **only the inactive letter’s FIT** (`boot.img` or `boot_b.img`) and its `.sig` from shared `output/firmware/`; optionally upload **oem** (+ `.sig`) when packaged; show **upload progress** to the operator; then trigger on-device apply (HMI/`cyber_ota` or board helper) so burn progress is available to the device UI. Default full-system mode MUST update the inactive **boot and rootfs** letter pair (kernel + rootfs).

**`make upgrade` MUST** stage the firmware images used for apply under `/userdata/ota/` (unlike the retired stream-to-partition default). **`make upgrade` MUST NOT** enter RockUSB loader mode or invoke Rockchip `upgrade_tool uf` / `flash-usb.sh` upgrade. **`make upgrade` MUST NOT** skip Ed25519 verification on the device for full-system images.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs via staged apply

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after successful signed kernel/rootfs builds
- **THEN** signed images are uploaded under `/userdata/ota/`, on-device verify-and-apply writes the inactive rootfs and try-boot FIT path, the board requests reboot without using RockUSB, and the command returns as soon as reboot-after-arm is started without waiting for SSH disconnect or for SSH to become reachable again

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the signed upload + staged apply full-system upgrade is performed against that registered IP over SSH without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SN=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SN` or `IP`

### Requirement: Host refuses upgrade when required bundle images are missing

Before uploading, the host upgrade command SHALL verify that required **signed** artifacts exist for the inactive letter: **`output/firmware/<APP>/rootfs.img`** and **`rootfs.img.sig`** (default `APP=lws_hmi`), the inactive letter’s FIT and its `.sig` under shared `output/firmware/`, and that image sizes fit GPT slot capacities. It SHALL fail fast with a clear error if images or signatures are missing (e.g. instruct to run `make build-kernel` / `APP=<APP> make build-rootfs`).

#### Scenario: Missing boot.img

- **WHEN** the host runs full-system `make upgrade`, preflight selects inactive letter A, and `boot.img` is absent from the expected firmware output path
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `output/firmware/<APP>/rootfs.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device and MUST mention `build-rootfs`

#### Scenario: Missing signature refuses upload apply

- **WHEN** a required `.img` exists but its sibling `.img.sig` is missing
- **THEN** `make upgrade` exits non-zero before relying on an unsigned apply

### Requirement: Host reports apply failure without claiming success

If preflight refuses the slot state, upload fails, on-device verification fails, write/arm fails, or the trigger cannot start apply, the host command SHALL exit non-zero and MUST NOT report a successful letter switch. Try-boot MUST NOT be armed after a failed or incomplete apply.

#### Scenario: Board rejects bad package

- **WHEN** on-device Ed25519 verification fails or apply refuses unsafe slot state
- **THEN** `make upgrade` exits non-zero, try-boot is not armed, and the board remains on its previous active letter

### Requirement: Documentation contrasts upgrade vs flash

Host/docs SHALL state that full-system `make upgrade` **uploads signed boot + rootfs** (and optional oem when packaged) over SSH into `/userdata/ota/` and runs the **same Ed25519-verified staged apply** as online OTA, while **`make flash`** remains required for GPT changes, U-Boot/MiniLoader, and factory reset. Docs SHALL state that online OTA differs only by downloading images instead of host upload.

#### Scenario: Help or README mentions unified staged upgrade

- **WHEN** a developer reads Makefile `help` or README Make-commands for `upgrade`
- **THEN** the text indicates full-system upgrade uploads signed images, uses staged verified apply shared with OTA, and is not an unsigned stream-to-partition path

### Requirement: make upgrade presents upload progress then device burn UX

`make upgrade` SHALL present **upload** progress for bytes transferred to `/userdata/ota/` such that the operator can see transfer completion. After upload completes, the on-device HMI SHALL perform safe shutdown to Home, open the **dedicated upgrade page**, and drive burn/write progress via `cyber_ota` callbacks; the host MAY additionally echo apply progress if a status file is available. The operator MUST NOT be left believing a silent post-upload apply with no progress channel exists.

#### Scenario: Progress covers upload

- **WHEN** the operator runs `make upgrade` and watches the console
- **THEN** progress advances while firmware image bytes are uploaded to the device staging directory

#### Scenario: Safe upgrade page after upload

- **WHEN** upload of the required signed bundle completes and apply is triggered on device
- **THEN** the device HMI returns to Home if needed, opens the dedicated upgrade page, and shows burn progress for the write phase
- **AND** laser/work sessions are not left running across the apply

### Requirement: make upgrade streams OEM when available

After resolving `FACTORY_SKU` / `OEM_ID` (same resolver as `build-oem`), `make upgrade` SHALL upload signed `oem.img` (+ `.sig`) into `/userdata/ota/` and include it in staged apply to the device `oem` partition when the resolved image exists, unless the operator explicitly disables OEM update via environment variable `OEM_IMG` set empty (e.g. `OEM_IMG= make upgrade`). OEM upgrade controls SHALL be environment variables (`OEM_IMG`, `OEM_ONLY`), loadable from repo-root `.env` via `WITH_DOTENV`, with command-line env overriding `.env`. When `OEM_ONLY=1`, the command SHALL upload/apply only `oem.img` (requiring image + signature), SHALL NOT write boot/rootfs, and SHALL plain-reboot without arming an A/B letter switch. When the resolved oem image is missing and `OEM_ONLY` is not `1`, full-system boot/rootfs upgrade MAY still proceed with a clear warning that OEM was skipped. `make upgrade` MUST NOT use `factory.img` / RockUSB for the A/B staged path.

#### Scenario: Default upgrade writes oem

- **WHEN** `oem/out/<oem_id>/oem.img` and `oem.img.sig` exist for the resolved sku and the operator runs `make upgrade` without disabling OEM
- **THEN** the host uploads that oem image into the staged bundle and apply writes `PARTLABEL=oem` in addition to inactive boot/rootfs

#### Scenario: OEM-only upgrade

- **WHEN** the operator runs `OEM_ONLY=1 make upgrade` (or has `OEM_ONLY=1` in `.env`) after `make build-oem`
- **THEN** the host uploads/applies only signed `oem.img` to `PARTLABEL=oem` and requests a plain reboot without changing the A/B active letter

#### Scenario: Missing oem warns but upgrades OS

- **WHEN** resolved `oem.img` is absent, `OEM_ONLY` is not `1`, and the operator runs `make upgrade`
- **THEN** the command MAY complete boot/rootfs upgrade after warning that OEM was not updated
