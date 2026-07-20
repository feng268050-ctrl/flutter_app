## MODIFIED Requirements

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound: screen brightness via backlight controller; media volume via media audio controller using **Cyber volume chrome** where CyberUI is available; language / unit / screen-off rows MAY remain UI stubs when no platform store exists yet; **sound-effect SHALL be a real Effect 1/2/3 control with persistence** (see `settings-sound-effect`)
- Date & Time: wall clock, manual vs network sync, timezone, Apply / Sync Now via `DateTimeController`
- Input: mouse settings via `MouseSettingsController`; keyboard layout / smoke affordances via keyboard HAL as applicable

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness or volume in Common Settings
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Volume page uses Cyber volume chrome

- **WHEN** the user opens Volume under Display & Sound
- **THEN** the volume control is rendered with CyberUI volume chrome (not a bare Material-only Settings stand-in as the long-term target)

#### Scenario: Sound effect is not a stub

- **WHEN** the user opens Sound Effect under Display & Sound
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted

#### Scenario: Date and time sync actions invoke controller

- **WHEN** the user taps Apply or Sync Now in Date & Time
- **THEN** the date/time controller is asked to set the clock or sync from the network

#### Scenario: Mouse settings invoke controller

- **WHEN** the user changes a mouse setting in Common Settings
- **THEN** the mouse settings controller is asked to persist and apply the value

### Requirement: Settings shell uses four fixed tabs

The product Settings screen SHALL present four top-level tabs in this order, matching lws-ui Device Settings structure:

1. Device Information
2. Common Settings
3. Advanced Settings
4. Custom Home Page

UI chrome MAY use Material widgets where CyberUI counterparts are not yet available. New frost / volume / sound-effect chrome introduced by this change SHALL use CyberUI. Settings MUST NOT block app first paint on the Home route.

#### Scenario: Four tabs visible

- **WHEN** the user opens Settings
- **THEN** the four tab labels are visible in the order listed above

#### Scenario: CyberUI used for new audio chrome

- **WHEN** Settings Volume or Sound Effect surfaces introduced by this change are rendered
- **THEN** they use CyberUI widgets for volume chrome / effect selection rather than inventing a parallel glass kit
