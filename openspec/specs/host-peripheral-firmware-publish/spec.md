# host-peripheral-firmware-publish Specification

## Purpose

Host `make publish-control-board-firmware` / `publish-camera-firmware`: sign and upload peripheral release blobs + `release.json` under `{artifact}/control-board/` and `{artifact}/camera/` via the same R2 presign path as system `make publish`.

## Requirements

### Requirement: make publish-control-board-firmware uploads release channel to R2

The repository SHALL provide **`make publish-control-board-firmware`** that selects the newest (or `FIRMWARE_BIN=` overridden) control-board `.bin` under `app/lws_hmi/assets/firmware/control-board/` (or the selected HMI app’s equivalent path when documented), ensures a detached Ed25519 `.sig` exists via the same OTA signing tooling, and uploads the `.bin`, `.sig`, and channel manifest to R2 under **`{artifact}/control-board/`** where `{artifact}` is derived from `APP` (default `lws_hmi` → `lws-hmi`).

The channel manifest file SHALL always be **`release.json`** (release-only; no `staging.json` / `-beta` for this target). Manifest fields SHALL match the system OTA channel shape: `version`, `filename`, `published_at`, `url` (public URL of the `.bin`). For control-board, **`version` SHALL be the bare software integer** from `LSW01H####S####.bin` with **no `v` prefix** (e.g. `LSW01H1000S1017.bin` → `1017`); **`filename`** remains the full basename for HW/SW parse. Integrity SHALL rely on the sibling `.sig` (device resolves `url + ".sig"`); the manifest MUST NOT require `sha512`.

Authentication and API base SHALL match **`make publish`**: `cloud_api_base()`, token order `PUBLISH_API_TOKEN` / `CLOUD_ACCESS_TOKEN` / login credentials, presigned PUT via `/v1/storage/r2/presigned-url`.

An optional **`make publish-control-board-firmware-only`** (or documented equivalent) MAY upload an already-signed local pair without re-selecting sources, and MUST fail if the `.bin` or `.sig` is missing.

#### Scenario: Default publish writes control-board release.json

- **WHEN** the operator runs `make publish-control-board-firmware` with signing and a publish token configured and the selected file is `LSW01H1000S1017.bin`
- **THEN** the host SHALL upload the selected `.bin` and `.sig` under `lws-hmi/control-board/`
- **AND** SHALL PUT `lws-hmi/control-board/release.json` with `filename` `LSW01H1000S1017.bin`, `version` `1017` (no `v` prefix), and `url` pointing at the uploaded `.bin`

#### Scenario: Missing token refuses control-board publish

- **WHEN** no publish token is available after dotenv load
- **THEN** the command SHALL exit non-zero before uploading

### Requirement: make publish-camera-firmware uploads release channel to R2

The repository SHALL provide **`make publish-camera-firmware`** that selects the newest (or `FIRMWARE_ZIP=` overridden) camera firmware ZIP under the App camera firmware source tree, ensures a detached Ed25519 `.sig`, and uploads ZIP + `.sig` + **`release.json`** under **`{artifact}/camera/`** (default `lws-hmi/camera/`).

Publish SHALL be release-only (always `release.json`). Manifest shape and auth/API base SHALL match `make publish-control-board-firmware` / system `make publish`. Filename and typed version parse rules SHALL remain compatible with bundled camera ZIP naming (`{MODEL}-v{SEMVER} build{YYYYMMDD}.zip`). Channel **`version` SHALL be `v{SEMVER}` only** (e.g. `v1.0.7`); the build date remains in **`filename`** only.

#### Scenario: Default publish writes camera release.json

- **WHEN** the operator runs `make publish-camera-firmware` with signing and a publish token configured and the selected file is `LTC609-v1.0.7 build20260513.zip`
- **THEN** the host SHALL upload the selected ZIP and `.sig` under `lws-hmi/camera/`
- **AND** SHALL PUT `lws-hmi/camera/release.json` with `filename` `LTC609-v1.0.7 build20260513.zip`, `version` `v1.0.7`, and `url` pointing at the uploaded ZIP

#### Scenario: Camera publish is never staging

- **WHEN** the operator runs `make publish-camera-firmware` without any release flag
- **THEN** the written manifest key SHALL be `{artifact}/camera/release.json`
- **AND** MUST NOT write `staging.json` for that prefix
