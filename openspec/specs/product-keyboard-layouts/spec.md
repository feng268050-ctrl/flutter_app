## Purpose

Product keyboard profiles (ANSI / QWERTZ / AZERTY / JIS) bind Settings selection, CyberIME soft layouts, and physical XKB in one preference.

## Requirements

### Requirement: Four product keyboard profiles

The product SHALL define exactly four keyboard profiles for Settings and CyberIME:

1. **ANSI US** — US QWERTY (ANSI Enter)
2. **ISO DE** — German QWERTZ (ISO)
3. **ISO FR** — French AZERTY (ISO)
4. **JIS JP** — Japanese Industrial Standard typewriter block

Each profile MUST map to a CyberIME Keyboard A arrangement and to a physical XKB layout id (at least `us`, `de`, `fr`, `jp` with an appropriate model such as `pc105` or `jp106`).

#### Scenario: Profile enumeration is fixed

- **WHEN** the App lists product keyboard profiles
- **THEN** exactly the four profiles above are offered in product Settings (Demo-only layouts such as `ru` MUST NOT appear in the product Segment)

### Requirement: Virtual keyboard excludes F-keys and numpad

Product CyberIME / preview keyboards for these profiles MUST present the **typewriter block only**: no Function-key row (F1–F12) and no dedicated numeric keypad (right-hand 9-key / 100% block). Dedicated CyberIME Keyboard B (compact numeric pad for number fields) remains allowed and is out of scope of this exclusion.

#### Scenario: Preview has no F-row or numpad

- **WHEN** the operator views the layout preview for any of the four profiles
- **THEN** the preview MUST NOT show an F1–F12 row or a right-hand numeric keypad

### Requirement: Settings Segment selects profile with preview

Common Settings → Keyboard SHALL use `CyberSegmentedControl` (or package equivalent) to select among the four profiles and SHALL show a visual preview of the selected typewriter layout. Changing the Segment MUST update the preview without requiring a navigation pop.

#### Scenario: Segment updates preview

- **WHEN** the operator selects a different segment (e.g. DE after US)
- **THEN** the on-page keyboard preview switches to that profile’s typewriter arrangement

### Requirement: Soft input defaults to CyberIME

On-screen text entry in product flows SHALL continue to use CyberIME by default. The selected product keyboard profile SHALL drive CyberIME Keyboard A key caps / arrangement for the focused session when a profile-aware layout is available.

#### Scenario: Wi-Fi password uses CyberIME with current profile

- **WHEN** the operator opens a CyberIME password field after selecting ISO FR
- **THEN** the soft keyboard letter layout follows the French AZERTY profile arrangement (within typewriter scope)

### Requirement: Physical keyboard requires matching profile

Physical USB/BT HID key text SHALL be produced by flutter-pi / XKB using the persisted layout for the selected profile. The Settings Keyboard page MUST inform the operator that the selected specification must match the attached physical keyboard; otherwise some keys may not produce the expected characters. The App MUST NOT implement physical typing by remapping HID scancodes in Dart as a substitute for XKB.

#### Scenario: Apply persists XKB layout for profile

- **WHEN** the operator applies the DE profile for physical input
- **THEN** the HAL keyboard layout preference is persisted for XKB id `de` (or documented equivalent)
- **AND** after the documented apply path (v1: HMI restart), physical key events follow the German layout

#### Scenario: Mismatch warning is visible

- **WHEN** the Keyboard settings page is shown
- **THEN** a short operator-facing note states that the physical keyboard specification must match the selection
