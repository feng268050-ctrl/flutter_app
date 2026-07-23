## Purpose

Define the JNI return-code contract for `nativeInferImageAndSave` so pipeline success (`0`), stage failures (negative integers), and qualitative detection results (`CLEAN` / `LIGHT` / `HEAVY`) are not conflated.
## Requirements
### Requirement: nativeInferImageAndSave SHALL use zero for successful pipeline completion

The native implementation of `nativeInferImageAndSave` SHALL return `0` when the JNI call, image read, model inference, and result image write have all completed successfully, regardless of the qualitative detection outcome (for example `CLEAN`, `LIGHT`, or `HEAVY`).

#### Scenario: Heavy detection but successful save returns zero

- **WHEN** the model classifies the scene as `HEAVY` (or equivalent) and the annotated image is written to the requested output path
- **THEN** the function SHALL return `0`
- **AND** the qualitative status SHALL NOT be encoded as a non-zero return value

### Requirement: nativeInferImageAndSave SHALL use defined negative codes for stage failures

The native implementation SHALL return the following negative integers on failure, and SHALL NOT use return values to convey `CLEAN` / `LIGHT` / `HEAVY` or similar business labels:

- `-1` for invalid arguments or invalid handle
- `-2` for input image read failure
- `-3` for model inference failure
- `-4` for result image save failure

#### Scenario: Unreadable input path returns negative two

- **WHEN** the input image path cannot be read or decoded
- **THEN** the function SHALL return `-2`
- **AND** it SHALL NOT return a code that represents a detection level

### Requirement: Qualitative detection results SHALL be delivered outside the integer return value

The system SHALL expose detection level, status string, and human-readable message through at least one of: an existing callback or event path (for example a check-result listener), or a companion result file (for example JSON alongside the output image). The App SHALL NOT infer `CLEAN` / `LIGHT` / `HEAVY` solely from the integer return code of `nativeInferImageAndSave` when that code is `0` or a defined negative error code.

#### Scenario: App does not map detection label from return code

- **WHEN** `nativeInferImageAndSave` returns `0`
- **THEN** the App presentation layer SHALL obtain `level`, `status`, and `message` from the agreed non-return-code channel
- **AND** SHALL NOT treat a non-zero historical “success” code as a detection label

### Requirement: App SHALL treat only zero as native infer success and map error codes to user-facing messages

The App layer (for example `LensGuardManager.inferJpgAndSaveResult` and `NativeBridge.guardedInferImageAndSave` diagnostics) SHALL treat `nativeCode == 0` as the only success outcome for the native infer call. For negative codes `-1` through `-4`, the App SHALL map to stable user-facing messages (for example via a dedicated helper), and SHALL use a generic fallback for other negative codes.

#### Scenario: Minus three shows inference failed message

- **WHEN** the native layer returns `-3`
- **THEN** the App SHALL surface a message consistent with “model inference failed” (or localized equivalent)
- **AND** SHALL NOT label the failure as a detection grade

### Requirement: App SHALL verify output file after native reports success

After `nativeCode == 0`, the App SHALL verify that the output image file exists and has non-zero size; if not, it SHALL report failure with a defined App-side error code (for example existing `-6` for missing/empty file) and SHALL NOT treat the call as a successful user-visible inference.

#### Scenario: Zero return but missing file is rejected

- **WHEN** `nativeCode` is `0` but the output file is missing or empty
- **THEN** the App SHALL return a failure result to the caller
- **AND** the failure SHALL be attributed to output validation, not to native detection level

### Requirement: Instrumented tests SHALL count success when native success and file present

Instrumented tests that batch-infer images SHALL increment success counts when the App-reported result is successful under the `nativeCode == 0` contract and the output file is present and non-empty.

#### Scenario: All successful images increment counter

- **WHEN** each image completes with `nativeCode == 0` and a non-empty output file
- **THEN** the test SHALL count each as success
- **AND** SHALL NOT require a legacy non-zero code for “business success”

### Requirement: nativeInferImageToJson SHALL use JSON code field for success and errors

The native method `nativeInferImageToJson(handle, imagePath)` SHALL return a JSON string where integer field `code` indicates outcome: `0` for successful inference and post-processing, and negative values for failures (`-1` argument/path, `-2` read failure, `-3` inference/post-process exception) per engine alignment documentation.

The App SHALL NOT treat non-JSON return values or empty strings as success.

#### Scenario: Successful offline frame

- **WHEN** native returns JSON with `"code":0` and `source` such as `offline_infer`
- **THEN** `LensGuardManager.inferJpgToJson` SHALL return that JSON to callers
- **AND** `AiVisionFrameInference.fromNativeJson` SHALL accept it without throwing

#### Scenario: Read failure

- **WHEN** native returns JSON with `"code":-2`
- **THEN** `fromNativeJson` SHALL throw or callers SHALL treat the frame as failed
- **AND** SHALL NOT write annotated result images (this API does not save images)

