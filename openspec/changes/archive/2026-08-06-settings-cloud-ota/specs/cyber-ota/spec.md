## ADDED Requirements

### Requirement: Cloud channel manifest accepts publish url field

`cyber_ota` SHALL parse whole-device **cloud channel** manifests as used by `make publish` / `host-ota-publish`: a JSON object with at least `version` (string) and an archive location. The archive location SHALL be taken from **`package_url`** when that field is a non-empty string; otherwise from **`url`** when that field is a non-empty string. Missing both SHALL be a parse error. Optional `sig_url` (or equivalent) SHALL select the detached signature URL; when absent, the resolved signature URL SHALL default to the archive URL with `.sig` appended. The package MUST NOT require `sha512` in the channel manifest. Channel `url` / `package_url` alone MUST NOT authorize partition writes; CloudIngress MUST still Ed25519-verify using the detached `.sig` before extract-and-apply.

#### Scenario: Published staging.json with url parses

- **WHEN** `OtaManifest.fromJson` receives `{"version":"v1.0.41-beta","filename":"v1.0.41-beta.tar.gz","published_at":"…Z","url":"https://cdn.example/lws-hmi/v1.0.41-beta.tar.gz"}` with no `package_url`
- **THEN** the manifest’s package URL equals that `url` value
- **AND** the resolved signature URL equals that `url` with `.sig` appended

#### Scenario: package_url still accepted

- **WHEN** `OtaManifest.fromJson` receives a non-empty `package_url` (with or without `url`)
- **THEN** the package URL is taken from `package_url`

#### Scenario: Neither url nor package_url fails

- **WHEN** the JSON has `version` but neither `url` nor `package_url` is a non-empty string
- **THEN** parsing fails without starting a download or partition write

## MODIFIED Requirements

### Requirement: cyber_ota package provides unified OTA orchestration APIs

The repository SHALL provide a Dart path package `packages/cyber_ota` (not part of `cyber_hal`) that exposes orchestration for whole-device firmware updates: fetch or accept an OTA manifest (including **host-published channel manifests** per the cloud channel manifest requirement), compare versions against the running HMI app version, transfer an **OTA `tar.gz`** (and detached `.sig` when required) into `/userdata/ota/`, **Ed25519-verify** the archive for cloud and host HTTP ingresses via subprocess `openssl`, extract via subprocess `tar`, apply to the inactive A/B letter (and optional oem) via subprocess `dd` with Dart-owned A/B slot safety, and emit progress events on a Stream. Cloud WebSocket progress MUST subscribe to that Stream (not a progress file). Debug detail MAY append to `/userdata/ota/ota.log`. Product Apps SHALL depend on this package via pubspec `path`. The package MUST NOT rely on `ab-upgrade-apply.sh` / `ab-upgrade-stream.sh` / `ab-ota-verify.sh` (those scripts MUST be absent from rootfs). Board retainers: `ab-preflight.sh` (host slot check), `ab-slot-lib.sh`, `ab-boot-confirm.sh`.

#### Scenario: Package is importable by the HMI app

- **WHEN** a developer adds `cyber_ota` as a path dependency of `app/lws_hmi`
- **THEN** the app can import the package’s public OTA session/progress APIs without pulling OTA logic into `cyber_hal`

#### Scenario: Version compare reports update availability

- **WHEN** `cyber_ota` compares a fetched channel manifest version to the device’s current HMI app version and the manifest is newer
- **THEN** the API reports that an update is available without writing any partition

#### Scenario: checkForUpdate consumes published channel JSON

- **WHEN** `checkForUpdate` fetches a channel document that uses `url` (not `package_url`) and the remote version is newer
- **THEN** the result reports `has_update` true with a usable package URL for subsequent cloud download
