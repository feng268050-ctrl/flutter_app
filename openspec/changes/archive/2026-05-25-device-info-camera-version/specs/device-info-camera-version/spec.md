## ADDED Requirements

### Requirement: Device Information shows camera app version

The client SHALL display a **Camera Version** row as the **last** version field on Settings **Device Information** (after all existing version rows such as wire feeder version). The displayed value SHALL be the `appVersion` string from the camera HTTP API `GET /System/deviceinfo` on port 9000, using the configured camera host (`CameraConfig.getCameraHost` / `baseCameraAppUrl`).

#### Scenario: Camera reachable with valid appVersion

- **WHEN** the user opens Settings **Device Information**
- **AND** `GET http://{cameraHost}:9000/System/deviceinfo` succeeds with HTTP 2xx
- **AND** the JSON body contains non-empty `appVersion`
- **THEN** the **Camera Version** row SHALL show that `appVersion` string

#### Scenario: Camera unreachable or request fails

- **WHEN** the user opens Settings **Device Information**
- **AND** the deviceinfo request fails (network error, timeout, non-2xx, or no response)
- **THEN** the **Camera Version** row SHALL show exactly `-`

#### Scenario: Response missing appVersion

- **WHEN** the user opens Settings **Device Information**
- **AND** the deviceinfo request returns 2xx but `appVersion` is null, empty, or absent
- **THEN** the **Camera Version** row SHALL show exactly `-`

### Requirement: Camera version is not persisted in Room

The client SHALL NOT add a `t_device_info` column or persist camera `appVersion` in Room `DeviceInfo`. Camera version SHALL be fetched at runtime for display on the Device Information screen only.

#### Scenario: No Room migration for camera version

- **WHEN** this capability is implemented
- **THEN** `DeviceInfo` entity and `t_device_info` schema SHALL remain unchanged with respect to camera software version

### Requirement: Camera host follows configuration

The deviceinfo URL host SHALL be resolved via the same camera host configuration used for other camera HTTP/RTSP features (`CameraConfig.getCameraHost`), not a hardcoded default IP alone when a user override exists.

#### Scenario: Custom camera host pref

- **WHEN** the operator has set a non-default camera host in app preferences
- **AND** that host responds on port 9000
- **THEN** the client SHALL request deviceinfo from that host
