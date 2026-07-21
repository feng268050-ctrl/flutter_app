## ADDED Requirements

### Requirement: Keyboard A supports four regional typewriter layouts

CyberIME Keyboard A SHALL provide selectable typewriter arrangements for ANSI US QWERTY, ISO German QWERTZ, ISO French AZERTY, and JIS Japanese letter/symbol rows. Layout selection MUST be driven by an App-registered profile/layout provider (or the shared product keyboard preference). Layouts MUST NOT include an F1–F12 row or a right-hand numeric keypad.

Regional soft layouts MUST be built from a unified `CyberImeKeyCode` identity plus per-profile character maps (base / shift / optional altGr). Soft key commit characters MUST come from that map. The product MUST align those maps with the XKB layouts used for physical typing for the same profile; CyberIME MUST NOT implement F-keys or NumPad chrome (hardware path owns those).

#### Scenario: Profile switches QWERTY to QWERTZ

- **WHEN** the registered profile is ISO DE and Keyboard A letter layer is shown
- **THEN** the letter row arrangement matches German QWERTZ (Z/Y positions per DE), not US QWERTY

#### Scenario: No numpad on Keyboard A

- **WHEN** Keyboard A is shown for any regional profile
- **THEN** the panel MUST NOT render a dedicated 9-key numeric keypad block

#### Scenario: Soft commit uses KeyMap

- **WHEN** the operator taps a letter key on Keyboard A for the active regional profile
- **THEN** the inserted character matches the KeyMap entry for that key’s `CyberImeKeyCode` under the active profile
