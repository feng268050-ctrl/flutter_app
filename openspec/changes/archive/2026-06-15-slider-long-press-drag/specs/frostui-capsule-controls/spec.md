## MODIFIED Requirements

### Requirement: FrostCapsuleSlider provides filled capsule progress slider

`FrostCapsuleSlider` and `FrostCapsuleSliderView` SHALL replace the common-settings brightness row (`SeekBar` + overlay percent text + trailing icon). The control MUST draw a capsule track filled from the left proportional to progress, with height and corner radius aligned with `capsule_seekbar_progress` (46dp / 23dp). During idle the fill edge MAY remain the sole progress indicator; during long-press arm and drag the control MUST show an enlarged logical thumb at the fill edge. The control MUST NOT support tap-to-seek: clicking the capsule track outside the thumb hit region MUST NOT change progress. Dragging MUST update progress continuously without edge magnetic snapping, but ONLY after long-press on the thumb hit region arms drag (see `slider-long-press-drag`).

#### Scenario: User long-presses then drags brightness slider

- **WHEN** the user long-presses the logical thumb at the fill edge for at least the long-press threshold, then drags horizontally
- **THEN** progress MUST update continuously to follow the touch position
- **AND** the filled capsule width MUST update continuously
- **AND** `onProgressChanged` MUST be invoked with `fromUser=true`
- **AND** arm sound MUST play when drag arms; release sound MUST play when the pointer is released after drag

#### Scenario: Short tap or track tap does not change brightness

- **WHEN** the user short-taps the fill edge or taps elsewhere on the capsule without completing long-press
- **THEN** progress MUST NOT change
- **AND** no tracking callbacks MUST fire

#### Scenario: Overlay text and icon adapt to fill width

- **WHEN** progress changes
- **THEN** the leading value label (e.g. `102%`) and optional trailing icon color interpolate between light (`#FFFFFF`) and dark (`#060720`) based on whether the fill edge has passed each overlay's center, matching existing `CommonSettingsFragment.updateBrightnessOverlayColors` behavior
