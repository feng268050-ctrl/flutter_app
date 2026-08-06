## MODIFIED Requirements

### Requirement: Common Settings Display and Sound — Display and Sound sub-pages

Within Common Settings, Language and Unit remain as list/nav rows. **Brightness** and **Auto Screen Off** SHALL be merged into a single **Display** nav row. **Volume** and **Sound Effect** SHALL be merged into a single **Sound** nav row. Display SHALL provide Brightness via `CyberSlider` (drag-value chrome) → HAL `Backlight`, and Auto Screen Off as a dropdown → HAL `AutoSleep`. Sound SHALL provide Volume via left-label / right `CyberVolumeSlider` (speaker icons retained; no play-test card) → HAL media audio, and Sound Effect as a dropdown → `ButtonFeedback` / sound-effect store. Language SHALL continue to offer **three** App locales (`en-US`, `zh-CN`, `zh-TW`). Power Mode / load-profile selection MUST NOT live on the Display sub-page (see Power Mode requirement).

#### Scenario: Display opens brightness and screen-off

- **WHEN** the operator opens Common Settings → Display
- **THEN** Brightness can be adjusted with a CyberSlider
- **AND** Auto Screen Off can be chosen from a dropdown without a separate screen-off page
- **AND** the Display page MUST NOT host the Power Mode / performance / balanced selector

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

- Display & Sound (untitled card): Language and Unit as persisted controls backed by `/var/lib/hmi/common-settings.json`; Language drives Flutter UI locale and CyberIME for three locales; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: Language and Unit before Display before Sound.
- **Power Mode** (untitled card, **own group**, after Display & Sound and before RGB LED + Camera): a single nav row (same chrome pattern as **Unit**) with trailing summary of the current mode; tapping opens a Power Mode sub-page (see ADDED requirement). Persistence remains `/var/lib/hal/power.conf` via HAL (not `common-settings.json`).
- RGB LED + Camera (untitled card, after Power Mode, before Date & Time): RGB LED entry; Camera entry → product IP-camera settings page.
- Date & Time (untitled card): Automatic sync plus Set Date / Set Time / Set Time Zone via `DateTimeController` (lws-ui parity).
- Input (untitled card): mouse settings; keyboard layout; USB OTG. **Camera is not under Input** (see Camera + RGB LED group requirement).
- Operator-visible labels SHALL come from App localization. Group section titles MUST NOT be shown.

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness on Display or volume on Sound
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Screen-off invokes AutoSleep

- **WHEN** the user selects an Auto Screen Off option on the Display page other than the current policy
- **THEN** HAL `AutoSleep` is asked to set the corresponding policy and the choice is persisted

#### Scenario: Power Mode group is separate from Display and Sound

- **WHEN** the operator opens Common Settings
- **THEN** Power Mode appears as its own untitled card (not a row inside Display & Sound)
- **AND** that card is after Display & Sound and before RGB LED + Camera

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

## ADDED Requirements

### Requirement: Common Settings Power Mode nav opens a Unit-style sub-page

Common Settings SHALL present **Power Mode** (localized; en: Power Mode; zh-CN: 效能模式) as a **SettingsNavRow** in its own untitled card. The row SHALL show a trailing summary of the active profile (Performance / Balanced, localized 性能 / 均衡). Tapping SHALL push a dedicated Power Mode settings sub-page (same navigation chrome pattern as **Unit** → `UnitSettingsPage`). The sub-page SHALL list the two options `performance` and `balanced` for selection. Selecting an option SHALL call the HAL load-profile API (persist + apply) and update the in-App continuous-paint policy; the Common Settings trailing summary SHALL refresh to match. Operator-facing copy MUST NOT present the mode primarily as energy saving / 省电.

#### Scenario: Power Mode opens sub-page like Unit

- **WHEN** the operator taps Power Mode on Common Settings
- **THEN** a Power Mode sub-page opens (not an inline dropdown on the Common Settings list)
- **AND** the navigation pattern matches Unit (nav row → push settings page)

#### Scenario: Sub-page lists performance and balanced

- **WHEN** the operator opens the Power Mode sub-page
- **THEN** Performance (性能) and Balanced (均衡) options are available
- **AND** selecting Balanced invokes HAL setMode(`balanced`) and persists `/var/lib/hal/power.conf`
- **AND** returning to Common Settings shows the Balanced trailing summary
