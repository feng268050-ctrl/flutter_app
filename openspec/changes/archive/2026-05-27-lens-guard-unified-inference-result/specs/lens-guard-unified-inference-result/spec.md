## ADDED Requirements

### Requirement: Unified detection result type

The system SHALL provide an immutable `LensGuardInferenceResult` (exact class name MAY vary) representing one stain/detection inference outcome. The type SHALL NOT embed classification-only fields (`topk`, `className` from cls snapshot).

Required fields on every result instance:

| Field | Type | Role |
|-------|------|------|
| `success` | boolean | `code == 0` for a completed native/App infer |
| `code` | int | Native or App error / busy code |
| **`level`** | **int** | **Stain severity: `0` clean, `1` mild, `2` heavy (same semantics as `onCheckResult` and offline JSON)** |
| **`status`** | **String** | **Short stain tag: production vocabulary `CLEAN`, `MILD`, `HEAVY` (and legacy `STAIN_*` aliases when native emits them)** |
| `message` | String | Human-readable description |
| `imageWidth`, `imageHeight` | int | Frame / JPEG dimensions; `0` if unknown |
| `boxes` | list | Detection boxes (`x1,y1,x2,y2`, `classId`, `label`, `score`) in pixel space |
| `source` | String | e.g. `preview_det`, `offline_infer`, `production` |
| `timestampMs` | long | Completion time |

`level` and `status` MUST be present on both I420 and JPG paths so callers never need to read raw `onCheckResult` arguments or parse JSON only for stain grade.

#### Scenario: Successful detection includes level and status

- **WHEN** native JSON contains `code: 0`, `level: 2`, `status: "HEAVY"`, and a non-empty `boxes` array
- **THEN** `LensGuardInferenceResult.success` MUST be true
- **AND** `level` MUST be `2`
- **AND** `status` MUST be `"HEAVY"`
- **AND** `boxes` MUST preserve native pixel coordinates before any UI normalization

#### Scenario: Failed inference still exposes level and status when known

- **WHEN** native JSON contains `code` not equal to `0` but includes `level` and `status`
- **THEN** `success` MUST be false
- **AND** `level` and `status` MUST be copied from JSON when present
- **AND** `message` MUST contain a human-readable error string

#### Scenario: App-side error uses sentinel level and status

- **WHEN** unified infer fails before native returns (timeout, busy, push rejected)
- **THEN** `success` MUST be false
- **AND** `level` MUST be `-1` unless native already supplied a level
- **AND** `status` MUST be `"ERROR"` or a documented busy sentinel (e.g. `"BUSY"`) consistent across I420 and JPG paths

### Requirement: level and status merge rules are identical for I420 and JPG

When both callback arguments and JSON `message` carry `level` / `status`, the mapper SHALL apply the same precedence for `inferFromI420` and `inferFromJpg`:

1. If `message` parses as JSON with `level` / `status`, use JSON values when present.
2. Else use `onCheckResult` `level` / `status` (I420 path only).
3. For JPG-only path, use JSON root fields; if missing on `code == 0`, treat as mapper error (`success == false`).

#### Scenario: I420 JSON overrides empty callback status

- **WHEN** `onCheckResult` has `level=0`, `status=""`, and `message` JSON has `"level":1,"status":"MILD"`
- **THEN** the unified result MUST have `level` 1 and `status` `"MILD"`

#### Scenario: JPG path populates level and status from JSON root

- **WHEN** `inferFromJpg` receives native JSON `{ "code":0, "level":0, "status":"CLEAN", "boxes":[] }`
- **THEN** the unified result MUST have `level` 0 and `status` `"CLEAN"`
- **AND** MUST match what `inferFromI420` would produce for an equivalent detection payload

### Requirement: inferFromI420 returns unified result

`LensGuardManager` SHALL expose `inferFromI420(byte[] i420, int width, int height)` (or equivalent) that pushes the frame via the existing guarded native push path, waits for the correlated `onCheckResult` callback, parses `message` when JSON, merges `level` and `status` from the callback, and returns `LensGuardInferenceResult`.

#### Scenario: JSON message from preview det

- **WHEN** `onCheckResult` delivers `message` containing JSON with `boxes` and `source` `preview_det`
- **THEN** `inferFromI420` MUST return a result whose `boxes` match the parsed JSON
- **AND** `source` MUST reflect the JSON `source` field when present

#### Scenario: Plain-text production message

