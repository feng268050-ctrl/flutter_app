## MODIFIED Requirements

### Requirement: Language selection applies UI locale and lists supported endonyms

Language Settings SHALL offer the App-supported locales `en-US`, `zh-CN`, and `zh-TW` with endonym labels (English / 简体中文 / 繁體中文). Selecting a locale SHALL persist via **HAL locale PreferredLanguage** (`package:cyber_hal/locale.dart`, key `language` in `/var/lib/hal/locale.conf`) and apply both Flutter UI locale and CyberIME language mapping. Language Settings and General (Common Settings) Language summary MUST NOT claim that Language applies only to the soft keyboard once UI localization for that surface has shipped.

#### Scenario: Language page lists three locales

- **WHEN** the operator opens Language Settings
- **THEN** English, 简体中文, and 繁體中文 options are available

#### Scenario: Selecting Simplified Chinese updates UI and summary

- **WHEN** the operator selects 简体中文
- **THEN** the choice is persisted in `locale.conf`
- **AND** General Settings Language summary shows the matching endonym
- **AND** migrated Settings chrome uses Simplified Chinese strings

### Requirement: Common Settings exposes display, sound, date-time, and input controls

General Settings (Common Settings; en label **General**) SHALL expose:

- Display & Sound (untitled card): **Country/Region**, Language, and Unit as persisted controls backed by **`/var/lib/hal/locale.conf`** through HAL locale (`Region` / `region`, `PreferredLanguage` / `language`, `UnitSystem` / `unit`); Country/Region drives wireless regulatory and region-aware timezone/NTP defaults per `region-country-settings` / `hal-locale`; Language drives Flutter UI locale and CyberIME for three locales; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: **Country/Region before Language**, then Unit, then Display, then Sound.
- **Power Mode** (untitled card, **own group**, after Display & Sound and before RGB LED + Camera): a single nav row (same chrome pattern as **Unit**) with trailing summary of the current mode; tapping opens a Power Mode sub-page (see Power Mode requirement). Persistence remains `/var/lib/hal/power.conf` via HAL (not `common-settings.json` / not `locale.conf` for power).
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

#### Scenario: Country/Region appears before Language

- **WHEN** the operator opens Common Settings
- **THEN** the Display & Sound card lists Country/Region above Language
- **AND** Country/Region summary reflects the persisted Region preference

#### Scenario: Language is persisted

- **WHEN** the user selects a Language option other than the current value
- **THEN** the choice is persisted in `/var/lib/hal/locale.conf` via HAL locale and Common Settings shows the matching Language summary or segment

#### Scenario: Unit is persisted

- **WHEN** the user selects a Unit option other than the current value
- **THEN** the choice is persisted in `/var/lib/hal/locale.conf` via HAL locale UnitSystem

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

### Requirement: Country/Region selection lists all markets and applies region effects

Country/Region Settings SHALL list the full ISO 3166-1 alpha-2 country/territory catalog (plus `XK`) with human-readable labels (English / Simplified Chinese by UI locale) and search. Selecting a country SHALL persist via **HAL locale Region** (`region=` in `locale.conf`) and trigger HAL Region apply (wireless regulatory and Region-linked timezone/NTP defaults). General Settings Country/Region summary MUST show the selected country label (or code). Country/Region MUST appear as a nav row before Language on the Display & Sound card. Operator-visible title SHALL be Country/Region (zh: 国家/地区).

#### Scenario: Country page lists options with US default summary

- **WHEN** Region preference is `US` and the operator opens Common Settings
- **THEN** Country/Region summary indicates United States (or localized equivalent)
- **AND** opening Country/Region Settings shows `US` among the selectable options

#### Scenario: Selecting Germany updates summary and apply path

- **WHEN** the operator selects Germany (`DE`) on Country/Region Settings
- **THEN** the choice is persisted as `region=DE` via HAL locale
- **AND** Common Settings Country/Region summary shows the matching label
- **AND** region apply runs for regulatory / linked clock defaults
