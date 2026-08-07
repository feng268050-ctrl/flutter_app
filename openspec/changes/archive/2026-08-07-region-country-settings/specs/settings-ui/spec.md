## MODIFIED Requirements

### Requirement: Common Settings exposes display, sound, date-time, and input controls

Common Settings SHALL expose:

- Display & Sound (untitled card): **Country**, Language, and Unit as persisted controls backed by `/var/lib/hmi/common-settings.json`; Country drives wireless regulatory and region-aware timezone/NTP defaults per `region-country-settings`; Language drives Flutter UI locale and CyberIME for three locales; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: **Country before Language**, then Unit, then Display, then Sound.
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

#### Scenario: Country appears before Language

- **WHEN** the operator opens Common Settings
- **THEN** the Display & Sound card lists Country above Language
- **AND** Country summary reflects the persisted Country preference

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

#### Scenario: Common Settings chrome follows UI locale

- **WHEN** Language is `zh-CN` and the operator opens Common Settings
- **THEN** migrated row titles and control labels render in Simplified Chinese via App localization

## ADDED Requirements

### Requirement: Country selection lists all markets and applies region effects

Country Settings SHALL list the full ISO 3166-1 alpha-2 country/territory catalog (plus `XK`) with human-readable labels (English / Simplified Chinese by UI locale) and search. Selecting a country SHALL persist via `CommonSettingsStore` and trigger region apply (wireless regulatory and Country-linked timezone/NTP defaults). Common Settings Country summary MUST show the selected country label (or code). Country MUST appear as a nav row before Language on the Common Settings Display & Sound card.

#### Scenario: Country page lists options with US default summary

- **WHEN** Country preference is `US` and the operator opens Common Settings
- **THEN** Country summary indicates United States (or localized equivalent)
- **AND** opening Country Settings shows `US` among the selectable options

#### Scenario: Selecting Germany updates summary and apply path

- **WHEN** the operator selects Germany (`DE`) on Country Settings
- **THEN** the choice is persisted
- **AND** Common Settings Country summary shows the matching label
- **AND** region apply runs for regulatory / linked clock defaults
