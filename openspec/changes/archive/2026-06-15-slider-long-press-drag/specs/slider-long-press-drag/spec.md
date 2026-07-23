## ADDED Requirements

### Requirement: Slider long-press drag state machine

Frostui linear and capsule sliders SHALL implement a shared long-press-to-arm drag interaction. Each slider instance MUST maintain isolated gesture state. The state machine MUST expose `draggingEnabled` internally: false until long-press threshold is met on the thumb hit region; true only after threshold while the pointer remains down; false again on pointer up or cancel.

#### Scenario: Track tap does not arm drag

- **WHEN** the user taps anywhere on the slider track outside the thumb hit region
- **THEN** `draggingEnabled` MUST remain false
- **AND** progress MUST NOT change
- **AND** no arm or release sound MUST play

#### Scenario: Short thumb tap does not change value

- **WHEN** the user presses down on the thumb hit region and releases before the long-press threshold (~400 ms)
- **THEN** progress MUST NOT change
- **AND** `draggingEnabled` MUST never become true
- **AND** no arm or release sound MUST play

#### Scenario: Long-press on thumb arms drag

- **WHEN** the user keeps a single pointer down on the thumb hit region for at least the long-press threshold
- **THEN** `draggingEnabled` MUST become true
- **AND** the thumb MUST animate to enlarged scale (approximately 1.25× to 1.4×, default 1.3×)
- **AND** an arm sound MUST play via `FrostUiClickSoundRegistry`

#### Scenario: Drag after arm updates value continuously

- **WHEN** `draggingEnabled` is true and the user moves the pointer horizontally
- **THEN** progress MUST update continuously from horizontal position using the slider's existing fraction mapping
- **AND** `onProgressChange` MUST be invoked with `fromUser=true`

#### Scenario: Release disarms and restores thumb

- **WHEN** the user releases the pointer after an armed drag session
- **THEN** `draggingEnabled` MUST become false
- **AND** thumb scale MUST animate back to normal
- **AND** a release sound MUST play via `FrostUiClickSoundRegistry`
- **AND** `onStopTracking` MUST be invoked if a drag session had started

#### Scenario: Multiple sliders on one screen are independent

- **WHEN** two or more sliders are visible and the user long-presses the thumb on one slider only
- **THEN** only that slider MUST enter `draggingEnabled=true`
- **AND** other sliders MUST remain idle with unchanged progress
