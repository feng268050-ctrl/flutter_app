## ADDED Requirements

### Requirement: cyber_ota package provides unified OTA orchestration APIs

The repository SHALL provide a Dart path package `packages/cyber_ota` (not part of `cyber_hal`) that exposes orchestration for whole-device firmware updates: fetch or accept an OTA manifest, compare versions, transfer an **OTA `tar.gz`** (and detached `.sig` when required) into `/userdata/ota/`, **Ed25519-verify** the archive for cloud and host HTTP ingresses via subprocess `openssl`, extract via subprocess `tar`, apply to the inactive A/B letter (and optional oem) via subprocess `dd` with Dart-owned A/B slot safety, and emit progress events on a Stream. Cloud WebSocket progress MUST subscribe to that Stream (not a progress file). Debug detail MAY append to `/userdata/ota/ota.log`. Product Apps SHALL depend on this package via pubspec `path`. The package MUST NOT rely on `ab-upgrade-apply.sh` / `ab-upgrade-stream.sh` / `ab-ota-verify.sh` (those scripts MUST be absent from rootfs). Board retainers: `ab-preflight.sh` (host slot check), `ab-slot-lib.sh`, `ab-boot-confirm.sh`.

#### Scenario: Package is importable by the HMI app

- **WHEN** a developer adds `cyber_ota` as a path dependency of `app/lws_hmi`
- **THEN** the app can import the package’s public OTA session/progress APIs without pulling OTA logic into `cyber_hal`

#### Scenario: Version compare reports update availability

- **WHEN** `cyber_ota` compares a fetched manifest version to the device’s current OS/HMI version and the manifest is newer
- **THEN** the API reports that an update is available without writing any partition

### Requirement: Ingress adapters share verify-extract-apply for cloud and host HTTP

`cyber_ota` SHALL support at least: network download of the OTA `tar.gz` and `.sig` (**CloudIngress**), host HTTP pull of the `tar.gz` and `.sig` from the ephemeral host server used by `make upgrade` (**HostHttpIngress**), and local/testing staging. After the archive and signature are present, **CloudIngress and HostHttpIngress MUST** Ed25519-verify the complete archive before extract-and-apply. Subsequent extract → write → arm try-boot steps are shared. Host HTTP transfer progress SHALL emit the same **transferring** events used for cloud download.

#### Scenario: Host HTTP-pulled package requires signature verify

- **WHEN** HostHttpIngress has downloaded an OTA `tar.gz` and `.sig` under `/userdata/ota/`
- **THEN** the session MUST Ed25519-verify using the sibling `.sig` before extract-and-apply
- **AND** MUST refuse to write partitions if the `.sig` is missing or verification fails

#### Scenario: Cloud missing or bad signature refuses apply

- **WHEN** CloudIngress lacks a valid detached `.sig` that verifies against the device pubkey
- **THEN** `cyber_ota` refuses to write partitions and reports failure

### Requirement: Progress callbacks cover transfer, verify, extract, and write

`cyber_ota` SHALL emit progress events that distinguish at least: checking/manifest, transferring, **verifying**, extracting, writing, arming try-boot, and terminal success/failure. Cloud and host HTTP sessions MUST include a successful verifying phase before extract/write. Transfer-phase progress SHALL map to upgrade-page **download** UX for both ingresses.

Extract progress SHALL advance with **compressed archive bytes** consumed while feeding `tar -xz` on stdin (same chunked model as host `stream-file-progress.py`).

Write progress SHALL be **per image** (each of rootfs / kernel FIT / oem reports its own 0–100% from that image’s bytes). Full-system write order SHALL be: inactive rootfs → backup `boot`→`boot_b` (UI remains `writing kernel` at 0%) → try FIT to `boot` (`writing kernel` with byte progress) → optional oem (`writing oem`) → arm. Progress MUST NOT use elapsed-time estimates. Block-device writes SHALL chunk-read the image file and pipe to a single `dd of=<device>` (MUST NOT open `/dev` via Dart `RandomAccessFile`).

#### Scenario: Write progress updates during apply

- **WHEN** images are being written to inactive partitions via Dart chunked file→`dd` stdin copy (byte progress like host `stream-file-progress.py`)
- **THEN** subscribers receive per-image write progress (percent may restart at 0 when the next image begins) until arming or failure
- **AND** there is no `progress.json` dependency for UI or cloud WS

#### Scenario: Extract progress updates while unpacking

- **WHEN** the OTA `tar.gz` is extracted under `/userdata/ota/`
- **THEN** subscribers receive `extracting` progress that advances with archive bytes fed to `tar`

#### Scenario: Host HTTP pull reports transferring like download

- **WHEN** the device is downloading the OTA `tar.gz` from the host HTTP server and the session is subscribed
- **THEN** subscribers receive transferring progress that advances with received bytes

#### Scenario: Failed verify emits failure without write success

- **WHEN** package signature verification fails (cloud or host HTTP)
- **THEN** the session ends failed and MUST NOT emit successful write/arm completion
