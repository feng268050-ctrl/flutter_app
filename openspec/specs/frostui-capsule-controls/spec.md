# frostui-capsule-controls Specification

## Purpose
TBD - created by archiving change frostui-capsule-controls. Update Purpose after archive.
## Requirements
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

### Requirement: FrostCapsuleSlider provides filled capsule progress slider

`FrostCapsuleSlider` and `FrostCapsuleSliderView` SHALL replace the common-settings brightness row (`SeekBar` + overlay percent text + trailing icon). The control MUST draw a capsule track filled from the left proportional to progress, with height and corner radius aligned with `capsule_seekbar_progress` (46dp / 23dp). The thumb MUST be invisible (transparent), matching `seekbar_thumb_v2`. Dragging MUST update progress continuously without edge magnetic snapping.

#### Scenario: User drags brightness slider

- **WHEN** the user presses and drags horizontally on the capsule slider
- **THEN** progress updates immediately to follow the touch position
- **AND** the filled capsule width updates continuously
- **AND** `onProgressChanged` is invoked with `fromUser=true`
- **AND** a click sound plays on start tracking

#### Scenario: Overlay text and icon adapt to fill width

- **WHEN** progress changes
- **THEN** the leading value label (e.g. `102%`) and optional trailing icon color interpolate between light (`#FFFFFF`) and dark (`#060720`) based on whether the fill edge has passed each overlay's center, matching existing `CommonSettingsFragment.updateBrightnessOverlayColors` behavior

### Requirement: Common settings display-and-sound rows migrate to Frost capsule controls

After migration, `fragment_common_settings.xml` rows for language, unit, screen brightness, screen-off time, and sound effect MUST use `FrostSegmentedControlView` or `FrostCapsuleSliderView` instead of `ControlCapsule` with `RadioGroup`/`SeekBar` children. `ControlCapsule.java` MUST be deleted when no references remain.

#### Scenario: Common settings page compiles and binds

- **WHEN** `CommonSettingsFragment` loads
- **THEN** language, unit, screen-off, and sound-effect rows bind via `FrostSegmentedControlView` index APIs
- **AND** brightness binds via `FrostCapsuleSliderView` seek-bar-compatible listener
- **AND** grep for `com.lasercyber.lws.ui.component.layout.ControlCapsule` returns no production references

### Requirement: Frost capsule controls use frostui control tokens

Capsule segmented and capsule slider appearance MUST be driven by `frostui_control_colors.xml`, `frostui_control_dimens.xml`, and `frostui_control_attrs.xml` extensions. The `frostui` package MUST NOT depend on `com.lasercyber.lws.ui`.

#### Scenario: Token resolution from resources

- **WHEN** a `FrostSegmentedControlView` is inflated from XML with default style
- **THEN** segment and capsule colors resolve from `frostui_control_*` resources without importing `ui` package classes

