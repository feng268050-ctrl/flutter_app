# lens-det-emulator-session Specification

## Purpose
TBD - created by archiving change lens-det-emulator-session. Update Purpose after archive.
## Requirements
### Requirement: Lens det uses an independent OpenCV session handle

The system SHALL manage lens_det OpenCV inference through a dedicated native session handle (`ldHandle`) created by `NativeBridge.nativeCreateOpencvLensDetSession(configYamlPath, projectRoot)` and destroyed by `nativeDestroyOpencvLensDetSession(ldHandle)`. The session MUST load `lens_det:` options from the deployed `config.yaml` via native `load_config` and MUST NOT require an active RKNN engine handle.

#### Scenario: Session created from deployed config

- **WHEN** `AssetDeployer.deploy` has written `config.yaml` under the lens guard project root
- **AND** `nativeCreateOpencvLensDetSession` is called with the deployed config path and project root
- **THEN** the returned `ldHandle` MUST be non-zero
- **AND** subsequent `nativeOpencvStainDetectFromNv12(ldHandle, ...)` MUST use the `lens_det:` section from that config

#### Scenario: Invalid session handle rejected

- **WHEN** `nativeOpencvStainDetectFromNv12` is called with `ldHandle == 0`
- **THEN** native MUST return summary JSON with `ok == false` and a documented invalid-handle reason
- **AND** MUST NOT read arbitrary memory via a stale pointer

### Requirement: Emulator startup creates lens det session without RKNN

When the app runs on a host classified by `AiNativeRuntime.blocksRknnSession()`, and `BuildConfig.ENABLE_LENS_DET_APP` is true, `AiManager.start()` SHALL deploy assets and create a lens_det session after `NativeBridge.ensureLoaded` succeeds. RKNN `nativeCreate` and `nativeStart` MUST NOT be invoked on the emulator.

#### Scenario: Emulator libs-only with lens det enabled

- **WHEN** the app starts on an Android emulator with `ENABLE_LENS_DET_APP=true`
- **THEN** `AiManager.isRunning()` MUST be false
- **AND** `AiManager.isLensDetAvailable()` MUST be true after successful `start()`
- **AND** logcat MUST record lens_det session creation with the deployed config path

#### Scenario: Lens det disabled on emulator

- **WHEN** `ENABLE_LENS_DET_APP` is false on an emulator
- **THEN** `isLensDetAvailable()` MUST be false
- **AND** the app MUST NOT call `nativeCreateOpencvLensDetSession`

### Requirement: AI Vision process video offline lens det works on emulator

On an arm64-v8a emulator with lens_det enabled, the user SHALL be able to upload a local process video and start AI Vision **Detect** such that `ProcessVideoAiSession` runs lens_det offline inference on the existing 500 ms sampling grid without requiring RKNN.

#### Scenario: Session create succeeds on emulator

- **WHEN** the user selects a valid local process video in AI Vision Detect on an emulator
- **AND** `ENABLE_LENS_DET_APP=true` and `isLensDetAvailable()` is true
- **THEN** `ProcessVideoAiSession.tryCreate` MUST succeed
- **AND** MUST NOT fail with `ENGINE_NOT_RUNNING` solely because RKNN is unavailable

#### Scenario: Offline infer executes on emulator

- **WHEN** the process-video worker accepts a 500 ms sample while lens_det is enabled on an emulator
- **THEN** the app MUST call OpenCV stain detect via **`opencvStainDetectFromNv12`** (or equivalent `inferLensDetFromNv12`) with source `process_video_lens_det`
- **AND** MUST log `process_video_lens_det sample_ok` or `sample_fail` with native result codes

