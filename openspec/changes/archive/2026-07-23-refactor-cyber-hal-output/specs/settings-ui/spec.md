## MODIFIED Requirements

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound: screen brightness via HAL `Backlight`; screen-off time via HAL `AutoSleep` (real control, not a non-persisted stub); media volume via media audio / `Volume` using **Cyber volume chrome** where CyberUI is available; language / unit rows MAY remain UI stubs when no platform store exists yet; **sound-effect SHALL be a real Effect 1/2/3 control** wired through HAL `ButtonFeedback` (see `settings-sound-effect` / `hal-button-feedback`). Within the main Display & Sound settings group, display controls (brightness, screen-off) SHALL appear before sound controls (volume, sound-effect).
- Date & Time: wall clock, manual vs network sync, timezone, Apply / Sync Now via `DateTimeController`
- Input: mouse settings via `MouseSettingsController`; keyboard layout / smoke affordances via keyboard HAL as applicable; **IP Camera** entry that navigates to a live preview page backed by the product IP-camera session (HAL `ip_camera` + this product’s path/relay)

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness or volume in Common Settings
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Screen-off invokes AutoSleep

- **WHEN** the user selects a Screen-off Time option other than the current policy
- **THEN** HAL `AutoSleep` is asked to set the corresponding policy and the choice is persisted

#### Scenario: Volume page uses Cyber volume chrome

- **WHEN** the user opens Volume under Display & Sound
- **THEN** the volume control is rendered with CyberUI volume chrome (not a bare Material-only Settings stand-in as the long-term target)

#### Scenario: Sound effect is not a stub

- **WHEN** the user opens Sound Effect under Display & Sound
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted via `ButtonFeedback`

#### Scenario: Date and time sync actions invoke controllers

- **WHEN** the user taps Apply or Sync Now in Date & Time
- **THEN** the date/time controller is asked to set the clock or sync from the network

#### Scenario: Mouse settings invoke controller

- **WHEN** the user changes a mouse setting in Common Settings
- **THEN** the mouse settings controller is asked to persist and apply the value

#### Scenario: Input lists IP Camera

- **WHEN** the operator opens Common Settings
- **THEN** an IP Camera row SHALL be available under Input alongside Mouse and Keyboard

### Requirement: Display & Sound includes RGB LED controls

Common Settings SHALL include an RGB LED entry under the Display & Sound **section** that opens controls for Red, Yellow, and Green modes (Steady / Blink / Off), wired to the GPIO RGB LED controller. The RGB LED entry MUST appear **after** the main Display & Sound settings group (the card that contains brightness / screen-off / volume / sound-effect), not as a mid-group row among those controls. LED I/O MUST NOT block Home first paint.

#### Scenario: LED entry after display-sound group

- **WHEN** the user opens Display & Sound in Common Settings
- **THEN** an RGB LED (or equivalent) entry is available after the main Display & Sound settings group

#### Scenario: LED mode invokes GPIO controller

- **WHEN** the user selects Steady on the Green LED control from Settings
- **THEN** the GPIO LED controller is asked to set Green to Steady
