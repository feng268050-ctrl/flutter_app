# cyber-ui-controls Specification

## Purpose
TBD - created by archiving change cyber-ui-frost-parity. Update Purpose after archive.
## Requirements
### Requirement: Binary controls with click sound

CyberUI SHALL provide `CyberSwitch` and `CyberCheckbox` (names may match package conventions) that honor `clickSoundEnabled` (default true) via `CyberClickSoundRegistry.playClick()` on activation, aligned with lws-ui Frost switch/checkbox behavior.

#### Scenario: Switch toggle plays click when enabled

- **WHEN** a registered click backend exists and the user toggles a Cyber switch with click sound enabled
- **THEN** `playClick()` is invoked

### Requirement: Slider family

CyberUI SHALL provide a core `CyberSlider` (and keep/align `CyberVolumeSlider` / flanked variants) for 0–N integer or continuous progress with App-supplied callbacks. Long-press-drag parity with Frost MAY be phased; v1 MUST support ordinary drag.

#### Scenario: Slider reports progress

- **WHEN** the user drags a Cyber slider
- **THEN** the App progress callback receives updated values within the configured min/max

### Requirement: Segmented control and numeric stepper

CyberUI SHALL provide segmented selection and numeric stepper controls with optional click sound on commit, suitable for Settings rows (e.g. sound-effect / discrete options).

#### Scenario: Segment selection commits

- **WHEN** the user selects a segment
- **THEN** the selection callback fires with the new index/value

### Requirement: Capsule, hold-confirm, and ripple

CyberUI SHALL provide capsule slider chrome, hold-to-confirm interaction, and press/ripple feedback primitives aligned with lws-ui `control/` (simplified visuals allowed). These MUST remain presentation + gesture logic only (no HAL).

#### Scenario: Hold-confirm completes after duration

- **WHEN** the user holds a hold-confirm control for the configured duration
- **THEN** the confirm callback fires once

### Requirement: Checkbox face size tiers for product callers

CyberUI SHALL expose checkbox face sizes only as `CyberDimens.checkboxSmallSize` and `CyberDimens.checkboxLargeSize`. Product App call sites that show operator checkboxes SHALL use these tiers (large = 28 for product toggles and don’t-show-again). Product code MUST NOT invent additional face sizes for `CyberCheckbox`.

#### Scenario: Large tier is twenty-eight

- **WHEN** a product surface requests the large checkbox tier
- **THEN** the face edge length is 28 logical pixels

