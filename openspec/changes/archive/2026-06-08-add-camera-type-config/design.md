## Context

`/system/etc/model.properties` already carries device identity keys (`model`, `sn`, `camera_ip`, `host_ip`) injected by `make emulator` (`sync_model_properties`) and `make prepare` (`write_model_config`). `DeviceModelConfig` loads these once at process start.

All camera-based AI stain detection (live PR1, AI Vision live, recorded/process video) runs through OpenCV stain JNI today, with optional RKNN paths on hardware. Implementations assume **blue-light** camera imagery. A **red-light** camera variant will need distinct models and post-processing; we want configuration and JNI signatures in place before that work lands.

## Goals / Non-Goals

**Goals:**

- Persist `camera_type` in ROM via existing Make workflows (`CAMERA_TYPE=1|2`, default `1`).
- Expose typed runtime access (`DeviceModelConfig.getCameraType()` / `CameraType`).
- Thread `cameraType` through stain-detect JNI (session create + infer entry points); native ignores value but documents future use.
- Keep **observable behavior unchanged** when `camera_type=1` (current production default).

**Non-Goals:**

- Shipping red-light models, configs, or alternate inference pipelines.
- Changing zero-point detect JNI.
- Adding `cameraType` to WebSocket `deviceInfo` or cloud stat payloads.
- Auto-selecting RTSP URLs or MediaMTX paths by camera type.

## Decisions

### 1. Property key and values: `camera_type` integer in `model.properties`

**Choice:** Store `camera_type=1` or `camera_type=2` (ASCII integer), mirroring existing key style (`camera_ip`, `host_ip`).

**Rationale:** Consistent with ROM config patterns; easy for shell scripts and Java `Properties`.

**Alternatives considered:** String enum (`camera_type=BLUE_LIGHT`) — rejected to keep script validation simple and align with user's `1`/`2` mapping.

### 2. Default when absent: `1` (BLUE_LIGHT)

**Choice:** If `camera_type` key is missing, empty, or unparsable, App and scripts treat the device as blue-light (`1`).

**Rationale:** Preserves backward compatibility for existing devices and emulators without re-flash.

### 3. Build injection: extend existing merge/push helpers

**Choice:**

- `sync_model_properties` (emulator): merge `CAMERA_TYPE` env → `camera_type=` line; default `1` when env unset and key absent from pulled file.
- `write_model_config` (prepare): write `camera_type=` when any model config key is written; default `1` if `CAMERA_TYPE` unset.

**Rationale:** Same pattern as `CAMERA_IP` / `HOST_IP`; no new Make targets.

### 4. App representation: `CameraType` enum + int in `DeviceModelConfig`

**Choice:** Add `com.lasercyber.lws.ui.common.config.CameraType` with `BLUE_LIGHT(1)` and `RED_LIGHT(2)`, plus `DeviceModelConfig.getCameraType()` returning the enum (never null; defaults to `BLUE_LIGHT`).

**Rationale:** Avoid magic integers in Java call sites; single source for JNI int values.

### 5. JNI placement: session create + all stain infer entry points

**Choice:** Add trailing `jint cameraType` to:

| Layer | Methods |
|-------|---------|
| RKNN (`jni_bridge.cpp`) | `nativeCreate`, `nativeRknnStainDetectFromStream`, `nativeRknnStainDetectFromJpg`, `nativeRknnStainDetectFromRgb`, `nativeRknnStainDetectFromI420`, `nativeRknnStainDetectFromJpgAndSave`, `nativeRknnStainDetectFromVideoAndSave` |
| OpenCV stain (`opencv_stain_detect_jni.cpp`) | `nativeCreateOpencvStainDetectSession`, `nativeOpcvStainDetectFromJpg/Rgb/I420` |

Native implementation: `(void)cameraType;` or equivalent with a short comment block, e.g. `// TODO(camera-type): select model/ROI when RED_LIGHT`.

**Rationale:** Session-level and per-frame hooks cover future model swap at init and per-call overrides without another JNI break.

**Alternatives considered:** Only `nativeCreate` — rejected because offline one-shot infer paths bypass long-lived session state in some flows.

### 6. Java guarded wrappers pass config-derived type

**Choice:** `NativeBridge.guarded*` methods read `DeviceModelConfig.getCameraType().getValue()` once per call (or accept explicit int for tests).

**Rationale:** Centralizes default; tests can still pass constants.

### 7. Breaking JNI change coordinated in one release

**Choice:** Update Java `native` declarations, C++ JNI names, `verify_libai_jni.sh` / symbol checks, and rebuild `libai.so` in the same change.

**Rationale:** JNI signature mismatch crashes at load time; partial updates are unsafe.

## Risks / Trade-offs

- **[Risk] JNI signature drift between App and libai.so** → Mitigation: single PR, `make ai` + `make build`, extend `scripts/verify_libai_jni.sh` for new mangled names.
- **[Risk] Prepare script overwrites `model.properties` without merge on physical device** → Mitigation: only write `camera_type` when other keys are written; document that full merge is emulator-only (existing behavior for `camera_ip`).
- **[Risk] Invalid `CAMERA_TYPE` env (e.g. `3`)** → Mitigation: scripts validate `1|2` and fail fast with clear error; App falls back to `1` on bad ROM value with warning log.
- **[Trade-off] Native ignores parameter today** → Acceptable; spec requires plumbing only; red-light behavior is a follow-up change.

## Migration Plan

1. Land script + App + native changes together; developers run `make ai && make build`.
2. Existing devices without `camera_type` in ROM behave as blue-light (default `1`).
3. For red-light dev testing later: `CAMERA_TYPE=2 make emulator` or `CAMERA_TYPE=2 make prepare`.
4. Rollback: revert JNI signatures and rebuild `libai.so`; remove key from ROM optional (App still defaults to `1`).

## Open Questions

- Should `deviceInfo.cameraType` be exposed on the remote snapshot in a follow-up? (Deferred.)
- Will red-light use the same `config.yaml` path or a sibling directory? (Deferred; native TODO comment only.)
