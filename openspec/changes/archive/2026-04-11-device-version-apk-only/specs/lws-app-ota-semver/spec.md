## ADDED Requirements

### Requirement: OTA success does not persist manifest version into Room as systemVersion

After a successful `lws-app` OTA pipeline, the client SHALL NOT write the manifest `version` string (including any normalized “core” form) into Room `DeviceInfo.systemVersion` because that field is removed as redundant with the installed APK. The installed app release SHALL remain observable only via APK metadata (`PackageManager` / `BuildConfig`) as defined by the `device-app-version-single-source` capability.

#### Scenario: Post-OTA DeviceInfo row has no systemVersion

- **WHEN** OTA completes successfully and `DeviceInfo` is saved to Room
- **THEN** the persisted row MUST NOT include a `systemVersion` column or field

#### Scenario: OTA semver gate unchanged

- **WHEN** the client decides whether to download the OTA payload
- **THEN** it SHALL still compare manifest `version` to the local installed app `versionName` (or equivalent) using the project’s SemVer library as in existing OTA requirements