- **WHEN** `onCheckResult` delivers a non-JSON `message` with `level` and `status` set
- **THEN** `inferFromI420` MUST still return `LensGuardInferenceResult` with those fields populated
- **AND** `boxes` MAY be empty

#### Scenario: Push rejected

- **WHEN** `guardedPushFrame` rejects the frame (invalid state or dimensions)
- **THEN** `inferFromI420` MUST return a failed result without waiting indefinitely
- **AND** MUST clear any in-flight infer lock

#### Scenario: Wait timeout

- **WHEN** no matching `onCheckResult` arrives within the configured timeout
- **THEN** `inferFromI420` MUST return a failed result with a timeout error code
- **AND** MUST clear the in-flight infer lock

### Requirement: inferFromJpg returns unified result

`LensGuardManager` SHALL expose `inferFromJpg(String imagePath)` that invokes `guardedInferImageToJson` on the RKNN guard thread and maps the JSON response into `LensGuardInferenceResult` using the same field rules as the I420 path.

#### Scenario: Offline infer success

- **WHEN** native returns JSON with `code: 0` and `source` `offline_infer`
- **THEN** `inferFromJpg` MUST return the same result shape as a successful `inferFromI420` call
- **AND** `boxes` coordinates MUST remain in JPEG pixel space

#### Scenario: JNI unavailable

- **WHEN** `nativeInferImageToJson` is not linked
- **THEN** `inferFromJpg` MUST return a failed unified result
- **AND** MUST NOT throw to callers of the public API

### Requirement: Single in-flight unified infer

The system SHALL allow at most one in-flight unified infer operation (`inferFromI420` or `inferFromJpg`) per `LensGuardManager` instance at a time. While in-flight, new invocations MUST NOT start a second native infer.

#### Scenario: Second I420 while first pending

- **WHEN** `inferFromI420` is in progress and another caller invokes `inferFromI420`
- **THEN** the second call MUST return immediately indicating busy/dropped (non-success with a distinct busy code or empty optional per implementation contract documented in JavaDoc)
- **AND** MUST NOT call `guardedPushFrame` again

#### Scenario: JPG while I420 in flight

- **WHEN** `inferFromI420` is in progress and `inferFromJpg` is invoked
- **THEN** `inferFromJpg` MUST be rejected as busy until the I420 operation completes

### Requirement: Deprecated legacy entry points

`LensGuardManager.inferJpgToJson` and public unstructured I420 push helpers used for inference SHALL be annotated `@Deprecated` and documented to delegate to `inferFromJpg` / `inferFromI420`. New feature code MUST use the unified APIs.

#### Scenario: Deprecated inferJpgToJson

- **WHEN** a caller invokes `inferJpgToJson`
- **THEN** the implementation MAY delegate to `inferFromJpg` and serialize back to JSON for compatibility
- **AND** Android Studio deprecation warnings MUST point to `inferFromJpg`

### Requirement: Hold-forward overlay policy applies to all unified infer consumers

Callers that render detection on a moving video stream (AI Vision live RTSP, process-video composited encode, production PR1, HTTP `/v1/camera/ai`) SHALL use the same hold-forward rule: use the latest **completed** unified result until a newer sample completes, without blocking the video path on infer. Detection boxes and stain **status text** (`level`, `status`, `message`) MUST be drawn **into the frame bitmap** (shared compositor). AI Vision live/recorded MUST NOT use stacked `DetectionOverlayView` or status `TextView` for those elements during composited sessions. Quick/Engineer production compositing on PR1 applies **only when `GET /v1/camera/ai` has active subscribers**; otherwise unified infer feeds warnings/logs/alerts only. Recorded video uses timeline `findFrameAt`; live uses a monotonic `lastCompleted` snapshot—semantics are equivalent for forward playback.

#### Scenario: Live and recorded share result type

- **WHEN** live preview completes `inferFromI420` and recorded detect completes `inferFromJpg`
- **THEN** both MUST produce `LensGuardInferenceResult` with the same `level`, `status`, and `boxes` schema
- **AND** overlay renderers MUST use `toOverlayBoxes()` or a shared mapper helper

### Requirement: Shared overlay conversion

`LensGuardInferenceResult` SHALL provide conversion to `DetectionOverlayView.Box` lists using the same normalization rules as `AiVisionOverlayParser` (pixel to 0–1 when image dimensions are known).

#### Scenario: Overlay draw

- **WHEN** `imageWidth` and `imageHeight` are positive
- **THEN** `toOverlayBoxes()` MUST produce normalized coordinates suitable for `DetectionOverlayView`
