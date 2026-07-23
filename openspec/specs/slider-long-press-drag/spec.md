# slider-long-press-drag Specification

## Purpose

Long-press thumb drag interaction for `FrostSlider` / `FrostSliderView` to prevent accidental value changes in advanced settings. Capsule and flanked slider variants are out of scope and retain direct drag.

## Requirements

### Requirement: Slider long-press drag state machine

`FrostSlider` and `FrostSliderView` with `longPressDragEnabled=true` (default) SHALL implement a long-press-to-arm drag interaction. Each slider instance MUST maintain isolated gesture state. The state machine MUST expose `isValueArmed` internally: false until long-press threshold is met on the thumb hit region; true only after threshold while the pointer remains down; false again on pointer up or cancel.

#### Scenario: Track tap does not arm drag

- **WHEN** the user taps anywhere on the slider track outside the thumb hit region
- **THEN** `isValueArmed` MUST remain false
- **AND** progress MUST NOT change
- **AND** no arm or release sound MUST play

#### Scenario: Short thumb tap does not change value

- **WHEN** the user presses down on the thumb hit region and releases before the long-press threshold (~400 ms)
- **THEN** progress MUST NOT change
- **AND** `isValueArmed` MUST never become true
- **AND** no arm or release sound MUST play

#### Scenario: Long-press on thumb arms drag

- **WHEN** the user keeps a single pointer down on the thumb hit region for at least the long-press threshold
- **THEN** `isValueArmed` MUST become true after thumb expand animation completes
- **AND** the thumb MUST animate to enlarged scale (approximately 1.25× to 1.4×, default 1.3×)
- **AND** an arm sound MUST play via `FrostUiClickSoundRegistry`

#### Scenario: Drag after arm updates value continuously

- **WHEN** `isValueArmed` is true and the user moves the pointer horizontally
- **THEN** progress MUST update continuously using delta-based fraction mapping from the arm activation X
- **AND** `onProgressChange` MUST be invoked with `fromUser=true`
- **AND** bipolar sliders MAY apply center snap per configured threshold and escape distance

#### Scenario: Release disarms and restores thumb

- **WHEN** the user releases the pointer after an armed drag session
- **THEN** `isValueArmed` MUST become false
- **AND** thumb scale MUST animate back to normal
- **AND** a release sound MUST play via `FrostUiClickSoundRegistry`
- **AND** `onStopTracking` MUST be invoked if a drag session had started

#### Scenario: Multiple sliders on one screen are independent

- **WHEN** two or more `FrostSliderView` instances are visible and the user long-presses the thumb on one slider only
- **THEN** only that slider MUST enter `isValueArmed=true`
- **AND** other sliders MUST remain idle with unchanged progress

#### Scenario: Long-press disabled uses direct drag

- **WHEN** `longPressDragEnabled` is false (for example embedded in `FrostFlankedSliderView`)
- **THEN** press and drag on the track MUST update progress immediately without long-press arming
- **AND** center snap MUST NOT apply
