# zero-point-detect-on-laser-on Specification

## Purpose
TBD - created by archiving change zero-point-detect-on-laser-on. Update Purpose after archive.
## Requirements
### Requirement: Laser rising edge starts bounded zero-point detect task

When the device reports laser **OFF→ON** via cached `DeviceStatus` and `zeroPointOffsetDetectionEnabled` is true, the App SHALL start a zero-point detect **round** anchored at laser-on time `T₀`. While laser remains ON, zero-point detect samples SHALL be driven by **`StreamDetectPipeline`** on PR1: the first attempt MUST be eligible on the **first acceptable decoded frame** after `T₀` in the native pipeline (no mandatory `T₀ + 500ms` delay). Subsequent attempts SHALL respect **500ms** in normal mode or **100ms** burst interval when burst mode is active inside the native scheduler. There SHALL be **no fixed maximum sample count** per laser-on event. When laser turns **OFF**, the App SHALL finalize that round (aggregate valid samples and apply correction per existing cluster-reducer rules). If laser turns ON again while a round is active, the App SHALL cancel the in-flight round and start a new round from the new `T₀`.

When `zeroPointOffsetDetectionEnabled` is false, the App SHALL NOT schedule zero-point detect samples in the native pipeline for that laser-on session.

#### Scenario: First sample on first PR1 frame

- **WHEN** laser transitions from OFF to ON
- **AND** `zeroPointOffsetDetectionEnabled` is true
- **AND** the native pipeline delivers the first decoded frame at `T₀ + Δ` where `Δ` may be less than 500ms
- **THEN** the system SHALL attempt zero-point detection on that frame (subject to gate and busy rules)
- **AND** SHALL NOT defer the first attempt solely until `T₀ + 500ms`

#### Scenario: Continuous sampling while laser on

- **WHEN** laser remains ON and the native pipeline continues decoding PR1
- **AND** `zeroPointOffsetDetectionEnabled` is true
- **THEN** the system SHALL keep attempting zero-point detection at the configured gate interval
- **AND** SHALL NOT stop after a fixed fourth sample

#### Scenario: Laser off finalizes round

- **WHEN** laser turns OFF after one or more sample attempts in the current round
- **AND** `zeroPointOffsetDetectionEnabled` was true for that round
- **THEN** the App SHALL run cluster aggregation on valid samples from that round
- **AND** SHALL apply or skip Modbus write per existing tolerance and reducer rules

#### Scenario: Laser off cancels further sampling

- **WHEN** laser turns OFF
- **THEN** no further zero-point samples SHALL run for that round in the native pipeline

#### Scenario: Re-trigger on second laser-on

- **WHEN** laser turns ON again while a zero-point round is still active
- **AND** `zeroPointOffsetDetectionEnabled` is true
- **THEN** the previous round SHALL be cancelled without finalize
- **AND** a new round SHALL start from the new laser-on time

#### Scenario: Toggle off skips entire laser-on round

- **WHEN** `zeroPointOffsetDetectionEnabled` is false
- **AND** laser transitions from OFF to ON
- **THEN** the App SHALL NOT start a zero-point detect round
- **AND** SHALL NOT sample PR1 frames for zero-point detect while laser remains ON
- **AND** SHALL NOT finalize or write 0090H when laser turns OFF for that session

### Requirement: Each sample uses I420 frame and zero-point native JNI

At each PR1-driven sample opportunity while laser is ON, **`StreamDetectPipeline`** SHALL run zero-point detect in native code on the gated BGR/NV12 frame. Java **`ZeroPointManualAutoCoordinator`** (or successor) SHALL subscribe to `detect_result` events for zero_point and MUST NOT obtain I420 snapshots from `LatestI420FrameHolder` or `LivePr1InferenceStreamClient` for live RTSP samples.

**Java** SHALL still select the detect function routing policy from Machine Model (per `machine-model-zero-point-routing`) by configuring the native pipeline module at session start.

#### Scenario: Zero point result from bus not JNI I420

- **WHEN** a zero-point sample completes in the native pipeline
- **THEN** Java MUST receive the result via `StreamDetectResultBus`
- **AND** MUST NOT call `nativeOpencvZeroPointDetectFromI420` with live PR1 I420 from Java

#### Scenario: Background executor for round aggregation unchanged

- **WHEN** laser turns OFF and valid samples exist
- **THEN** cluster aggregation and Modbus write MUST still run on a background executor without blocking Modbus poll or UI threads

### Requirement: Parse offset_x and compute UI correction with inverted sign

Native JSON SHALL expose at minimum `ok`, `code`, `reason` (when `ok` is false), `offset_x`, and `offset_y`. The `code` field MUST follow the shared OpenCV detect table in `opencv-detect-error-codes` (for example `-5` with `reason=spot_size_above_max` for spot-size rejection in point mode, `-3` with `reason=line_not_found` for continuous-weld line failure, or `-5` with `reason=no_valid_region` / `empty_roi` for red-frame mask failures).

