## MODIFIED Requirements

### Requirement: FRAME_REJECTED on either module enters shared burst sampling

On the live PR1 weld path (Quick Mode / Engineer Mode, laser ON), when the App parses a native result with `code=-5` (`OpencvDetectCodes.FRAME_REJECTED`) from **zero_point**, **edgedrawing**, or **lens_det**, the system SHALL enter **burst sampling mode** for both modules that are active on that path.

In burst mode, the frame-sampling gate interval for each active module SHALL be **100ms** (`AiFrameSamplingInterval.FRAME_REJECTED_BURST`).

#### Scenario: Zero point spot size triggers burst

- **WHEN** zero_point returns `ok=false`, `code=-5`, `reason=spot_size_above_max` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active
- **AND** subsequent live PR1 samples for lens_det and zero_point SHALL use the 100ms gate while burst is active

#### Scenario: Lens det saturation triggers burst

- **WHEN** lens_det returns `ok=false`, `code=-5`, `reason=saturated_white_area_exceeds_limit` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active for both active modules

#### Scenario: Red-frame overexposed triggers burst

- **WHEN** any active OpenCV detect module returns `ok=false`, `code=-5`, `reason=overexposed` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active
- **AND** subsequent samples SHALL use the 100ms gate while burst is active

#### Scenario: Red-frame invalid_non_red triggers burst

- **WHEN** any active OpenCV detect module returns `ok=false`, `code=-5`, `reason=invalid_non_red` on a live PR1 sample
- **THEN** burst sampling mode SHALL be active
