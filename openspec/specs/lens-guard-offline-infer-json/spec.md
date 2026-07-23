# lens-guard-offline-infer-json Specification

## Purpose
TBD - created by archiving change lens-guard-engine-alignment-2026-05-19. Update Purpose after archive.
## Requirements
### Requirement: Offline video analysis SHALL use nativeInferImageToJson when available

When the capability profile reports `offlineInferJsonAvailable`, AI Vision offline processing for selected process videos SHALL sample frames (approximately every 500 ms per product constants), convert each sample to I420 in memory, call `LensGuardManager.inferFromI420`, and SHALL NOT use temporary JPEG files, `nativeInferImageAndSave`, or production `onCheckResult` for timeline population.

#### Scenario: Successful frame inference

- **WHEN** `inferFromI420` returns `success` with a valid unified result
- **THEN** the App SHALL map the payload into the offline timeline (e.g. `AiVisionFrameInference.fromLensGuardResult`)
- **AND** SHALL append the frame to the offline timeline used for overlay and inference MP4 export

#### Scenario: Native failure code

- **WHEN** JSON contains `code` not equal to `0` (native codes `-1`..`-3` per engine contract)
- **THEN** the frame SHALL be skipped or counted as failure per existing offline pipeline policy
- **AND** diagnostics SHALL log the code and message without crashing the upload flow

### Requirement: Offline infer SHALL be skipped with explicit operator feedback when JNI is unavailable

When `offlineInferJsonAvailable` is `false`, the system SHALL NOT silently claim inference MP4 is ready. Upload or export paths that require inference video SHALL surface a user-visible message equivalent to «推理视频尚未准备好» (or localized successor) and SHALL log guidance to update `libai.so` / ai-library.

#### Scenario: Old libai.so without symbol

- **WHEN** `nativeInferImageToJson` is not available on the loaded library
- **THEN** `offlineInferJsonAvailable` SHALL be `false`
- **AND** upload gating SHALL block or degrade per product policy with explicit messaging
- **AND** SHALL NOT set compile-time bypass flags that hide the missing capability in release builds

#### Scenario: Android emulator without RKNN session

- **WHEN** the app runs on an emulator and `LensGuardManager.isRunning()` is `false` after libs-only startup
- **THEN** `offlineInferJsonAvailable` SHALL be `false`
- **AND** process-video / upload paths SHALL surface explicit failure (e.g. engine not running or offline JNI unavailable)
- **AND** SHALL NOT invoke `nativeCreate` or offline infer JNI on the emulator host

### Requirement: Only code zero SHALL advance offline timeline success semantics

The App SHALL treat `code == 0` as the sole success indicator for offline JSON inference, consistent with engine documentation. Qualitative `level`, `status` (`CLEAN` / `MILD` / `HEAVY`), and `boxes` SHALL be read from JSON fields, not from JNI integer return values.

#### Scenario: Heavy stain with successful infer

- **WHEN** JSON has `code: 0`, `status: "HEAVY"`, and non-empty `boxes`
- **THEN** the timeline entry SHALL record HEAVY level and boxes in image pixel coordinates
- **AND** SHALL NOT require `onCheckResult` callback delivery

### Requirement: Pre-upload validation SHALL verify inference MP4 when offline path is required

Before completing AI Vision upload that depends on offline inference video, the App SHALL verify the inference MP4 file exists and is non-empty when `offlineInferJsonAvailable` is `true`.

#### Scenario: Upload blocked without MP4

- **WHEN** offline infer is required and the inference MP4 path is missing or zero bytes
- **THEN** upload SHALL not proceed as success
- **AND** the operator SHALL receive a clear failure reason in UI or toast

### Requirement: Offline timeline prefers inferFromI420

AI Vision process-video and offline analysis boundaries SHALL use `LensGuardManager.inferFromI420` returning `LensGuardInferenceResult` as the primary API. Raw `inferJpgToJson` strings MUST NOT cross feature module boundaries except inside deprecated compatibility shims.

#### Scenario: Session timeline population

- **WHEN** `ProcessVideoAiSession` records a sample
- **THEN** it MUST call `inferFromI420` on I420 bytes derived from the sampled frame
- **AND** MUST NOT write temporary JPEG files for inference input
- **AND** MUST NOT require a separate production `onCheckResult` subscription for that sample beyond the unified infer callback

#### Scenario: Deprecated string API

- **WHEN** legacy code calls `inferJpgToJson`
- **THEN** the implementation MAY wrap `inferFromJpg` and serialize to JSON for backward compatibility