For samples with **`ok == true`**, the App SHALL read **`offset_x`** (pixels, detected minus reference). UI zero correction uses **1 unit = 3px** with **+ = move zero right** and **− = move zero left**. The App SHALL compute per-sample UI delta as:

**`uiDelta = round(-offset_x / 3.0)`**

(JSON negative → UI increases; JSON positive → UI decreases.)

**Position tolerance** (`ZeroPointCorrectionMapper.isWithinPositionTolerance`) SHALL use **only `offset_x`** (absolute value ≤ `POSITION_TOLERANCE_PX`). `offset_y` SHALL NOT affect skip-write, alerts, or correction eligibility.

#### Scenario: Large offset_y within tolerance when offset_x is small

- **WHEN** aggregated representative has `offset_x = 5.0` and `offset_y = 50.0`
- **THEN** `isWithinPositionTolerance` SHALL return true
- **AND** the App SHALL skip Modbus write and offset alert for this round

#### Scenario: Negative offset_x increases UI value

- **WHEN** native returns `ok=true` and `offset_x=-6`
- **THEN** per-sample `uiDelta` SHALL be `+2`

#### Scenario: Line not found does not produce offset

- **WHEN** native returns `ok=false`, `code=-3`, `reason=line_not_found`
- **THEN** the App MUST NOT treat the sample as a valid offset for cluster aggregation

#### Scenario: Red-frame mask empty does not produce offset

- **WHEN** native returns `ok=false`, `code=-5`, `reason=empty_roi` or `no_valid_region`
- **THEN** the App MUST NOT treat the sample as a valid offset for cluster aggregation

### Requirement: Aggregate samples and update zeroPointCorrection with clamp

When laser turns **OFF** for the current zero-point round, the App SHALL collect all native-valid (`ok == true`) samples from that round into `ZeroPointDetectClusterReducer` as **one detection round**. The reducer SHALL apply cluster selection (16px tolerance, largest cluster, representative nearest cluster center) with priority over round-anchor filtering (10px from first valid sample), per `zero-point-detect-cluster-filter`.

If the reducer returns a representative sample, the App SHALL set **`meanOffsetX`** and **`meanOffsetY`** to that representative's offsets (not the arithmetic mean of the raw list), derive **`uiDelta = round(-meanOffsetX / 3.0)`**, and set:

**`newZeroPointCorrection = clamp(currentZeroPointCorrection + uiDelta, -30, 30)`**

The App SHALL persist the new value and write Modbus register **0090H** using the existing Advanced Settings write path (`zeroPointCorrection × 10`). If the reducer returns no representative (no valid samples or empty round), the App SHALL leave `zeroPointCorrection` unchanged and SHALL NOT write 0090H for this round.

#### Scenario: Round applies correction from cluster representative on laser off

- **WHEN** laser turns OFF and valid samples in the round include outliers but the reducer representative yields `offset_x = -9.0`, `offset_y = 0.0`
- **THEN** `meanOffsetX` SHALL be `-9.0`
- **AND** `uiDelta` SHALL be `+3`
- **AND** persisted correction SHALL be updated before Modbus write when tolerance allows

#### Scenario: All samples invalid on laser off

- **WHEN** laser turns OFF and no valid samples exist in the round (or reducer returns no representative)
- **THEN** `zeroPointCorrection` SHALL remain unchanged
- **AND** Modbus 0090H SHALL not be updated for this round

#### Scenario: Cluster reducer invoked once per round on laser off

- **WHEN** laser turns OFF for `eventId=N`
- **THEN** the App SHALL invoke the cluster reducer exactly once with all valid samples from that round
- **AND** SHALL NOT arithmetic-mean the raw offset lists before correction mapping

### Requirement: Zero-point detect uses 500ms interval constant

The zero-point task schedule SHALL use **`AiFrameSamplingInterval.ZERO_POINT_ON_LASER`** with value **500 ms** for documentation and tests, aligned with other 500 ms AI Vision sampling constants.

#### Scenario: Constant value

- **WHEN** code reads `AiFrameSamplingInterval.ZERO_POINT_ON_LASER.getIntervalMs()`
- **THEN** the value SHALL be `500L`

### Requirement: Production zero-point offset sets immediate user alert

After aggregating valid zero-point samples, when offsets exceed position tolerance in production weld scope, the App MAY still apply incremental Modbus 0090H correction per existing requirements, and SHALL set and show the zero-point offset user alert **immediately** as specified in `production-zero-point-offset-alerts` (alarm code **H034**).

#### Scenario: Auto write and alert are not mutually exclusive

- **WHEN** a zero-point task applies incremental correction to 0090H
- **AND** offsets were outside tolerance
- **THEN** Modbus write behavior SHALL follow existing clamp and write rules
- **AND** H034 warn log and dialog MAY be shown immediately without waiting for laser OFF

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

