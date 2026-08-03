## ADDED Requirements

### Requirement: cyber_ota package provides unified OTA orchestration APIs

The repository SHALL provide a Dart path package `packages/cyber_ota` (not part of `cyber_hal`) that exposes orchestration for whole-device firmware updates: fetch or accept an OTA manifest, compare versions against the running device, transfer images into `/userdata/ota/` (when the ingress is network download), verify each partition image with its detached Ed25519 signature, apply verified images to the inactive A/B letter (and optional oem), and emit progress events for transfer and write phases. Product Apps SHALL depend on this package via pubspec `path` for Settings, cloud commands, and host-upload completion handling.

#### Scenario: Package is importable by the HMI app

- **WHEN** a developer adds `cyber_ota` as a path dependency of `app/lws_hmi`
- **THEN** the app can import the package’s public OTA session/progress APIs without pulling OTA logic into `cyber_hal`

#### Scenario: Version compare reports update availability

- **WHEN** `cyber_ota` compares a fetched manifest version to the device’s current OS/HMI version and the manifest is newer
- **THEN** the API reports that an update is available without writing any partition

### Requirement: Ingress adapters share one apply pipeline after images are staged

`cyber_ota` SHALL support multiple ingress sources (at least: network download, host upload already staged under `/userdata/ota/`, and local/testing staging) such that after required `*.img` and `*.img.sig` files are present under `/userdata/ota/`, the subsequent verify → write → arm try-boot steps are identical regardless of ingress.

#### Scenario: Host-staged bundle uses same verify-apply path as cloud download

- **WHEN** a host has uploaded signed `rootfs.img`, the inactive letter’s FIT, matching `*.sig` files, and an optional `oem.img` under `/userdata/ota/`, and an apply session starts with host-upload ingress
- **THEN** verification and partition writes follow the same rules as a session that downloaded those files over the network

#### Scenario: Missing signature refuses apply for every ingress

- **WHEN** any image required for the session lacks a valid `*.img.sig` that verifies against the device pubkey
- **THEN** `cyber_ota` refuses to write partitions and reports failure via progress/error, for both cloud and host-upload ingress

### Requirement: Progress callbacks cover transfer and write phases

`cyber_ota` SHALL emit progress events that distinguish at least: checking/manifest, transferring (download or awaiting host upload completion), verifying signatures, writing partitions (burn), arming try-boot, and terminal success-reboot-requested or failure. Write-phase progress SHALL be suitable for the dedicated in-app upgrade page (bytes or percent per image / overall). Transfer-phase progress SHALL be suitable for that page or for correlating with host upload completion.

#### Scenario: Write progress updates during apply

- **WHEN** verified images are being written to inactive partitions
- **THEN** subscribers receive monotonic write progress until arming or failure

#### Scenario: Failed verify emits failure without write progress claiming success

- **WHEN** signature verification fails
- **THEN** the session ends in a failed state and MUST NOT emit a successful write/arm completion