### Requirement: nativeInferImageToJson qualitative fields SHALL match stain vocabulary

On `code == 0`, JSON SHALL include `level`, `status`, and `message` using production stain vocabulary where `status` is one of `CLEAN`, `MILD`, `HEAVY`. Optional `boxes[]` entries SHALL use coordinates in the sampled JPEG pixel space (up to engine max count).

#### Scenario: Boxes parsed for overlay

- **WHEN** JSON includes `boxes` with `x1,y1,x2,y2,classId,label,score`
- **THEN** offline overlay rendering SHALL map coordinates directly to the frame bitmap dimensions without letterbox remapping

### Requirement: nativeInferImageToJson SHALL remain distinct from nativeInferImageAndSave

The App SHALL NOT invoke `nativeInferImageAndSave` for offline timeline sampling. App-side guarded wrappers SHALL route offline timeline calls only through `guardedInferImageToJson` on the RKNN single-thread executor.

#### Scenario: Manager routing

- **WHEN** AI Vision requests one-shot JSON for a JPG path
- **THEN** `LensGuardManager.inferJpgToJson` SHALL call `NativeBridge.guardedInferImageToJson`
- **AND** SHALL NOT call `guardedInferImageAndSave` for that use case

### Requirement: App maps nativeInferImageToJson to LensGuardInferenceResult

The App SHALL treat `nativeInferImageToJson` wire JSON as unchanged at the JNI boundary. `LensGuardManager.inferFromJpg` MUST map `code`, `level`, `status`, `message`, `imageWidth`, `imageHeight`, `boxes`, and `source` into `LensGuardInferenceResult` without altering native field semantics documented in this capability.

#### Scenario: Code zero mapping

- **WHEN** native returns `"code":0` with `boxes` and stain `status`
- **THEN** `inferFromJpg` MUST set `success` true and preserve `status` vocabulary (`CLEAN`, `MILD`, `HEAVY`)

#### Scenario: Negative code mapping

- **WHEN** native returns `"code":-2`
- **THEN** `inferFromJpg` MUST set `success` false and `code` -2
- **AND** MUST NOT populate fake detection boxes

### Requirement: nativeOpencvStainDetect SHALL not depend on blue-line valid region geometry

The OpenCV stain / `lens_det` JNI entry points (`nativeOpencvStainDetectFromJpg`, `FromRgb`, `FromNv12`, `FromI420` deprecated) SHALL perform detection using the fixed ROI enhance-invert-erode pipeline defined in `lens-det-fixed-roi-pipeline`. Callers MUST NOT assume that detection success requires visible blue guide lines or a vertically scaled valid band derived from `ref_height`.

For **`FromNv12`**, native code MUST convert NV12 to BGR via the shared `nv12ToBgr` path before entering the fixed ROI pipeline. **`FromI420`** SHALL shim through I420→NV12 conversion then the same path.

Configuration under `config.yaml` → `lens_det` MUST expose ROI and preprocess parameters; legacy `bright_*` and `valid_region_ref_*` keys MUST be ignored or documented as deprecated without affecting the fixed ROI path.

#### Scenario: Detect without blue lines in frame

- **WHEN** an input image contains no blue alignment lines but contamination appears inside the fixed ROI
- **THEN** native stain detect MUST still run the full ROI pipeline
- **AND** MUST return success with `target.json` when a qualifying blob is found

#### Scenario: JNI summary contract unchanged on failure

- **WHEN** no qualifying target is found after fixed ROI processing
- **THEN** JNI MUST return summary JSON with `ok:false` and empty `files`
- **AND** MUST NOT return coordinates in the summary string (coordinates remain file-based on success)

#### Scenario: FromNv12 uses shared nv12ToBgr

- **WHEN** `nativeOpencvStainDetectFromNv12` is invoked with valid dimensions and buffer
- **THEN** native MUST convert NV12 to BGR using the same implementation as `StreamDetectPipeline`
- **AND** MUST then run the fixed ROI stain pipeline unchanged

### Requirement: nativeInferImageToJson box coordinates SHALL use full JPEG pixel space

When `nativeInferImageToJson` returns JSON with `code == 0`, each optional `boxes[]` entry SHALL use `x1`, `y1`, `x2`, `y2` in the pixel coordinate system of the input JPEG (full width and height), after the engine applies the same center-crop ROI and crop-offset restoration as live inference.

The App SHALL parse and render these coordinates on the full bitmap without applying crop offsets or letterbox adjustments in the client.

#### Scenario: Offline JPG at 1920x1080

- **WHEN** offline inference runs on a 1920×1080 sampled JPG
- **THEN** returned box coordinates SHALL align with stains when drawn on the full image
- **AND** `AiVisionFrameInference` SHALL store `imageWidth` and `imageHeight` matching that JPG

