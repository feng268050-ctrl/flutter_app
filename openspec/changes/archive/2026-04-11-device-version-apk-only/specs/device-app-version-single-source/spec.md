## ADDED Requirements

### Requirement: Installed app version is read from the APK only

The client SHALL determine the **installed application release** for user-visible surfaces and for local semver comparison against OTA manifest `version` using **only** Android-installed metadata: `PackageManager.getPackageInfo(packageName, …).versionName` and/or `BuildConfig.VERSION_NAME` for the same build. The client MUST NOT require a Room-persisted `systemVersion` (or equivalent duplicate) to represent the installed app release.

#### Scenario: Device Information shows one app version

- **WHEN** the user opens Settings **Device Information**
- **THEN** the client SHALL show exactly **one** row for the installed app release sourced from APK metadata
- **AND** the client SHALL NOT show a separate **UI Version** row for the same value

#### Scenario: No Room column for installed app duplicate

- **WHEN** persisting `DeviceInfo` to Room after this change ships
- **THEN** the `t_device_info` schema SHALL NOT include a `systemVersion` column used to store the installed APK release

### Requirement: Room DeviceInfo schema drops systemVersion

The `DeviceInfo` entity backing `t_device_info` SHALL NOT define or persist `systemVersion` after migration. Existing migrations SHALL advance the database from prior schemas that included `systemVersion` without leaving orphan accessors in application code.

#### Scenario: Fresh install database

- **WHEN** the app is installed on a device with no prior database
- **THEN** the created `t_device_info` table SHALL NOT contain a `systemVersion` column

### Requirement: Room does not persist app UI version

The `t_device_info` table SHALL NOT include a persisted `uiVersion` column. MQTT / `DeviceInfoVo` payloads SHALL set in-memory `DeviceInfo.uiVersion` from installed APK metadata (`PackageManager` / `BuildConfig`), not from Room.

#### Scenario: MQTT payload carries installed app version

- **WHEN** the client builds `DeviceInfoVo` for MQTT upload
- **THEN** the embedded `DeviceInfo` SHALL include `uiVersion` from installed APK metadata
- **AND** that value SHALL NOT be read from a Room `uiVersion` column
