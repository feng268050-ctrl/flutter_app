## ADDED Requirements

### Requirement: cyber_ota package provides unified OTA orchestration APIs

The repository SHALL provide a Dart path package `packages/cyber_ota` (not part of `cyber_hal`) that exposes orchestration for whole-device firmware updates: fetch or accept an OTA manifest, compare versions against the running device, transfer an **OTA zip package** into `/userdata/ota/` (network download or host-upload byte progress), extract the archive to obtain partition images and detached signatures, verify each partition image with its detached Ed25519 signature, apply verified images to the inactive A/B letter (and optional oem), and emit progress events for transfer, extract, and write phases. Product Apps SHALL depend on this package via pubspec `path` for Settings, cloud commands, and host-upgrade session handling.

#### Scenario: Package is importable by the HMI app

- **WHEN** a developer adds `cyber_ota` as a path dependency of `app/lws_hmi`
- **THEN** the app can import the package’s public OTA session/progress APIs without pulling OTA logic into `cyber_hal`

#### Scenario: Version compare reports update availability

- **WHEN** `cyber_ota` compares a fetched manifest version to the device’s current OS/HMI version and the manifest is newer
- **THEN** the API reports that an update is available without writing any partition

### Requirement: Ingress adapters share one apply pipeline after the package is staged

`cyber_ota` SHALL support multiple ingress sources (at least: network download of the OTA zip, host upload of the same zip under `/userdata/ota/`, and local/testing staging) such that after the archive is present and extracted so required `*.img` and `*.img.sig` files are available under `/userdata/ota/`, the subsequent verify → write → arm try-boot steps are identical regardless of ingress. Host-upload transfer progress SHALL emit the same **transferring** progress events used for cloud download (product UX treats both as download).

#### Scenario: Host-uploaded zip uses same verify-apply path as cloud download

- **WHEN** a host has uploaded an OTA zip under `/userdata/ota/`, the session extracts it to signed `rootfs.img`, the inactive letter’s FIT, matching `*.sig` files, and an optional `oem.img`, and apply continues
- **THEN** verification and partition writes follow the same rules as a session that downloaded that zip over the network

#### Scenario: Missing signature refuses apply for every ingress

- **WHEN** any image required for the session lacks a valid `*.img.sig` that verifies against the device pubkey
- **THEN** `cyber_ota` refuses to write partitions and reports failure via progress/error, for both cloud and host-upload ingress

### Requirement: Progress callbacks cover transfer, extract, and write phases

`cyber_ota` SHALL emit progress events that distinguish at least: checking/manifest, transferring (cloud download **or** host zip upload mapped to the same phase), extracting, verifying signatures, writing partitions (burn), arming try-boot, and terminal success-reboot-requested or failure. Transfer-phase progress SHALL be suitable for the dedicated in-app upgrade page as **download** progress. Write-phase progress SHALL be suitable for that page (bytes or percent per image / overall).

#### Scenario: Write progress updates during apply

- **WHEN** verified images are being written to inactive partitions
- **THEN** subscribers receive monotonic write progress until arming or failure

#### Scenario: Host upload reports transferring like download

- **WHEN** a host is uploading the OTA zip and the session is subscribed on device
- **THEN** subscribers receive transferring progress that advances with received bytes, indistinguishable in phase from a cloud download

#### Scenario: Failed verify emits failure without write progress claiming success

- **WHEN** signature verification fails
- **THEN** the session ends in a failed state and MUST NOT emit a successful write/arm completion
