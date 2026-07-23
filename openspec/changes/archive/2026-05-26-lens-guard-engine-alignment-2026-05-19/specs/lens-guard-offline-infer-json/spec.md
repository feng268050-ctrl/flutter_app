## ADDED Requirements

### Requirement: Offline video analysis SHALL use nativeInferImageToJson when available

When the capability profile reports `offlineInferJsonAvailable`, AI Vision offline processing for selected process videos SHALL sample frames (approximately every 500 ms per product constants), call `LensGuardManager.inferJpgToJson` for each JPEG path on the RKNN single-thread guard, and SHALL NOT use `nativeInferImageAndSave` or production `onCheckResult` for timeline population.

#### Scenario: Successful frame inference

- **WHEN** `inferJpgToJson` returns JSON with `code: 0`
- **THEN** the App SHALL parse the payload via `AiVisionFrameInference.fromNativeJson`
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
