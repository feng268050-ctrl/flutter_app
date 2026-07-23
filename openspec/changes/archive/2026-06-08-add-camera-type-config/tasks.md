## 1. Build tooling — model.properties injection

- [x] 1.1 Add `validate_camera_type()` helper in shared shell scripts (accept `1|2`, default `1`, fail on invalid)
- [x] 1.2 Extend `sync_model_properties` in `scripts/emulator-system-common.sh`: merge/write `camera_type` from `CAMERA_TYPE` env (default `1` when unset and key absent)
- [x] 1.3 Extend `write_model_config` in `scripts/ci/prepare-device.sh`: write `camera_type=` when model config is pushed (default `1`)
- [x] 1.4 Document `CAMERA_TYPE` in root `Makefile` help and `.env.example`

## 2. App runtime — DeviceModelConfig and CameraType

- [x] 2.1 Add `CameraType` enum (`BLUE_LIGHT=1`, `RED_LIGHT=2`) under `ui.common.config`
- [x] 2.2 Load `camera_type` in `DeviceModelConfig` with default/fallback to `BLUE_LIGHT` and warning on invalid values
- [x] 2.3 Add unit tests for `DeviceModelConfig` camera type parsing (missing, `1`, `2`, invalid)

## 3. Native JNI — cameraType parameter (ignored for now)

- [x] 3.1 Add trailing `jint cameraType` to RKNN stain JNI in `jni_bridge.cpp` (`nativeCreate`, stream/jpg/rgb/i420/video infer); add `TODO(camera-type)` comments; ignore value in body
- [x] 3.2 Add trailing `jint cameraType` to OpenCV stain JNI in `opencv_stain_detect_jni.cpp` (session create + infer); add comments; ignore value
- [x] 3.3 Update Java `NativeBridge` native method declarations and all `guarded*` wrappers to pass `DeviceModelConfig.getCameraType().getValue()`
- [x] 3.4 Update `AiManager` and other direct native stain call sites (if any bypass guarded wrappers)
- [x] 3.5 Extend `scripts/verify_libai_jni.sh` (or symbol check) for updated JNI signatures; rebuild with `make ai`

## 4. Verification

- [x] 4.1 Run unit tests for `DeviceModelConfig` / related config tests
- [x] 4.2 Smoke: `CAMERA_TYPE=2 make emulator` (or script dry-run) confirms `camera_type=2` in guest `model.properties`
- [x] 4.3 Smoke: `CAMERA_TYPE=1 make prepare` (or script path) confirms default `camera_type=1`
- [x] 4.4 Confirm live/process video AI paths still run on emulator/device with default blue-light behavior
