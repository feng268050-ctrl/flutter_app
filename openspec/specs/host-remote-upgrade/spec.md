# host-remote-upgrade Specification

## Purpose
Developer full-system A/B upgrade (`make upgrade`): SSH host-HTTP + device staged Ed25519 verify-apply when Linux is up, or RockUSB Loader/Maskrom `di` of OTA-equivalent loose images — not `factory.img` / unsigned product cloud OTA.

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

### Requirement: make upgrade dispatches SSH staged OTA vs RockUSB by device mode

`make upgrade` SHALL use the **SSH host-HTTP + device staged verify-apply** path when a deployable Linux USB-SSH or registered SSH target is selected. When no such SSH target is selected but a RockUSB Loader/Maskrom device is, it SHALL use the RockUSB OTA-images `di` path. When neither is available, it MUST fail with guidance to use `make devices`, SSH connectivity, `make reboot-loader`, or Maskrom. An optional env override (e.g. `UPGRADE_TRANSPORT=ssh|rockusb`) MAY force one transport; default is auto. Multi-device selection (`SN=` / `IP=`) SHALL apply to RockUSB as it does for `make flash`.

#### Scenario: SSH board uses staged host HTTP pull

- **WHEN** exactly one USB-SSH Linux board is available and no RockUSB force is set
- **THEN** `make upgrade` serves `tar.gz`+`.sig` over host HTTP for device download/verify-apply and does not RockUSB-download partitions

#### Scenario: Only RockUSB present

- **WHEN** no deployable SSH Linux target is available, one RockUSB Loader/Maskrom device is present, and required images exist
- **THEN** `make upgrade` uses the RockUSB OTA-images path

#### Scenario: No target

- **WHEN** neither SSH nor RockUSB targets are available
- **THEN** `make upgrade` exits non-zero with operator guidance

### Requirement: make upgrade performs remote full-system firmware upgrade over SSH

The repository SHALL provide **`make upgrade`** that selects a Linux target the same way as **`make push-app`** (**USB-SSH** and/or registered **`MODE=SSH`** via `SN=` / `IP=`), **first ensures an OTA `tar.gz` and sibling `.sig` via `make ota-package`** (unless an alternate package input is documented elsewhere), starts an **ephemeral host HTTP server** that serves the archive and `.sig`, triggers the on-device HMI to **HTTP download** those files into **`/userdata/ota/`**, runs the **staged verify-extract-apply** pipeline shared with product OTA (**MUST** Ed25519-verify before write), and returns successfully as soon as board reboot-after-arm is requested. It SHALL NOT wait for SSH disconnect, post-reboot SSH, or claim that boot health was verified.

For the SSH path, the host SHALL: obtain the `tar.gz` and `.sig`; preflight the active/inactive letter and refuse unsafe slot state; bind HTTP on an address the device can reach (USB-SSH default `192.168.55.2`, LAN: local source IP toward the board, overridable via `OTA_HTTP_HOST=` / `OTA_HTTP_PORT=`); trigger the on-device HMI to enter the dedicated upgrade page and download; report **HTTP send** progress on the host console until archive + `.sig` are fully served (`TRANSFER_COMPLETE`); then exit successfully without waiting for on-device apply. On-device **`cyber_ota`** SHALL verify, extract, and burn via Dart-orchestrated `openssl`/`tar`/`dd`. Default full-system mode MUST update the inactive **boot and rootfs** letter pair. SSH SHALL be used as a **control plane** (trigger + transfer complete), not as the bulk transfer path for the OTA archive.

**`make upgrade` MUST** stage the OTA package under `/userdata/ota/` (unlike the retired stream-to-partition default). **`make upgrade` MUST NOT** enter RockUSB loader mode or invoke Rockchip `upgrade_tool uf` / `flash-usb.sh` upgrade for the SSH path. For USB-SSH/SSH, **`make upgrade` MUST** require device verification of the Ed25519 `.sig`.

#### Scenario: Upgrade over USB-SSH updates kernel and rootfs via staged apply with verify

- **WHEN** exactly one USB-SSH device is available and the host runs `make upgrade` after packaging with a signature
- **THEN** the device HTTP-downloads `tar.gz` and `.sig` from the host into `/userdata/ota/`, on-device verify-extract-apply writes the inactive rootfs and try-boot FIT path after successful Ed25519 verification, the board requests reboot without using RockUSB, and the command returns as soon as reboot-after-arm is started

#### Scenario: Upgrade over registered LAN SSH

- **WHEN** a board is registered with `make connect` and the user runs `IP=<ip> make upgrade`
- **THEN** the packaged host-HTTP + device-pull (archive + `.sig`) + staged verify-apply full-system upgrade is performed against that registered IP without RockUSB

