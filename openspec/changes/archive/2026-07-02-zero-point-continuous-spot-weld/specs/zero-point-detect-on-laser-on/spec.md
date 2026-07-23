## MODIFIED Requirements

### Requirement: Each sample uses I420 frame and zero-point native JNI

At each PR1-driven sample opportunity while laser is ON, the App SHALL obtain a snapshot I420 frame from the production sub-stream (PR1) latest-frame holder and run detect on a background executor without blocking Modbus or UI threads.

**Java** SHALL invoke **only** `NativeBridge.nativeOpencvZeroPointDetectFromI420` for every accepted laser-on zero-point sample, regardless of Machine Model (L1 or L1 Pro).

Before each detect call, Java SHALL set the zero-point native session **detect target mode** from the active weld model type per `zero-point-line-detect` (`CONTINUOUS_WELDING` → Line, `POINT_WELDING` → Point).

Java SHALL NOT invoke `nativeOpencvEdgeDrawingDetectFromI420` for laser-on zero-point production rounds. Round lifecycle, sampling gates, JSON parsing, and correction semantics SHALL be unchanged aside from unified JNI and weld-mode target selection.

#### Scenario: All models call zero-point JNI

- **WHEN** a PR1-driven sample is accepted, Machine Model is L1 or L1 Pro, and a fresh I420 snapshot is available
- **THEN** the App SHALL call `nativeOpencvZeroPointDetectFromI420` with that frame
- **AND** SHALL parse the returned JSON on the worker thread

#### Scenario: L1 Pro does not call EdgeDrawing JNI

- **WHEN** a PR1-driven sample is accepted and Machine Model is L1 Pro
- **THEN** the App SHALL call `nativeOpencvZeroPointDetectFromI420`
- **AND** SHALL NOT call `nativeOpencvEdgeDrawingDetectFromI420` for that sample

#### Scenario: No frame available

- **WHEN** a sample opportunity occurs but no I420 snapshot is available
- **THEN** that sample SHALL be skipped
- **AND** the round SHALL continue on subsequent PR1 frames while laser remains ON

### Requirement: Parse offset_x and compute UI correction with inverted sign

Native JSON SHALL expose at minimum `ok`, `code`, `reason` (when `ok` is false), `offset_x`, and `offset_y`. The `code` field MUST follow the shared OpenCV detect table in `opencv-detect-error-codes` (for example `-5` with `reason=spot_size_above_max` for spot-size rejection in point mode, `-3` with `reason=line_not_found` for continuous-weld line failure, or `-5` with `reason=no_valid_region` / `empty_roi` for red-frame mask failures).

For samples with **`ok == true`**, the App SHALL read **`offset_x`** (pixels, detected minus reference). UI zero correction uses **1 unit = 3px** with **+ = move zero right** and **− = move zero left**. The App SHALL compute per-sample UI delta as:

**`uiDelta = round(-offset_x / 3.0)`**

(JSON negative → UI increases; JSON positive → UI decreases.)

#### Scenario: Negative offset_x increases UI value

- **WHEN** native returns `ok=true` and `offset_x=-6`
- **THEN** per-sample `uiDelta` SHALL be `+2`

#### Scenario: Line not found does not produce offset

- **WHEN** native returns `ok=false`, `code=-3`, `reason=line_not_found`
- **THEN** the App MUST NOT treat the sample as a valid offset for cluster aggregation

#### Scenario: Red-frame mask empty does not produce offset

- **WHEN** native returns `ok=false`, `code=-5`, `reason=empty_roi` or `no_valid_region`
- **THEN** the App MUST NOT treat the sample as a valid offset for cluster aggregation

## ADDED Requirements

### Requirement: Zero-point native path SHALL apply simplified red-frame gate before detection

Before running brightest-in-box (point mode) or brightest-line-in-box (line mode), native `zero_point` code SHALL invoke the shared red-frame validator on the full BGR frame when red-frame gate is enabled.

The validator SHALL check mask existence only (grayscale threshold, largest contour, erosion) per `opencv-red-frame-validation`. It SHALL NOT reject frames for OSD overlay exclusion, overexposure metrics, or non-red color thresholds.

When the gate rejects a frame, native MUST return `ok=false`, `code=-5`, with `reason` in `no_valid_region` or `empty_roi`. Downstream point or line detection MUST NOT run on rejected frames.

#### Scenario: No valid region skips detection

- **WHEN** a PR1 I420 frame is submitted to zero_point JNI
- **AND** the red-frame gate finds no qualifying bright region mask
- **THEN** native MUST return `ok=false`, `code=-5`, `reason=no_valid_region` or `empty_roi`
- **AND** the App round SHALL treat the sample as a failed attempt (not a valid offset)

#### Scenario: Dark continuous-weld frame with bright line may pass simplified gate

- **WHEN** a continuous-weld frame has a valid eroded ROI mask from bright pool pixels
- **AND** red-frame gate is enabled
- **THEN** native SHALL NOT reject the frame solely because HSV red ratio or overexposure metrics would have failed the legacy A7 checks
- **AND** SHALL proceed to line detection when mode is Line

## REMOVED Requirements

### Requirement: Zero-point and EdgeDrawing native paths SHALL apply red-frame gate before detection

**Reason**: Laser-on zero-point production unifies on `zero_point` JNI only; EdgeDrawing is no longer invoked. Red-frame validation is simplified and specified under the modified zero-point gate requirement above.

**Migration**: Remove EdgeDrawing-specific gate scenarios from laser-on zero-point specs. EdgeDrawing offline CLI and JNI remain available outside laser-on zero-point production.
