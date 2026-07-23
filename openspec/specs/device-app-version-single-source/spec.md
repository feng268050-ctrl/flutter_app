## Purpose

Define a single source of truth for the **installed Android application release**: runtime APK metadata (`PackageManager` / `BuildConfig`), without persisting a duplicate app-version column in Room.

## Requirements

### Requirement: Installed app version is read from the APK only

The client SHALL determine the **installed application release** for user-visible surfaces and for local semver comparison against OTA manifest `version` using **only** Android-installed metadata: `PackageManager.getPackageInfo(packageName, …).versionName` and/or `BuildConfig.VERSION_NAME` for the same build. The client MUST NOT require a Room-persisted `systemVersion` to represent the installed app release.

#### Scenario: Device Information shows one app version

- **WHEN** the user opens Settings **Device Information**
- **THEN** the client SHALL show exactly **one** row for the installed app release sourced from APK metadata (labeled per product copy, e.g. system version)
- **AND** the client SHALL NOT show a separate **UI Version** row for the same value

### Requirement: Room DeviceInfo schema drops systemVersion

The `DeviceInfo` entity backing `t_device_info` SHALL NOT define or persist `systemVersion` after migration.

#### Scenario: Fresh install database

- **WHEN** the app is installed on a device with no prior database
- **THEN** the created `t_device_info` table SHALL NOT contain a `systemVersion` column

### Requirement: Room does not persist app UI version

The `t_device_info` table SHALL NOT include a persisted `uiVersion` column. Any in-memory `DeviceInfo.uiVersion` field used for MQTT or JSON payloads SHALL be populated from the installed APK (`PackageManager.getPackageInfo(...).versionName` with `BuildConfig.VERSION_NAME` as fallback), not from Room reads.

#### Scenario: MQTT payload carries installed app version

- **WHEN** the client builds a `DeviceInfoVo` (or equivalent) for MQTT upload
- **THEN** the embedded `DeviceInfo` SHALL include `uiVersion` set from installed APK metadata
- **AND** that value SHALL NOT depend on a Room column for `uiVersion`