#### Scenario: Multi-device requires selection

- **WHEN** more than one deployable Linux target is present and neither `SN=` nor `IP=` is set
- **THEN** `make upgrade` fails with guidance to run `make devices` and set `SN` or `IP`

### Requirement: make upgrade depends on ota-package

`make upgrade` SHALL automatically invoke **`make ota-package`** (as a Make prerequisite or equivalent first step) before serving anything to the device when no alternate package path is set. **`make publish`** SHALL require the same `ota-package` artifact (and its `.sig`). The package SHALL be one compressed `tar.gz` plus sibling `.sig` to reduce transfer size relative to shipping loose images while preserving authenticity.

#### Scenario: upgrade runs packaging first

- **WHEN** the operator runs `make upgrade` and required images exist with signing configured
- **THEN** an OTA `tar.gz` and `.sig` are produced (or refreshed) via `ota-package` before the host HTTP server starts

#### Scenario: publish prerequisite is the same package

- **WHEN** a developer reads Make/docs for cloud publish
- **THEN** `make ota-package` (output `tar.gz` + `.sig`) is documented as the required prerequisite artifact for `make publish`

### Requirement: make upgrade honors UPGRADE_PACKAGE when set

In addition to upgrading from tree-built firmware outputs (or the default `ota-package` artifact when that path is active), **`make upgrade` SHALL** honor **`UPGRADE_PACKAGE=`** as specified by the `upgrade-package-input` capability: when the variable is non-empty, use that local `.tar` / `.tar.gz` / `.tgz` as the package input, branching by transport (**SSH/USB-SSH** → host HTTP serve archive **+ sibling `.sig`** + device download + staged **verify**-apply; **RockUSB Loader/Maskrom** → host extract + `di` OTA images). When `UPGRADE_PACKAGE` is unset or empty, existing input resolution for `make upgrade` remains unchanged by this requirement.

#### Scenario: Unset keeps default inputs

- **WHEN** the operator runs `make upgrade` without `UPGRADE_PACKAGE`
- **THEN** the command uses the default firmware/package inputs for the selected transport (not an operator-supplied tarball)

#### Scenario: Set overrides default package source

- **WHEN** the operator runs `UPGRADE_PACKAGE=/path/to/pkg.tar.gz make upgrade` with a valid archive and a selected transport
- **THEN** the upgrade uses that archive per `upgrade-package-input` and does not require regenerating a package solely because tree outputs changed

### Requirement: make publish shares ota-package artifact with make upgrade

**`make publish`** SHALL use the **same** OTA `tar.gz` (and detached `.sig`) produced by **`make ota-package`** (for the selected `APP` and packaging mode) as its upload artifact. **`make publish`** MUST invoke `ota-package` (or equivalent prerequisite) before upload when using the full `publish` target. Host documentation SHALL state that cloud publish and SSH `make upgrade` share that archive shape; publish MUST NOT invent a second unsigned or differently laid-out cloud-only archive.

#### Scenario: publish prerequisite is ota-package tar.gz

- **WHEN** a developer reads Make/docs for `make publish` or runs `make publish` with packaging available
- **THEN** the uploaded archive bytes are the `ota-package` `tar.gz` (or a content-identical rename for basename rules), not a separate ad-hoc firmware layout

#### Scenario: Docs link upgrade and publish packaging

- **WHEN** a developer reads host upgrade/publish documentation
- **THEN** the text states that both `make upgrade` and `make publish` depend on `make ota-package` for the whole-device `tar.gz`

### Requirement: Host refuses upgrade when required bundle images or signature are missing

Before packaging/serving, the host upgrade command SHALL verify that required **image** artifacts exist for the inactive letter: **`output/firmware/<APP>/rootfs.img`** (default `APP=lws_hmi`), the inactive letter’s FIT under shared `output/firmware/`, and that image sizes fit GPT slot capacities. After packaging (or when resolving `UPGRADE_PACKAGE=`), for **USB-SSH/SSH** it SHALL require the documented **`tar.gz` and sibling `.sig`**. It SHALL fail fast if images, the archive, or the signature are missing on the SSH path.

#### Scenario: Missing boot.img

