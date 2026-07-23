## MODIFIED Requirements

### Requirement: Parse offset_x and compute UI correction with inverted sign

Native JSON SHALL expose at minimum `ok`, `code`, `reason` (when `ok` is false), `offset_x`, and `offset_y`. The `code` field MUST follow the shared OpenCV detect table in `opencv-detect-error-codes` (for example `-5` with `reason=spot_size_above_max` for spot-size rejection, not a module-specific `-5` meaning).

For samples with **`ok == true`**, the App SHALL read **`offset_x`** (pixels, detected minus reference). UI zero correction uses **1 unit = 3px** with **+ = move zero right** and **− = move zero left**. The App SHALL compute per-sample UI delta as:

**`uiDelta = round(-offset_x / 3.0)`**

(JSON negative → UI increases; JSON positive → UI decreases.)

#### Scenario: Negative offset_x increases UI value

- **WHEN** a valid sample returns `offset_x = -9.0`
- **THEN** `uiDelta` SHALL be `+3`

#### Scenario: Positive offset_x decreases UI value

- **WHEN** a valid sample returns `offset_x = +12.0`
- **THEN** `uiDelta` SHALL be `-4`

#### Scenario: Spot size rejection uses unified FRAME_REJECTED

- **WHEN** native returns `ok=false`, `code=-5`, `reason=spot_size_above_max`
- **THEN** the App MUST treat the sample as failed detection
- **AND** `sample_fail` logs MUST include both `code` and `reason`
