## ADDED Requirements

### Requirement: Demo exposes audio play control and volume slider

The P2/P2.1 demo home SHALL include a control to play/stop the bundled `shanghai_tan.mp3` test track and a volume slider spanning 0–100 that calls the media audio controller. Play/stop and volume changes MUST NOT block first-frame paint.

#### Scenario: Play invokes media audio controller

- **WHEN** the user taps Play (while idle)
- **THEN** the media audio controller is asked to play the shanghai tan asset

#### Scenario: Volume slider sets percent

- **WHEN** the user moves the volume slider to 40
- **THEN** the media audio controller is asked to set volume percent 40

### Requirement: Demo exposes brightness slider

The demo home SHALL include a brightness slider spanning 0–100 that calls the backlight controller. The slider SHOULD initialize from a successful backlight get after first frame when available.

#### Scenario: Brightness slider sets percent

- **WHEN** the user moves the brightness slider to 25
- **THEN** the backlight controller is asked to set brightness percent 25

### Requirement: Demo exposes exclusive portrait/landscape controls

The demo home SHALL provide a mutually exclusive Portrait / Landscape control group. Selecting one MUST deselect the other. Selecting a mode SHALL call the display-orientation API for that mode.

#### Scenario: Exclusive orientation selection

- **WHEN** the user selects Portrait while Landscape was selected
- **THEN** Portrait is selected (not Landscape) and the orientation API is asked to set portrait

#### Scenario: Initial selection matches preference

- **WHEN** the demo screen first appears and the persisted preference is landscape
- **THEN** the Landscape control is the selected mode
