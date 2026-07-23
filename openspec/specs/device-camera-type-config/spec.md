# device-camera-type-config Specification

## Purpose
TBD - created by archiving change add-camera-type-config. Update Purpose after archive.
## Requirements
### Requirement: ROM model.properties SHALL declare camera_type

The file `/system/etc/model.properties` SHALL support optional integer property `camera_type` with allowed values:

- `1` — **BLUE_LIGHT** (蓝光摄像头)
- `2` — **RED_LIGHT** (红光摄像头)

When the key is absent, empty, or not parseable as `1` or `2`, the App MUST treat the device as **BLUE_LIGHT** (`1`).

#### Scenario: Missing key defaults to blue light

- **WHEN** `model.properties` exists but has no `camera_type` key
- **THEN** `DeviceModelConfig.getCameraType()` MUST return `CameraType.BLUE_LIGHT`

#### Scenario: Valid red light value loads

- **WHEN** `model.properties` contains `camera_type=2`
- **THEN** `DeviceModelConfig.getCameraType()` MUST return `CameraType.RED_LIGHT`

#### Scenario: Invalid value falls back with warning

- **WHEN** `model.properties` contains `camera_type=99`
- **THEN** `DeviceModelConfig.getCameraType()` MUST return `CameraType.BLUE_LIGHT`
- **AND** the App MUST log a warning that the value was invalid

### Requirement: DeviceModelConfig SHALL expose typed camera type

The App SHALL load `camera_type` once at startup (same lifecycle as other `DeviceModelConfig` keys) and expose:

- `DeviceModelConfig.getCameraType()` returning non-null `CameraType`
- `CameraType.getValue()` returning the integer JNI value (`1` or `2`)

#### Scenario: Preload loads camera type before AI session start

- **WHEN** `LaserApplication` calls `DeviceModelConfig.preload()`
- **THEN** subsequent `getCameraType()` MUST not block on file I/O
- **AND** MUST reflect the ROM value or default `BLUE_LIGHT`

### Requirement: CameraType enum SHALL map stable integer codes

`CameraType` SHALL define at minimum:

| Constant | Value |
|----------|-------|
| `BLUE_LIGHT` | `1` |
| `RED_LIGHT` | `2` |

App and native plumbing MUST use these integers consistently.

#### Scenario: Blue light is production default

- **WHEN** no ROM override exists
- **THEN** `CameraType.BLUE_LIGHT.getValue()` MUST equal `1`

