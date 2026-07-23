## ADDED Requirements

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
