# laser-detect-frame-rejected-burst Specification

## Purpose
TBD - created by archiving change laser-detect-sampling-alignment. Update Purpose after archive.
## Requirements
### Requirement: FRAME_REJECTED on either module enters shared burst sampling

On the live PR1 weld path (Quick Mode / Engineer Mode, laser ON), when the native pipeline or Java-mapped result has `code=-5` (`OpencvDetectCodes.FRAME_REJECTED`) from **zero_point**, **edgedrawing**, or **lens_det**, the system SHALL enter **burst sampling mode** for both modules that are active on that path. Burst scheduling authority SHALL reside in **`StreamDetectPipeline`**; Java MAY notify burst exit via control JNI when required but MUST NOT independently gate live PR1 I420 frames for burst.

In burst mode, the native frame-sampling interval for each active module SHALL be **100ms** (`AiFrameSamplingInterval.FRAME_REJECTED_BURST`).

#### Scenario: Zero point spot size triggers burst

- **WHEN** zero_point returns `ok=false`, `code=-5`, `reason=spot_size_above_max` on a live PR1 sample from the native pipeline
- **THEN** burst sampling mode SHALL be active in native scheduling
- **AND** subsequent live PR1 samples for lens_det and zero_point SHALL use the 100ms gate while burst is active

#### Scenario: Lens det saturation triggers burst

- **WHEN** lens_det returns `ok=false`, `code=-5`, `reason=saturated_white_area_exceeds_limit` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active for both active modules in the native pipeline

#### Scenario: Red-frame overexposed triggers burst

- **WHEN** any active OpenCV detect module returns `ok=false`, `code=-5`, `reason=overexposed` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active
- **AND** subsequent samples SHALL use the 100ms gate while burst is active

#### Scenario: Red-frame invalid_non_red triggers burst

- **WHEN** any active OpenCV detect module returns `ok=false`, `code=-5`, `reason=invalid_non_red` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active

### Requirement: Burst exits when both modules have succeeded

The native pipeline SHALL exit burst sampling mode and restore normal gate intervals when, **since entering the current burst**, **lens_det** has produced at least one result with `ok=true` and `code=0` **and** **zero_point** has produced at least one result with `ok=true` and `code=0`.

After exit, lens_det SHALL use `LIVE_WELD` (**500ms**) and zero_point SHALL use `ZERO_POINT_ON_LASER` (**500ms**) until the next burst entry.

#### Scenario: Both succeed restores normal intervals

- **WHEN** burst mode is active in the native pipeline
- **AND** lens_det returns `code=0` on one sample
- **AND** zero_point returns `code=0` on one sample (order arbitrary)
- **THEN** burst mode SHALL end in native scheduling
- **AND** the next accepted lens_det sample MUST be at least 500ms after the last accepted lens_det sample in normal mode

#### Scenario: Laser off cancels burst

- **WHEN** laser turns OFF while burst mode is active
- **THEN** burst mode SHALL reset to normal in the native pipeline
- **AND** all live PR1 sampling state SHALL reset

### Requirement: Single active module burst exit

When only one of zero_point or lens_det is active on the live PR1 path, burst mode in the native pipeline SHALL exit when that active module alone has returned `code=0` at least once since entering burst.

#### Scenario: Lens det disabled

- **WHEN** OpenCV stain detect session is not active
- **AND** zero_point enters burst from `code=-5`
- **THEN** burst SHALL exit when zero_point alone returns `code=0` in the native pipeline

