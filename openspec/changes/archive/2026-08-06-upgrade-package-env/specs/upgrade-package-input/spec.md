## ADDED Requirements

### Requirement: UPGRADE_PACKAGE selects a prebuilt OTA tarball for make upgrade

`make upgrade` SHALL accept an optional environment variable **`UPGRADE_PACKAGE`** (loadable from repo-root `.env` via the same dotenv pattern as other Make targets, with a non-empty command-line value overriding `.env`). When **`UPGRADE_PACKAGE`** is set to a non-empty path, the host SHALL use that archive as the firmware input for the selected transport instead of requiring a freshly built default package from the current tree outputs for that invocation. The path MUST resolve to a readable regular file. Unsupported or unreadable paths MUST fail fast before any device write.

Accepted archive types SHALL include uncompressed **`.tar`** and gzip-compressed **`.tar.gz`** / **`.tgz`**. Other formats (including `.zip`) MUST be rejected with a clear error unless explicitly documented later.

#### Scenario: Missing file fails fast

- **WHEN** the operator runs `UPGRADE_PACKAGE=/no/such/file.tar.gz make upgrade`
- **THEN** the command exits non-zero before writing partitions or entering RockUSB download

#### Scenario: Unsupported format fails fast

- **WHEN** the operator sets `UPGRADE_PACKAGE` to a `.zip` (or other non-tar) file and runs `make upgrade`
- **THEN** the command exits non-zero with guidance that only `.tar` / `.tar.gz` / `.tgz` are supported

### Requirement: SSH transport serves the package and sibling .sig for device HTTP download

When **`UPGRADE_PACKAGE`** is set and `make upgrade` selects a **USB-SSH or registered SSH** Linux target, the host SHALL resolve a detached signature at the **default sibling path** **`<UPGRADE_PACKAGE>.sig`** (same directory, archive filename + `.sig`). The host SHALL fail fast if that `.sig` is missing or unreadable. The host SHALL serve the archive **and** the `.sig` via an ephemeral HTTP server and trigger the device to **download** into **`/userdata/ota/`** then run **staged OTA verify-extract-apply**. The host MUST NOT RockUSB-`di` in this mode. The host SHOULD present **HTTP send** progress on the console until transfer complete; device UI transfer progress follows the unified host HTTP download mapping when that HMI path is present.

#### Scenario: USB-SSH upgrades from tarball with sibling sig

- **WHEN** exactly one USB-SSH device is available and the operator runs `UPGRADE_PACKAGE=/path/to/pkg.tar.gz make upgrade` with `/path/to/pkg.tar.gz.sig` present
- **THEN** the archive and `.sig` are served for device download into `/userdata/ota/` and on-device staged verify-apply runs without using RockUSB `di`

#### Scenario: Missing sibling sig fails on SSH

- **WHEN** `UPGRADE_PACKAGE=/path/to/pkg.tar.gz` is set, SSH transport is selected, and `/path/to/pkg.tar.gz.sig` is absent
- **THEN** the command exits non-zero before a successful verify-apply write

#### Scenario: Registered SSH upgrades from tarball

- **WHEN** a board is reachable via registered SSH and the operator runs `IP=<ip> UPGRADE_PACKAGE=/path/to/pkg.tar make upgrade` with `/path/to/pkg.tar.sig` present
- **THEN** the archive and `.sig` are served and device-side download + staged verify-apply is used against that IP

### Requirement: RockUSB transport extracts then di OTA images

When **`UPGRADE_PACKAGE`** is set and `make upgrade` selects **RockUSB Loader or Maskrom**, the host SHALL extract the archive on the host and flash the extracted OTA-equivalent loose images with the existing RockUSB **`upgrade-ota` / `di`** path (both FITs + rootfs to both letters when full-system; oem rules unchanged). The host MUST NOT `uf` `factory.img` for this path. If required members for RockUSB full-system upgrade are missing from the archive (e.g. `boot.img`, `boot_b.img`, `rootfs.img`), the command MUST fail fast before `di`.

#### Scenario: Loader upgrades from extracted tarball

- **WHEN** the board is in RockUSB Loader, `UPGRADE_PACKAGE` points at a `tar.gz` containing the required OTA images, and RockUSB transport is selected
- **THEN** the host extracts the archive and partition-downloads those images without `uf` of `factory.img`

#### Scenario: Incomplete archive for RockUSB fails

- **WHEN** RockUSB transport is selected with `UPGRADE_PACKAGE` set and the archive lacks a required `boot_b.img` (or other required member for full-system `di`)
- **THEN** the command exits non-zero without writing partitions

### Requirement: Docs describe UPGRADE_PACKAGE

Makefile `help` and host upgrade docs SHALL document **`UPGRADE_PACKAGE=`**, accepted archive suffixes, and the SSH host-HTTP + device-pull vs RockUSB-extract behavior split.

#### Scenario: Help mentions UPGRADE_PACKAGE

- **WHEN** a developer runs `make help` or reads README Make-commands for `upgrade`
- **THEN** `UPGRADE_PACKAGE` and the two transport behaviors are described
