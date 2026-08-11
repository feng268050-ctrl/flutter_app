## MODIFIED Requirements

### Requirement: Common Settings Network includes Wi-Fi, proxy, Ethernet, and Bluetooth

Common Settings SHALL include a Network group with operator entry points for:

- Wi‑Fi
- HTTP Proxy
- **Cloud services** (云服务; after Proxy in the Network group) — opens the Cloud services sub-page defined by `settings-cloud-services`

Ethernet, Bluetooth, and **LAN SSH debug** MUST NOT appear in product HMI Common Settings Network after migration; those surfaces are owned by the OS Settings app (`os-settings-app`). USB OTG mode selection remains outside Network (owned by OS Settings Input after migration). Cloud Worker connectivity and LAN HTTP `:5580`/mDNS MUST NOT appear as always-on implicit behavior; they are controlled from the Cloud services page. Cloud **Environment** tier (Production/Test) MUST NOT appear in HMI; it lives in OS Settings Network.

Product HMI SHALL expose OS Settings entry via Device Info → **Device SN 5×** invoking `switch-to-os-settings` per `os-settings-app-lifecycle`.

#### Scenario: Network entries reachable

- **WHEN** the operator opens Common Settings → Network
- **THEN** Wi‑Fi, HTTP Proxy, and Cloud services entries are available under Network
- **AND** Ethernet, Bluetooth, LAN SSH debug, and Cloud Environment tier entries are not present

#### Scenario: Cloud services opens sub-page

- **WHEN** the operator taps Cloud services under Network
- **THEN** the Cloud services settings sub-page is shown

#### Scenario: OS Settings entry via Device SN

- **WHEN** the operator taps Device SN five times on Device Information
- **THEN** `switch-to-os-settings` is invoked

### Requirement: Common Settings exposes display, sound, date-time, and input controls

General Settings (Common Settings; en label **General**) SHALL expose untitled cards in this order:

1. **Network** — Wi‑Fi, HTTP Proxy, Cloud services (see Network requirement).
2. **Date & Time** — Automatic sync plus Set Date / Set Time / Set Time Zone via `DateTimeController`; this card SHALL appear **before** Country/Region.
3. **Locale** — **Country/Region**, Language, and Unit backed by **`/var/lib/hal/locale.conf`** (`region` / `language` / `unit`); Country/Region before Language; Country/Region drives wireless regulatory and region-aware timezone/NTP defaults per `region-country-settings` / `hal-locale`; Language drives Flutter UI locale and CyberIME for three locales.
4. **Display + Sound + Camera** — **Display** nav → Brightness + Auto Screen Off (+ wallpaper / text size as product Display page); **Sound** nav → Volume + Sound Effect; **Camera** nav → product IP-camera settings. These three SHALL share **one** untitled card. **RGB LED MUST NOT appear** as a Common Settings nav row (page implementation MAY remain in the codebase but hidden).
5. **Misc** — boot self-check / status overlay / safety-ground toggles as elsewhere.

Additionally:

- **Input card MUST NOT list mouse, keyboard layout, or USB OTG** — owned by OS Settings.
- **Power Mode MUST NOT appear in Common Settings** — owned by OS Settings; HMI may still read `/var/lib/hal/power.conf` for continuous-paint.
- **UI Scale MUST NOT appear in HMI Display** — owned by OS Settings (`display.conf` `ui_scale`).
- Operator-visible labels SHALL come from App localization. Group section titles MUST NOT be shown.

#### Scenario: Date and Time before Country Region

- **WHEN** the operator opens Common Settings
- **THEN** the Date & Time card appears above the Locale card that contains Country/Region

#### Scenario: Display Sound Camera one card

- **WHEN** the operator opens Common Settings
- **THEN** Display, Sound, and Camera are in the same untitled card after Locale
- **AND** RGB LED is not listed

#### Scenario: Power Mode absent from Common Settings

- **WHEN** the operator opens Common Settings after Power Mode migration
- **THEN** Power Mode is not listed

#### Scenario: Brightness and volume invoke controllers

- **WHEN** the user adjusts brightness on Display or volume on Sound
- **THEN** the backlight or media audio controller is asked to set the corresponding percent

#### Scenario: Screen-off invokes AutoSleep

- **WHEN** the user selects an Auto Screen Off option on the Display page other than the current policy
- **THEN** HAL `AutoSleep` is asked to set the corresponding policy and the choice is persisted

#### Scenario: Sound effect is not a stub

- **WHEN** the user selects a Sound Effect option on the Sound page
- **THEN** the choice is persisted via HAL `ButtonFeedback` (`button_feedback` absolute path under `/var/lib/hal/`)
- **AND** product HMI owns installing catalog MP3 bytes next to `sound.conf`; OS Settings selects among installed samples without bundling product audio

#### Scenario: Country/Region appears before Language

- **WHEN** the operator opens Common Settings
- **THEN** the Locale card lists Country/Region above Language
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
- **THEN** Camera is reachable from the Display + Sound + Camera card
- **AND** Input does not list IP Camera / Camera

#### Scenario: Common Settings chrome follows UI locale

- **WHEN** Language is `zh-CN` and the operator opens Common Settings
- **THEN** migrated row titles and control labels render in Simplified Chinese via App localization

## REMOVED Requirements

### Requirement: Keyboard page offers four-layout Segment and preview

**Reason**: Keyboard layout UX migrates to the OS Settings app.
**Migration**: Implement under `os-settings-app`; product HMI MUST NOT expose Keyboard settings.

### Requirement: Restart persists layout and applies XKB

**Reason**: Keyboard apply/restart ownership moves to Settings; restart MUST target the OS Settings seat, not HMI.
**Migration**: OS Settings Keyboard page owns persist + restart of the foreground OS Settings process / `os-settings.service`.

### Requirement: OS Settings Input includes USB OTG mode

**Reason**: USB OTG mode selection migrates to the OS Settings app.
**Migration**: Implement under `os-settings-app` Input → USB OTG.
