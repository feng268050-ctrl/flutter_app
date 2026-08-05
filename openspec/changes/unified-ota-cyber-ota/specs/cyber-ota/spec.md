## ADDED Requirements

### Requirement: cyber_ota package provides unified OTA orchestration APIs

The repository SHALL provide a Dart path package `packages/cyber_ota` (not part of `cyber_hal`) that exposes orchestration for whole-device firmware updates: fetch or accept an OTA manifest, compare versions, transfer an **OTA `tar.gz`** into `/userdata/ota/`, optionally **verify** the archive (cloud only), extract partition images, apply to the inactive A/B letter (and optional oem), and emit progress events. Product Apps SHALL depend on this package via pubspec `path`.

#### Scenario: Package is importable by the HMI app

- **WHEN** a developer adds `cyber_ota` as a path dependency of `app/lws_hmi`
- **THEN** the app can import the package’s public OTA session/progress APIs without pulling OTA logic into `cyber_hal`

#### Scenario: Version compare reports update availability

- **WHEN** `cyber_ota` compares a fetched manifest version to the device’s current OS/HMI version and the manifest is newer
- **THEN** the API reports that an update is available without writing any partition

### Requirement: Ingress adapters share extract-apply; verify only on cloud

`cyber_ota` SHALL support at least: network download of the OTA `tar.gz` and `.sig` (**CloudIngress**), host upload of the `tar.gz` under `/userdata/ota/` (**HostUploadIngress**), and local/testing staging. After the archive is present, **CloudIngress MUST** Ed25519-verify the complete archive before extract-and-apply. **HostUploadIngress MUST NOT** require signature verification. Subsequent extract → write → arm try-boot steps (aside from verify) are shared. Host-upload transfer progress SHALL emit the same **transferring** events used for cloud download.

#### Scenario: Host-uploaded package skips signature verify

- **WHEN** a host has uploaded an OTA `tar.gz` under `/userdata/ota/` without a `.sig`
- **THEN** the session extracts and applies without failing for missing Ed25519 verification

#### Scenario: Cloud missing or bad signature refuses apply

- **WHEN** CloudIngress lacks a valid detached `.sig` that verifies against the device pubkey
- **THEN** `cyber_ota` refuses to write partitions and reports failure

### Requirement: Progress callbacks cover transfer, optional verify, extract, and write

`cyber_ota` SHALL emit progress events that distinguish at least: checking/manifest, transferring, **verifying** (cloud only), extracting, writing, arming try-boot, and terminal success/failure. Host-upload sessions MUST NOT require a successful verifying phase. Transfer-phase progress SHALL map to upgrade-page **download** UX for both ingresses.

#### Scenario: Write progress updates during apply

- **WHEN** images are being written to inactive partitions
- **THEN** subscribers receive monotonic write progress until arming or failure

#### Scenario: Host upload reports transferring like download

- **WHEN** a host is uploading the OTA `tar.gz` and the session is subscribed on device
- **THEN** subscribers receive transferring progress that advances with received bytes

#### Scenario: Failed cloud verify emits failure without write success

- **WHEN** cloud package signature verification fails
- **THEN** the session ends failed and MUST NOT emit successful write/arm completion
