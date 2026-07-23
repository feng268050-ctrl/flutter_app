## ADDED Requirements

### Requirement: Camera-based stain detect JNI SHALL accept cameraType parameter

Native stain-detect JNI entry points used for live and recorded camera video SHALL accept a trailing **`int cameraType`** argument with values defined by `CameraType` (`1` = BLUE_LIGHT, `2` = RED_LIGHT).

Affected methods include at minimum:

- RKNN: `nativeCreate`, `nativeRknnStainDetectFromStream`, `nativeRknnStainDetectFromJpg`, `nativeRknnStainDetectFromRgb`, `nativeRknnStainDetectFromI420`, `nativeRknnStainDetectFromJpgAndSave`, `nativeRknnStainDetectFromVideoAndSave`
- OpenCV stain: `nativeCreateOpencvStainDetectSession`, `nativeOpencvStainDetectFromJpg`, `nativeOpencvStainDetectFromRgb`, `nativeOpencvStainDetectFromI420`

Until red-light inference is implemented, native code MUST ignore `cameraType` and MUST preserve current blue-light behavior for all accepted values.

#### Scenario: Blue light call path unchanged

- **WHEN** the App invokes any affected JNI method with `cameraType=1`
- **THEN** detection output and performance MUST match pre-change behavior for the same inputs

#### Scenario: Red light parameter accepted but not branched

- **WHEN** the App invokes any affected JNI method with `cameraType=2`
- **THEN** native MUST NOT crash or reject the call solely due to camera type
- **AND** MUST behave identically to `cameraType=1` until a future red-light implementation lands

### Requirement: App SHALL pass DeviceModelConfig camera type into stain JNI

The App layer (`NativeBridge`, guarded wrappers, and `AiManager` stain-detect call sites) SHALL pass `DeviceModelConfig.getCameraType().getValue()` into every affected native stain-detect call.

#### Scenario: Live I420 OpenCV infer passes camera type

- **WHEN** `opencvStainDetectFromI420` runs on a device with `camera_type=1` in ROM
- **THEN** `nativeOpencvStainDetectFromI420` MUST be called with `cameraType=1`

#### Scenario: Process video session uses ROM camera type

- **WHEN** process video Detect runs on a device with `camera_type=2` in ROM
- **THEN** each OpenCV stain JNI call in that session MUST receive `cameraType=2`

### Requirement: Native camera type hook SHALL be documented for future work

Native implementations that receive `cameraType` SHALL include a brief comment (e.g. `TODO(camera-type)`) indicating where model selection, ROI, or threshold branching will occur for RED_LIGHT.

#### Scenario: Native source documents deferred branching

- **WHEN** a developer inspects `jni_bridge.cpp` or `opencv_stain_detect_jni.cpp` stain entry points
- **THEN** each `cameraType` parameter MUST have an adjacent comment referencing future RED_LIGHT adaptation
