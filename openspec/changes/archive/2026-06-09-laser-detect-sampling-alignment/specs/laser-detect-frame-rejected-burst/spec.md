## ADDED Requirements

### Requirement: FRAME_REJECTED on either module enters shared burst sampling

On the live PR1 weld path (Quick Mode / Engineer Mode, laser ON), when the App parses a native result with `code=-5` (`OpencvDetectCodes.FRAME_REJECTED`) from **zero_point** or **lens_det**, the system SHALL enter **burst sampling mode** for both modules that are active on that path.

In burst mode, the frame-sampling gate interval for each active module SHALL be **100ms** (`AiFrameSamplingInterval.FRAME_REJECTED_BURST`).

#### Scenario: Zero point spot size triggers burst

- **WHEN** zero_point returns `ok=false`, `code=-5`, `reason=spot_size_above_max` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active
- **AND** subsequent live PR1 samples for lens_det and zero_point SHALL use the 100ms gate while burst is active

#### Scenario: Lens det saturation triggers burst

- **WHEN** lens_det returns `ok=false`, `code=-5`, `reason=saturated_white_area_exceeds_limit` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active for both active modules

### Requirement: Burst exits when both modules have succeeded

The system SHALL exit burst sampling mode and restore normal gate intervals when, **since entering the current burst**, **lens_det** has produced at least one result with `ok=true` and `code=0` **and** **zero_point** has produced at least one result with `ok=true` and `code=0`.

After exit, lens_det SHALL use `LIVE_WELD` (**500ms**) and zero_point SHALL use `ZERO_POINT_ON_LASER` (**500ms**) until the next burst entry.

#### Scenario: Both succeed restores normal intervals

- **WHEN** burst mode is active
- **AND** lens_det returns `code=0` on one sample
- **AND** zero_point returns `code=0` on one sample (order arbitrary)
- **THEN** burst mode SHALL end
- **AND** the next accepted lens_det sample MUST be at least 500ms after the last accepted lens_det sample in normal mode (gate reset on mode transition)

#### Scenario: Laser off cancels burst

- **WHEN** laser turns OFF while burst mode is active
- **THEN** burst mode SHALL reset to normal
- **AND** all live PR1 sampling gates SHALL reset

### Requirement: Single active module burst exit

When only one of zero_point or lens_det is active on the live PR1 path, burst mode SHALL exit when that active module alone has returned `code=0` at least once since entering burst.

#### Scenario: Lens det disabled

- **WHEN** OpenCV stain detect session is not active
- **AND** zero_point enters burst from `code=-5`
- **THEN** burst SHALL exit when zero_point alone returns `code=0`
