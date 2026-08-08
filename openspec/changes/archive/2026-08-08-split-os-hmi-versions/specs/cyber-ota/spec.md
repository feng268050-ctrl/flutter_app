## MODIFIED Requirements

### Requirement: cyber_ota package provides unified OTA orchestration APIs

The repository SHALL provide a Dart path package `packages/cyber_ota` (not part of `cyber_hal`) that exposes orchestration for whole-device firmware updates: fetch or accept an OTA manifest (including **host-published channel manifests** per the cloud channel manifest requirement), compare versions against the running **OS Version**, transfer an **OTA `tar.gz`** (and detached `.sig` when required) into `/userdata/ota/`, **Ed25519-verify** the archive for cloud and host HTTP ingresses via subprocess `openssl`, extract via subprocess `tar`, apply to the inactive A/B letter (and optional oem) via subprocess `dd` with Dart-owned A/B slot safety, and emit progress events on a Stream. Cloud WebSocket progress MUST subscribe to that Stream (not a progress file). Debug detail MAY append to `/userdata/ota/ota.log`. Product Apps SHALL depend on this package via pubspec `path`. The package MUST NOT rely on `ab-upgrade-apply.sh` / `ab-upgrade-stream.sh` / `ab-ota-verify.sh` (those scripts MUST be absent from rootfs). Board retainers: `ab-preflight.sh` (host slot check), `ab-slot-lib.sh`, `ab-boot-confirm.sh`. Independent HMI app OTA is **out of scope** for this package’s partition-write path (see `hmi-app-cloud-ota`).

#### Scenario: Package is importable by the HMI app

- **WHEN** a developer adds `cyber_ota` as a path dependency of `app/lws_hmi`
- **THEN** the app can import the package’s public OTA session/progress APIs without pulling OTA logic into `cyber_hal`

#### Scenario: Version compare reports update availability against OS Version

- **WHEN** `cyber_ota` compares a fetched channel manifest version to the device’s current **OS Version** and the manifest is newer
- **THEN** the API reports that an update is available without writing any partition

#### Scenario: checkForUpdate consumes published channel JSON

- **WHEN** `checkForUpdate` fetches a channel document that uses `url` (not `package_url`) and the remote version is newer than OS Version
- **THEN** the result reports `has_update` true with a usable package URL for subsequent cloud download
