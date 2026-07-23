## ADDED Requirements

### Requirement: FrostSegmentedControl long-press arm and drag release use click sound registry

When `FrostSegmentedControl` or `FrostSegmentedControlView` has `clickSoundEnabled=true`, long-press arming on the selected segment and release after an armed drag session MUST invoke `FrostUiClickSoundRegistry`. Tap selection on an unselected segment MUST continue to play a single click sound. Short press on the selected segment without arming MUST NOT play sound.

#### Scenario: Arm sound on segment long-press threshold

- **WHEN** the user holds the selected segment until the long-press threshold elapses and the pill expands
- **THEN** the control MUST call `FrostUiClickSoundRegistry` exactly once for the arm event
- **AND** frostui MUST NOT reference `GlobalSoundManager` directly

#### Scenario: Release sound after armed segment drag

- **WHEN** the user releases the pointer after dragging while selection was armed
- **THEN** the control MUST call `FrostUiClickSoundRegistry` exactly once for the release event

#### Scenario: Segment row with click sound disabled

- **WHEN** `frostClickSoundEnabled` is false on the view (for example sound-effect preset row)
- **THEN** neither tap nor long-press arm/release MUST play click sound
