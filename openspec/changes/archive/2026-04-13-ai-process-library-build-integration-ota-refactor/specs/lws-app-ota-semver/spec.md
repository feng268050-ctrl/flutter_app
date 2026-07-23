## ADDED Requirements

### Requirement: OTA manifest is fetched from lws-app view

The App OTA client SHALL fetch its version descriptor from `https://api-prod.lasercyber.workers.dev/view/lws-app/<json_file>`, where `<json_file>` is `staging.json` or `release.json` under the **same** Makefile/environment selection rules as bundled library builds (default staging for test builds).

#### Scenario: Descriptor fetch uses configured channel

- **WHEN** the OTA check runs for a build configured for production descriptors
- **THEN** the client SHALL request `release.json` from the `lws-app` view path

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
