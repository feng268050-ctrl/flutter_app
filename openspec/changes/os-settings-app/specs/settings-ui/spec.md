## MODIFIED Requirements

### Requirement: Common Settings Network includes Wi-Fi, proxy, Ethernet, and Bluetooth

Common Settings SHALL include a Network group with operator entry points for:

- Wi‑Fi
- HTTP Proxy
- **Cloud services** (云服务; after Proxy in the Network group) — opens the Cloud services sub-page defined by `settings-cloud-services`

Ethernet, Bluetooth, and **LAN SSH debug** MUST NOT appear in product HMI Common Settings Network after migration; those surfaces are owned by the platform Settings app (`settings-app`). USB OTG mode selection remains outside Network (owned by platform Settings Input after migration). Cloud Worker connectivity and LAN HTTP `:5580`/mDNS MUST NOT appear as always-on implicit behavior; they are controlled from the Cloud services page.

Product HMI SHALL expose an explicit **System Settings** (or equivalent) entry that invokes `switch-to-settings` per `settings-app-lifecycle`.

#### Scenario: Network entries reachable

- **WHEN** the operator opens Common Settings → Network
- **THEN** Wi‑Fi, HTTP Proxy, and Cloud services entries are available under Network
- **AND** Ethernet, Bluetooth, and LAN SSH debug entries are not present

#### Scenario: Cloud services opens sub-page

- **WHEN** the operator taps Cloud services under Network
- **THEN** the Cloud services settings sub-page is shown

#### Scenario: System Settings entry

- **WHEN** the operator activates the product System Settings entry
- **THEN** `switch-to-settings` is invoked

### Requirement: Common Settings exposes display, sound, date-time, and input controls

General Settings (Common Settings; en label **General**) SHALL expose:

- Display & Sound (untitled card): **Country/Region**, Language, and Unit as persisted controls backed by **`/var/lib/hal/locale.conf`** through HAL locale (`Region` / `region`, `PreferredLanguage` / `language`, `UnitSystem` / `unit`); Country/Region drives wireless regulatory and region-aware timezone/NTP defaults per `region-country-settings` / `hal-locale`; Language drives Flutter UI locale and CyberIME for three locales; **Display** nav → Brightness (`CyberSlider` / HAL `Backlight`) + Auto Screen Off (dropdown / HAL `AutoSleep`); **Sound** nav → Volume (`CyberVolumeSlider` with speaker icons, left/right row) + Sound Effect (dropdown / `ButtonFeedback`). Order: **Country/Region before Language**, then Unit, then Display, then Sound.
- **Power Mode** (untitled card, **own group**, after Display & Sound and before RGB LED + Camera): a single nav row (same chrome pattern as **Unit**) with trailing summary of the current mode; tapping opens a Power Mode sub-page (see Power Mode requirement). Persistence remains `/var/lib/hal/power.conf` via HAL (not `common-settings.json` / not `locale.conf` for power).
- RGB LED + Camera (untitled card, after Power Mode, before Date & Time): RGB LED entry; Camera entry → product IP-camera settings page.
- Date & Time (untitled card): Automatic sync plus Set Date / Set Time / Set Time Zone via `DateTimeController` (lws-ui parity).
- **Input card MUST NOT list mouse, keyboard layout, or USB OTG** after migration — those entries are owned by the platform Settings app. **Camera is not under Input** (see Camera + RGB LED group requirement).
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

#### Scenario: Migrated input rows absent

- **WHEN** the operator opens Common Settings after Input migration
- **THEN** mouse, keyboard, and USB OTG entries are not present in product HMI Settings

#### Scenario: Camera is not under Input

- **WHEN** the operator opens Common Settings
- **THEN** Camera is reachable from the RGB LED + Camera card before Date & Time
- **AND** Input does not list IP Camera / Camera

#### Scenario: Common Settings chrome follows UI locale

- **WHEN** Language is `zh-CN` and the operator opens Common Settings
- **THEN** migrated row titles and control labels render in Simplified Chinese via App localization

## REMOVED Requirements

### Requirement: Keyboard page offers four-layout Segment and preview

**Reason**: Keyboard layout UX migrates to the platform Settings app.
**Migration**: Implement under `settings-app`; product HMI MUST NOT expose Keyboard settings.

### Requirement: Restart persists layout and applies XKB

**Reason**: Keyboard apply/restart ownership moves to Settings; restart MUST target the Settings seat, not HMI.
**Migration**: Settings Keyboard page owns persist + restart of the foreground Settings process / `settings.service`.

### Requirement: Settings Input includes USB OTG mode

**Reason**: USB OTG mode selection migrates to the platform Settings app.
**Migration**: Implement under `settings-app` Input → USB OTG.
