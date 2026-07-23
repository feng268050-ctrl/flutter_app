## Purpose

Define how the client discovers, compares, and applies `lws-app` OTA updates (manifest fetch, SemVer gate, zip payload with APK and control-card firmware), including coexistence with APK-bundled firmware delivery.
## Requirements
### Requirement: OTA manifest is fetched from lws-app view

The App OTA client SHALL fetch its version descriptor from the **in-memory pinned Worker API base** (the same origin used for other Worker HTTPS traffic after `DeviceApiOriginProber` succeeds), by joining the path `/view/lws-app/<json_file>` under that base using the project’s standard base+path join rules (`DeviceApiOriginConfig` / `joinUnderBase` semantics). The `<json_file>` value SHALL be `staging.json` or `release.json` under the **same** Makefile/environment selection rules as bundled library builds (default staging for test builds).

The client SHALL NOT use a hardcoded `https://api-prod.lasercyber.workers.dev/...` origin for manifest fetch when a pinned base is available.

#### Scenario: Descriptor fetch uses configured channel

- **WHEN** the OTA check runs for a build configured for production descriptors
- **THEN** the client SHALL request `release.json` under the `lws-app` view path on the pinned base

#### Scenario: Descriptor fetch uses staging by default for test builds

- **WHEN** the OTA check runs for a build whose manifest file is `staging.json`
- **THEN** the client SHALL request `staging.json` under the `lws-app` view path on the pinned base

#### Scenario: Manifest URL preserves a path-prefixed pinned base

- **WHEN** the pinned API base is `http://47.86.53.176:8080/prod` (no trailing slash) and the manifest file is `staging.json`
- **THEN** the manifest request URL MUST be `http://47.86.53.176:8080/prod/view/lws-app/staging.json` (and MUST NOT be `http://47.86.53.176:8080/view/lws-app/staging.json`)

#### Scenario: No hardcoded prod Workers host when pin is absent

- **WHEN** the OTA check runs and the pinned API base is not yet set (`getPinnedBase()` is null)
- **THEN** the client MUST NOT issue the manifest request using `https://api-prod.lasercyber.workers.dev` as a silent default solely because the pin is missing

#### Scenario: Manifest on canonical Workers host without path prefix

- **WHEN** the pinned API base is `https://api-prod.lasercyber.workers.dev` and the manifest file is `release.json`
- **THEN** the manifest request URL MUST be `https://api-prod.lasercyber.workers.dev/view/lws-app/release.json`

### Requirement: OTA update decision uses semantic version ordering

The client SHALL use a **standard SemVer 2.0–compliant library** (added as a project dependency) to parse the manifest `version` string and the local App `versionName` (or equivalent), then compare using **only** that library’s ordering API (e.g. parse + compare). The implementation MUST NOT implement bespoke version ordering (string sort, manual segment integers, etc.). Optional leading `v` and prerelease segments SHALL be handled by the library per SemVer rules.

#### Scenario: v-prefixed manifest compares like unprefixed SemVer

- **WHEN** the manifest `version` is `v1.0.0` and the local version string parses as `1.0.0`
- **THEN** the library SHALL report them as the same semantic version for ordering purposes

#### Scenario: No download when already current or newer

- **WHEN** the local App version is equal to or greater than the manifest `version` under semver rules
- **THEN** the client SHALL NOT download the OTA payload

#### Scenario: Download when manifest is newer

- **WHEN** the manifest `version` is greater than the local App version
- **THEN** the client SHALL download the resource at `url`

### Requirement: OTA payload is a zip containing App apk and device firmware

The downloaded OTA artifact SHALL be a zip archive. The client SHALL extract it and locate the contained App APK and lower-device `bin` firmware using the project’s agreed inner paths (documented at implementation time). It SHALL then apply **existing** firmware update and APK installation procedures used prior to this refactor (only the source of files and version comparison semantics change).

#### Scenario: Successful OTA applies firmware and schedules apk upgrade

- **WHEN** the zip is valid and contains the expected members
- **THEN** the firmware SHALL be processed with the legacy OTA firmware path and the APK SHALL be installed or staged using the legacy APK upgrade path

### Requirement: OTA does not process AI or process libraries

The OTA client SHALL NOT download, extract, or import AI library or process-library payloads as part of the `lws-app` OTA flow; those artifacts are exclusively handled by bundled-assets startup import.

#### Scenario: OTA flow ignores library artifacts

