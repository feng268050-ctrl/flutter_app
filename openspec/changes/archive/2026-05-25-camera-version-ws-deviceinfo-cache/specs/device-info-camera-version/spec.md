## MODIFIED Requirements

### Requirement: Device Information shows camera app version

The client SHALL display a **Camera Version** row as the **last** version field on Settings **Device Information** (after all existing version rows such as wire feeder version). The displayed value SHALL be read from the unified in-memory camera version cache (`camera-version-deviceinfo-cache`), which is populated from `GET /System/deviceinfo` `appVersion` on the configured camera host. The client MAY trigger a cache refresh when the screen is shown or resumed. The displayed string SHALL use the same normalization as remote `deviceInfo.cameraVersion` (strip leading `v`/`V`, remove ` build…` suffix). When the cache holds no successful value, the row SHALL show exactly `-`.

#### Scenario: Camera reachable with valid appVersion

- **WHEN** the user opens Settings **Device Information**
- **AND** the unified cache has been populated with normalized version `1.0.5` from a successful deviceinfo fetch
- **THEN** the **Camera Version** row SHALL show `1.0.5`

#### Scenario: Camera unreachable or request fails

- **WHEN** the user opens Settings **Device Information**
- **AND** the unified cache holds `-` because deviceinfo fetch failed or has not completed
- **THEN** the **Camera Version** row SHALL show exactly `-`

#### Scenario: Response missing appVersion

- **WHEN** deviceinfo returns 2xx but `appVersion` is null, empty, or absent
- **THEN** the unified cache SHALL store `-`
- **AND** the **Camera Version** row SHALL show exactly `-`

### Requirement: Camera version is not persisted in Room

The client SHALL NOT add a `t_device_info` column or persist camera `appVersion` in Room `DeviceInfo`. Camera version SHALL be held in the unified in-memory cache and copied onto transient `DeviceInfo` fields only when building UI or remote snapshots.

#### Scenario: No Room migration for camera version

- **WHEN** this capability is implemented
- **THEN** `DeviceInfo` entity and `t_device_info` schema SHALL remain unchanged with respect to camera software version columns
