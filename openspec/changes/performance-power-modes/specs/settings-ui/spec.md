## MODIFIED Requirements

### Requirement: Common Settings Display and Sound — Display and Sound sub-pages

Within Common Settings, Language and Unit remain as list/nav rows. **Brightness** and **Auto Screen Off** SHALL be merged into a single **Display** nav row. **Volume** and **Sound Effect** SHALL be merged into a single **Sound** nav row. Display SHALL provide Brightness via `CyberSlider` (drag-value chrome) → HAL `Backlight`, Auto Screen Off as a dropdown → HAL `AutoSleep`, and a **load / thermal profile** control (性能 / 均衡, tokens `performance` / `balanced`) → HAL load-profile API. Sound SHALL provide Volume via left-label / right `CyberVolumeSlider` (speaker icons retained; no play-test card) → HAL media audio, and Sound Effect as a dropdown → `ButtonFeedback` / sound-effect store. Language SHALL continue to offer **three** App locales (`en-US`, `zh-CN`, `zh-TW`).

#### Scenario: Display opens brightness and screen-off

- **WHEN** the operator opens Common Settings → Display
- **THEN** Brightness can be adjusted with a CyberSlider
- **AND** Auto Screen Off can be chosen from a dropdown without a separate screen-off page

#### Scenario: Display exposes performance and balanced

- **WHEN** the operator opens Common Settings → Display
- **THEN** a control offers performance (性能) and balanced (均衡) options (localized)
- **AND** selecting an option invokes the HAL load-profile API
- **AND** labels MUST NOT present the mode primarily as energy saving / 省电

#### Scenario: Sound opens volume and sound effect

- **WHEN** the operator opens Common Settings → Sound
- **THEN** Volume uses a left-label / right speaker-flanked CyberVolumeSlider
- **AND** Sound Effect can be chosen from a dropdown
- **AND** no music play-test card is shown

#### Scenario: Brightness invokes Backlight

- **WHEN** the operator changes Brightness on the Display page
- **THEN** HAL `Backlight` is asked to set the corresponding percent

#### Scenario: Language still lists three locales

- **WHEN** the operator changes Language on Common Settings
- **THEN** English, 简体中文, and 繁体中文 remain available
- **AND** the choice persists via `CommonSettingsStore` and updates UI locale

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound (untitled card): Language and Unit as persisted controls backed by `/var/lib/hmi/common-settings.json`; Language drives Flutter UI locale and CyberIME for three locales; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`) + load profile (性能 / 均衡 / HAL load-profile); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: Language and Unit before Display before Sound.
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

#### Scenario: Load profile invokes HAL

- **WHEN** the user selects balanced (均衡) on the Display page other than the current mode
- **THEN** the HAL load-profile API is asked to set `balanced` and the choice is persisted under `/var/lib/hal/power.conf`

#### Scenario: Sound effect is not a stub

- **WHEN** the user selects a Sound Effect option on the Sound page
- **THEN** Effect 1 / Effect 2 / Effect 3 are selectable and the choice is persisted via `ButtonFeedback`

#### Scenario: Language is persisted

- **WHEN** the user selects a Language option other than the current value
- **THEN** the choice is persisted in `/var/lib/hmi/common-settings.json` and Common Settings shows the matching Language summary or segment

#### Scenario: Unit is persisted

- **WHEN** the user selects a Unit option other than the current value
- **THEN** the choice is persisted in `/var/lib/hmi/common-settings.json`

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