- **WHEN** the `lws-app` OTA pipeline runs
- **THEN** it SHALL NOT invoke AI-library or process-library import routines unless triggered solely by the startup bundled-library feature

### Requirement: OTA success does not persist manifest version into Room as systemVersion

After a successful `lws-app` OTA pipeline, the client SHALL NOT write the manifest `version` string (including any normalized “core” form) into Room `DeviceInfo.systemVersion` because that field is removed as redundant with the installed APK. The installed app release SHALL remain observable only via APK metadata (`PackageManager` / `BuildConfig`) as defined by the `device-app-version-single-source` capability.

#### Scenario: Post-OTA DeviceInfo row has no systemVersion

- **WHEN** OTA completes successfully and `DeviceInfo` is saved to Room
- **THEN** the persisted row MUST NOT include a `systemVersion` column or field

#### Scenario: OTA semver gate unchanged

- **WHEN** the client decides whether to download the OTA payload
- **THEN** it SHALL still compare manifest `version` to the local installed app `versionName` (or equivalent) using the project’s SemVer library as in existing OTA requirements

### Requirement: Firmware may be delivered via bundled APK assets or OTA zip

Control-card firmware updates SHALL be deliverable through either:

1. the existing `lws-app` OTA zip download and `UpgradeActivity` extraction path, or
2. the home-screen bundled-firmware feature that reads firmware from `assets/firmware/` after user confirmation on `MainActivity`.

Both paths SHALL converge on the same legacy Modbus firmware upgrade implementation (`BinUtil` / `ControllerUpgradeHandler`). Neither path SHALL be removed by the introduction of the other.

When both an OTA session and a bundled-firmware upgrade could run concurrently, the implementation SHALL serialize controller firmware upgrade so only one Modbus OTA session is active at a time.

#### Scenario: OTA zip firmware path remains valid

- **WHEN** the user completes an online `lws-app` OTA that includes a `.bin` in the extracted zip
- **THEN** firmware SHALL still be applied through the existing OTA firmware path unchanged

#### Scenario: Bundled firmware does not disable OTA

- **WHEN** the APK contains bundled firmware assets
- **THEN** the OTA manifest check and zip download flow SHALL remain available for App and firmware updates delivered via `lws-app`

#### Scenario: Concurrent upgrade attempts are serialized

- **WHEN** bundled firmware upgrade is in progress
- **THEN** a new OTA firmware upgrade SHALL NOT start a second concurrent Modbus OTA session

### Requirement: OTA zip may include MediaMTX native artifact

The `lws-app` OTA zip payload MAY include a MediaMTX binary artifact with semver metadata. When present and newer than the installed relay binary, the client SHALL apply it per capability **`mediamtx-ota-upgrade`** without breaking unrelated OTA steps (APK, firmware, process-library, ai-library).

#### Scenario: OTA package contains mediamtx bump

- **WHEN** the OTA zip includes a MediaMTX artifact with version newer than installed
- **THEN** the OTA apply path MUST stage the binary for installation on the next safe relay boundary and MUST NOT skip APK or firmware artifacts solely due to MediaMTX handling

### Requirement: OTA manifest check supports automatic home-screen entry

In addition to the manual **Check and Install Updates** action on Device Information, the OTA client SHALL support an automatic manifest check entry point invoked from the home-screen prompt pipeline when the user has enabled **Auto check for updates**.

The automatic entry SHALL use the same pinned-base manifest URL, fetch implementation, and semver comparison requirements as the manual check.

When the automatic entry determines an update is available and the user confirms navigation, the client SHALL pass the already-fetched manifest data to `UpgradeActivity` without performing a redundant manifest request.

#### Scenario: Automatic entry uses pinned lws-app manifest URL

- **WHEN** the automatic home-screen OTA check runs with a pinned Worker API base
- **THEN** the client SHALL request the same `/view/lws-app/<json_file>` manifest as the manual OTA check

#### Scenario: Automatic entry honors semver no-download rule

- **WHEN** the automatic check compares manifest `version` to local `versionName` and local is equal or newer
- **THEN** the client SHALL NOT open `UpgradeActivity` and SHALL NOT download the OTA payload

#### Scenario: Confirmed automatic navigation reuses manifest result

- **WHEN** the automatic check found a newer manifest and the user confirms **Go to update**
- **THEN** `UpgradeActivity` SHALL receive `downloadUrl` and `version` from that check result without a second manifest GET

