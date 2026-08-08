## ADDED Requirements

### Requirement: make publish-app uploads signed tar.gz under lws-hmi/app

The repository SHALL provide **`make publish-app`** (and optional **`publish-app-only`**) that ensures a signed app `tar.gz` + `.sig` exist for the selected `APP`, then uploads them and **`release.json`** to R2 under **`{artifact}/app/`** (default `APP=lws_hmi` → **`lws-hmi/app/`**). Auth, API base, and presigned PUT SHALL match **`make publish`** / peripheral firmware publish. Publish SHALL be release-only (always `release.json`; reject `RELEASE=`).

Manifest fields SHALL be `version`, `filename`, `published_at`, `url` (public URL of the `tar.gz`). **`version` SHALL be `v{semver}`** from the Flutter app pubspec (semver before `+build`). Integrity SHALL rely on sibling `.sig` (`url + ".sig"`); manifest MUST NOT require `sha512`.

#### Scenario: Default publish writes app release.json

- **WHEN** the operator runs `make publish-app` with signing and a publish token, and app pubspec semver is `1.0.42`
- **THEN** the host uploads the archive and `.sig` under `lws-hmi/app/`
- **AND** PUTs `lws-hmi/app/release.json` with `version` `v1.0.42` and `url` pointing at the uploaded `tar.gz`

#### Scenario: Missing token refuses publish-app

- **WHEN** no publish token is available after dotenv load
- **THEN** the command exits non-zero before uploading

### Requirement: App package matches build-app install tree

The published/upgraded app `tar.gz` SHALL contain the same installable payload that `make build-app` stages for `/opt/hmi` (Flutter `libapp.so` / assets, optional `bin/` / `lib/` companions, `runtime-mode.json` as applicable). Packaging MUST fail closed if required primary artifacts are missing.

#### Scenario: Package includes libapp and assets

- **WHEN** `make build-app` has produced a complete HMI overlay tree and the operator packages for publish or `upgrade-app`
- **THEN** the `tar.gz` includes the app binary and flutter_assets required for `hmi.service` to start
