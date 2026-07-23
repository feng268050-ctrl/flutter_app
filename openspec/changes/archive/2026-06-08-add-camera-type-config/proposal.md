## Why

The machine may use two distinct camera modalities—**blue-light** (current production path) and **red-light** (planned)—each requiring different AI models and tuning. Today there is no ROM-level way to declare which camera type a device or emulator represents, and native inference entry points have no hook to branch on camera type. We need build-time injection into `model.properties` and JNI plumbing now so future red-light inference can land without another breaking signature change.

## What Changes

- Add **`CAMERA_TYPE`** Make/env variable for **`make prepare`** and **`make emulator`**, written as `camera_type=<n>` in `/system/etc/model.properties`.
  - `1` → **BLUE_LIGHT** (蓝光摄像头) — default when unset
  - `2` → **RED_LIGHT** (红光摄像头)
- Load `camera_type` at App startup via **`DeviceModelConfig`** (integer, default `1`).
- Introduce a small **`CameraType`** enum/constants in App code for typed access.
- Extend **camera-based AI native JNI** (RKNN stain detect + OpenCV stain detect session/infer entry points) with an **`int cameraType`** parameter. Native code **SHALL ignore** the value for now but document it for future model/ROI selection per camera modality.
- App callers **SHALL pass** `DeviceModelConfig.getCameraType()` (or equivalent) on every affected JNI call; behavior remains identical to today when `camera_type=1`.
- Update **`.env.example`**, **Makefile help**, and emulator/prepare scripts to document `CAMERA_TYPE`.

## Capabilities

### New Capabilities

- `device-camera-type-config`: ROM `camera_type` key, runtime load/default, and App `CameraType` representation.

### Modified Capabilities

- `build-ci-tooling`: `CAMERA_TYPE` env var for `make prepare` and `make emulator` `model.properties` sync.
- `lens-det-app-inference`: JNI signatures and App call sites for camera-based stain detect accept `cameraType`; native ignores until red-light path is implemented.

## Impact

- **Scripts**: `scripts/emulator-system-common.sh` (`sync_model_properties`), `scripts/ci/prepare-device.sh` (`write_model_config`), Makefile help, `.env.example`.
- **App**: `DeviceModelConfig`, new `CameraType` helper, `NativeBridge` + guarded wrappers, `AiManager` / video-AI call sites that invoke stain JNI.
- **Native**: `native/lensinspector/src/jni_bridge.cpp`, `opencv_stain_detect_jni.cpp` — signature changes (**BREAKING** at JNI layer; requires `make ai` + App rebuild together).
- **Tests**: `DeviceModelConfig` unit tests, JNI/guarded-call tests if present, script smoke checks.
- **Out of scope this change**: red-light model assets, ROI/threshold tuning, zero-point detect JNI, remote snapshot `deviceInfo` field, switching camera RTSP URLs by type.
