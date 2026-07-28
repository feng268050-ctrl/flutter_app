## Purpose

Product keyboard profiles (QWERTY / QWERTZ / AZERTY / JIS) bind Settings selection, CyberIME soft phone layouts, and physical XKB in one preference.

## Requirements

### Requirement: Four product keyboard profiles

The product SHALL define exactly four keyboard profiles for Settings and CyberIME:

1. **QWERTY** — US QWERTY phone soft keyboard (default)
2. **QWERTZ** — German QWERTZ phone soft keyboard
3. **AZERTY** — French AZERTY phone soft keyboard
4. **JIS** — Japanese romaji 26-key phone soft keyboard

Each profile MUST map to a CyberIME Keyboard A soft arrangement and to a physical XKB layout id (at least `us`, `de`, `fr`, `jp` with an appropriate model such as `pc105` or `jp106`). Soft layout geometry MUST NOT simulate ANSI/ISO/JIS typewriter blocks (no number row, F-keys, Tab/Caps, Ctrl/Alt/AltGr, or NumPad on Keyboard A).

Legacy persisted ids `default`, `defaultSoft`, and `ansi` MUST read as **QWERTY**. Writes MUST use only `qwerty` / `qwertz` / `azerty` / `jis`.

#### Scenario: Profile enumeration is fixed

- **WHEN** the App lists product keyboard profiles
- **THEN** exactly the four profiles above are offered in product Settings (Demo-only layouts such as `ru` MUST NOT appear in the product Segment)
- **AND** Default / `defaultSoft` MUST NOT appear as a Segment option

#### Scenario: Legacy Default migrates to QWERTY

- **WHEN** keyboard.conf has `profile=default` or `profile=ansi`
- **THEN** Settings and CyberIME treat the selection as QWERTY
- **AND** the next successful apply persists `profile=qwerty`

### Requirement: Soft keyboard is phone-style four rows

Product CyberIME / preview keyboards for these profiles MUST present a **phone soft pad**: three letter rows plus one bottom function row. Digits and punctuation MUST come only from the `123` / `#+=` symbol layers — not as letter-key secondaries or long-press digit options. Dedicated CyberIME Keyboard B (compact numeric pad for number fields) remains allowed.

#### Scenario: Preview has no typewriter chrome

- **WHEN** the operator views the layout preview for any of the four profiles
- **THEN** the preview MUST NOT show an F1–F12 row, number row, Ctrl/Alt/AltGr, Tab/Caps, typewriter Enter geometry, or a right-hand numeric keypad
- **AND** the preview caption identifies a soft keyboard layout preview

### Requirement: Settings Segment selects profile with soft preview

Common Settings → Keyboard SHALL use `CyberSegmentedControl` (or package equivalent) to select among the four profiles and SHALL show a visual preview of the selected soft layout built from the same layout factory as the live panel. Changing the Segment MUST update the preview without requiring a navigation pop. QWERTZ/AZERTY pages SHOULD note long-press accents; JIS SHOULD note romaji + Space candidates.

#### Scenario: Segment updates preview

- **WHEN** the operator selects a different segment (e.g. AZERTY after QWERTY)
- **THEN** the on-page keyboard preview switches to that profile’s soft arrangement

### Requirement: Soft input defaults to CyberIME

On-screen text entry in product flows SHALL continue to use CyberIME by default. The selected product keyboard profile SHALL drive CyberIME Keyboard A key caps / arrangement for the focused session when a profile-aware layout is available.

#### Scenario: Wi-Fi password uses CyberIME with current profile

- **WHEN** the operator opens a CyberIME password field after selecting AZERTY
- **THEN** the soft keyboard letter layout follows the French AZERTY soft arrangement

### Requirement: Soft JIS uses romaji composition

When the soft JIS profile is active and Japanese mode is selected, letter taps MUST compose romaji into hiragana, Space MUST cycle candidates, and the confirm action MUST commit the selected candidate (or current reading). Delete MUST prefer composition backspace before field backspace.

#### Scenario: Romaji converts and commits

- **WHEN** the operator types `ka` then confirms in soft JIS Japanese mode
- **THEN** `か` is committed
- **WHEN** the operator types `nihongo`, presses Space to cycle, and confirms a dictionary candidate when present
- **THEN** the selected candidate (at least hiragana `にほんご` or `日本語`) is committed

### Requirement: Physical keyboard requires matching profile

Physical USB/BT HID key text SHALL be produced by eLinux HMI / XKB using the persisted layout for the selected profile. The Settings Keyboard page MUST inform the operator that the selected specification must match the attached physical keyboard; otherwise some keys may not produce the expected characters. The App MUST NOT implement physical typing by remapping HID scancodes in Dart as a substitute for XKB. Soft geometry changes MUST NOT redefine HID/XKB key shapes.

#### Scenario: Apply persists XKB layout for profile

- **WHEN** the operator applies the QWERTZ profile for physical input
- **THEN** the HAL keyboard layout preference is persisted for XKB id `de` (or documented equivalent)
- **AND** after the documented apply path (v1: HMI restart), physical key events follow the German layout

#### Scenario: Mismatch warning is visible

- **WHEN** the Keyboard settings page is shown
- **THEN** a short operator-facing note states that the physical keyboard specification must match the selection
