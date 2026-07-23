## ADDED Requirements

### Requirement: Slider long-press arm and drag release use click sound registry

When a frostui slider (`FrostSlider` or `FrostCapsuleSlider`) completes long-press arming or ends an armed drag session, the control MUST invoke `FrostUiClickSoundRegistry` for audible feedback. Short taps on the thumb that do not reach the long-press threshold MUST NOT play click sound. Track taps outside the thumb MUST NOT play click sound.

#### Scenario: Arm sound on long-press threshold

- **WHEN** the user holds the slider thumb until the long-press threshold elapses and drag becomes enabled
- **THEN** the slider MUST call `FrostUiClickSoundRegistry` exactly once for the arm event
- **AND** frostui MUST NOT reference `GlobalSoundManager` directly

#### Scenario: Release sound after armed drag

- **WHEN** the user releases the pointer after dragging while `draggingEnabled` was true
- **THEN** the slider MUST call `FrostUiClickSoundRegistry` exactly once for the release event

#### Scenario: Short thumb tap is silent

- **WHEN** the user releases the thumb before the long-press threshold without arming drag
- **THEN** no click sound MUST play
