## MODIFIED Requirements

### Requirement: FrostSegmentedControl provides capsule segmented single-select

`FrostSegmentedControl` and `FrostSegmentedControlView` SHALL replace `ControlCapsule` + `RadioGroup` + `RadioButton` for mutually exclusive text options in a horizontal capsule. The control MUST render an outer capsule chrome aligned with `control_capsule` (dark fill, subtle border, inset padding), segment backgrounds aligned with `radiobutton_background`, and segment text colors aligned with `radiobutton_text_color`. Exactly one segment MUST be selected at a time. Unselected segments MUST be selectable by tap. The currently selected segment MUST additionally support long-press drag to move the enlarged pill and commit the nearest segment on release (see `segment-long-press-drag`).

#### Scenario: User selects a different segment by tap

- **WHEN** the user taps an unselected segment
- **THEN** that segment becomes selected with white background and dark text
- **AND** the previously selected segment returns to dark background and white text
- **AND** `FrostUiClickSoundRegistry` plays a click sound when `clickSoundEnabled` is true
- **AND** the selection listener is notified with the new index

#### Scenario: User drags from selected segment to change selection

- **WHEN** the user long-presses the currently selected segment until the pill enlarges, drags horizontally, and releases over another segment
- **THEN** the nearest segment at release becomes selected
- **AND** the selection listener is notified once on release
- **AND** arm and release click sounds play when `clickSoundEnabled` is true

#### Scenario: Programmatic selection without listener

- **WHEN** `setSelectedIndex` is called with `suppressListener` (or equivalent) while updating UI state
- **THEN** the visual selection updates
- **AND** the selection listener MUST NOT be invoked