- **WHEN** the host runs full-system `make upgrade`, preflight selects inactive letter A, and `boot.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot on the device

#### Scenario: Missing rootfs.img

- **WHEN** the host runs full-system `make upgrade` and `output/firmware/<APP>/rootfs.img` is absent
- **THEN** the command exits non-zero without writing any boot or rootfs slot and MUST mention `build-rootfs`

#### Scenario: Missing signature blocks SSH make upgrade

- **WHEN** packaging produced a `tar.gz` but no `.sig` is present (or `UPGRADE_PACKAGE` has no sibling `.sig`) and transport is USB-SSH/SSH
- **THEN** `make upgrade` MUST exit non-zero without starting a download/apply session that skips Ed25519

### Requirement: Host reports apply failure without claiming success

If preflight refuses the slot state, packaging fails, HTTP serve/download fails, verify/write/arm fails, or the trigger cannot start apply, the host command SHALL exit non-zero and MUST NOT report a successful letter switch. Try-boot MUST NOT be armed after a failed or incomplete apply.

#### Scenario: Board rejects unsafe slot state

- **WHEN** on-device apply refuses unsafe slot state
- **THEN** `make upgrade` exits non-zero, try-boot is not armed, and the board remains on its previous active letter

### Requirement: Documentation contrasts upgrade vs flash

Host/docs SHALL state that full-system `make upgrade` over SSH **packages an OTA `tar.gz` and `.sig`**, serves them over an ephemeral host HTTP server for **device download** into `/userdata/ota/`, and runs staged **verify**-extract-apply shared with online/cloud OTA, while **RockUSB `di`** and **`make flash`** remain unsigned paths for Loader/factory. Device UI transfer progress is download progress for both host HTTP pull and cloud download; both then show verify.

#### Scenario: Help or README mentions unified staged upgrade with verify

- **WHEN** a developer reads Makefile `help` or README Make-commands for `upgrade`
- **THEN** the text indicates full-system SSH upgrade runs `ota-package`, serves a `tar.gz` and `.sig` over host HTTP for device download, uses staged verify-apply shared with OTA shape, and is not an unsigned stream-to-partition path

### Requirement: make upgrade presents transfer progress unified with device download UX

`make upgrade` SHALL present **host HTTP send** progress on the console (chunked serve of archive + `.sig`) and exit after `TRANSFER_COMPLETE`. Concurrently, the on-device HMI SHALL already be on the **dedicated upgrade page** and SHALL show **download/transferring** progress from its HTTP client; after the package arrives, the same page SHALL show **verify**, **extract** (archive-byte progress), and **burn** progress from `cyber_ota` (per-image chunked `dd` stdin callbacks on `OtaSession.progress`).

#### Scenario: Progress covers download on host console and device UI

- **WHEN** the operator runs `make upgrade` and watches the console and the device UI
- **THEN** host console reflects HTTP send progress until transfer complete
- **AND** the device upgrade page shows download/transfer progress from the HTTP pull

#### Scenario: Safe upgrade page during and after download

- **WHEN** package download is in progress or has completed and apply continues on device
- **THEN** the device HMI is on the dedicated upgrade page and shows verify then burn progress for the write phase after extract
- **AND** laser/work sessions are not left running across the apply

### Requirement: make upgrade streams OEM when available

After resolving `FACTORY_SKU` / `OEM_ID` (same resolver as `build-oem`), `make ota-package` / `make upgrade` SHALL include `oem.img` in the OTA `tar.gz` and staged apply to the device `oem` partition when the resolved image exists, unless the operator explicitly disables OEM update via `OEM_IMG` set empty. OEM controls SHALL be environment variables (`OEM_IMG`, `OEM_ONLY`), loadable from `.env` via `WITH_DOTENV`, with command-line overriding `.env`. When `OEM_ONLY=1`, the package/command SHALL include/apply only `oem.img`, SHALL NOT write boot/rootfs, and SHALL plain-reboot without arming an A/B letter switch. When the resolved oem image is missing and `OEM_ONLY` is not `1`, full-system boot/rootfs upgrade MAY still proceed with a clear warning that OEM was skipped. `make upgrade` MUST NOT use `factory.img` / RockUSB for the A/B staged SSH path.

#### Scenario: Default upgrade writes oem

- **WHEN** `oem/out/<oem_id>/oem.img` exists for the resolved sku and the operator runs `make upgrade` without disabling OEM
- **THEN** the OTA package includes that oem image and apply writes `PARTLABEL=oem` in addition to inactive boot/rootfs

#### Scenario: OEM-only upgrade

- **WHEN** the operator runs `OEM_ONLY=1 make upgrade` after `make build-oem`
- **THEN** the host packages/serves/applies only `oem.img` to `PARTLABEL=oem` (after SSH-path verify) and requests a plain reboot without changing the A/B active letter

#### Scenario: Missing oem warns but continues full-system

- **WHEN** resolved `oem.img` is absent, `OEM_ONLY` is not `1`, and the operator runs `make upgrade`
- **THEN** the command MAY proceed with boot/rootfs only and MUST warn that OEM was skipped
