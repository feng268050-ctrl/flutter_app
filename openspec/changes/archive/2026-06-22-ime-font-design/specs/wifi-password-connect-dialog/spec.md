## ADDED Requirements

### Requirement: WiFi password dialog uses Mono when password is visible

The WiFi password connect dialog SHALL apply JetBrains Mono to the password `EditText` when characters are visible, and SHALL NOT require Mono for masked bullet display.

#### Scenario: WiFi password hidden

- **WHEN** the WiFi password field is masked
- **THEN** the field MAY use system password masking without JetBrains Mono

#### Scenario: WiFi password revealed

- **WHEN** the user toggles password visibility to show plaintext
- **THEN** the EditText MUST use JetBrains Mono for character distinction
