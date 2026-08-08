## MODIFIED Requirements

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound (untitled card): **Country/Region**, Language, Unit, and **Text Size** as persisted controls backed by `/var/lib/hmi/common-settings.json`; Country/Region drives wireless regulatory and region-aware timezone/NTP defaults per `region-country-settings`; Language drives Flutter UI locale and CyberIME for three locales; Text Size drives App-wide reading UI scale (`small` / `medium` / `large`) per `frostui-typography`; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: **Country/Region before Language**, then Unit, then Display, then **Text Size**, then Sound.
- RGB LED + Camera (untitled card, after Display & Sound, before Date & Time): RGB LED entry; Camera entry → product IP-camera settings page.
- Date & Time (untitled card): Automatic sync plus Set Date / Set Time / Set Time Zone via `DateTimeController` (lws-ui parity).
- Input (untitled card): mouse settings; keyboard layout; USB OTG. **Camera is not under Input** (see Camera + RGB LED group requirement).
- Operator-visible labels SHALL come from App localization. Group section titles MUST NOT be shown.

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness on Display or volume on Sound
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Screen-off invokes AutoSleep

- **WHEN** the user selects an Auto Screen Off option on the Display page other than the current policy
- **THEN** HAL `AutoSleep` is asked to set the corresponding policy and the choice is persisted

#### Scenario: Sound effect is not a stub

- **WHEN** the user selects a Sound Effect option on the Sound page
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted via `ButtonFeedback`

#### Scenario: Country/Region appears before Language

- **WHEN** the operator opens Common Settings
- **THEN** the Display & Sound card lists Country/Region above Language
- **AND** Country/Region summary reflects the persisted Country preference

#### Scenario: Language is persisted

- **WHEN** the user selects a Language option other than the current value
- **THEN** the choice is persisted in `/var/lib/hmi/common-settings.json` and Common Settings shows the matching Language summary or segment

#### Scenario: Unit is persisted

- **WHEN** the user selects a Unit option other than the current value
- **THEN** the choice is persisted in `/var/lib/hmi/common-settings.json`

#### Scenario: Text Size appears between Display and Sound

- **WHEN** the operator opens Common Settings
- **THEN** the Display & Sound card lists Text Size after Display and before Sound
- **AND** Text Size summary reflects the persisted text size preference

#### Scenario: Text Size is persisted and applies without restart

- **WHEN** the user selects Text Size `large` (or other non-current value)
- **THEN** the choice is persisted in `/var/lib/hmi/common-settings.json`
- **AND** reading UI scale updates for the current session without requiring an App process restart

#### Scenario: Date and time sync actions invoke controllers

- **WHEN** the user enables Automatic or applies a manual date/time/zone change
- **THEN** the date/time controller is asked to set the corresponding policy or wall clock

#### Scenario: Mouse settings invoke controller

- **WHEN** the user changes a mouse setting from Common Settings
- **THEN** the mouse settings controller is asked to persist and apply the value

#### Scenario: Camera is not under Input

- **WHEN** the operator opens Common Settings
- **THEN** Camera is reachable from the RGB LED + Camera card before Date & Time
- **AND** Input does not list IP Camera / Camera

#### Scenario: Common Settings chrome follows UI locale

- **WHEN** Language is `zh-CN` and the operator opens Common Settings
- **THEN** migrated row titles and control labels render in Simplified Chinese via App localization

## ADDED Requirements

### Requirement: Text Size selection lists Small Medium Large

Text Size Settings SHALL offer three options—Small, Medium, Large—mapped to wire values `small`, `medium`, and `large`. Selecting an option SHALL persist via `CommonSettingsStore` and update the App root `MediaQuery.textScaler` for reading UI. Common Settings Text Size summary MUST show the selected option label. Default when unset is Medium.

#### Scenario: Text Size page lists three options

- **WHEN** the operator opens Text Size settings
- **THEN** Small, Medium, and Large are available

#### Scenario: Default summary is Medium

- **WHEN** Text Size preference is unset or `medium` and the operator opens Common Settings
- **THEN** Text Size summary indicates Medium (or localized equivalent)
