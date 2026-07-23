## ADDED Requirements

### Requirement: IME bundles Inter and JetBrains Mono font resources

The system SHALL ship Inter (Regular, Medium, SemiBold) and JetBrains Mono (Regular, Medium) under `app/src/main/res/font/` with corresponding OFL license files under `app/src/main/assets/licenses/fonts/`. Font files MUST be sourced from official upstream repositories (rsms/inter, JetBrains/JetBrainsMono).

#### Scenario: Font resources compile

- **WHEN** the application is built
- **THEN** all five TTF resources MUST be packaged
- **AND** license files MUST be present under `assets/licenses/fonts/`

### Requirement: IME typography tokens use dimen-backed sizes

The IME SHALL define centralized typography tokens (`ImeTypography`) that reference `ime_dimens.xml` for font sizes. Tokens MUST NOT hardcode font sizes that duplicate existing IME dimen keys without documentation.

#### Scenario: Key label size matches dimen

- **WHEN** `ImeTypography.KeyLabel` is applied to a key cap
- **THEN** its font size MUST equal `ime_key_primary_text_size`

### Requirement: Key caps use Inter for all text labels

All keyboard key cap text labels (letters, digits, symbols, mode keys, accent function keys such as Backspace/C/Minus) SHALL use the Inter font family via `ImeTypography` tokens. This requirement MUST NOT alter frosted glass key chrome (fill, border, ripple, spacing, or primary Enter background styling).

#### Scenario: QWERTY letter key font

- **WHEN** the global QWERTY keyboard is visible
- **THEN** letter key labels MUST render in Inter Medium at the key label token size

#### Scenario: Frosted glass chrome unchanged

- **WHEN** fonts are applied to key caps
- **THEN** `ImeGlassKeyBackground` and `ImePrimaryKeyShell` MUST continue using existing light-tone glass and primary Enter styling without modification solely for font rollout

#### Scenario: Icon keys unaffected

- **WHEN** Enter displays the default filled vector icon or Shift uses Canvas/vector artwork
- **THEN** those icons MUST NOT be replaced with font glyphs

### Requirement: Input text font follows ImeFieldType

The system SHALL resolve input field text style through `ImeFontResolver.inputTextStyleFor(ImeFieldType, passwordVisible)`:

- `Text` → Inter Medium
- `Number`, `SignedDecimal`, `Email`, `Uri`, `Password`, `WiFi` → JetBrains Mono Medium when password is visible or field is not masked
- `Password` / `WiFi` hidden (masked) → system password glyphs or Inter; MUST NOT force Mono on bullet masking

#### Scenario: Text dialog input

- **WHEN** `ImeFieldType.Text` input is shown in a Frosted Glass text dialog
- **THEN** the EditText value MUST use Inter

#### Scenario: Numeric dialog input

- **WHEN** `ImeFieldType.Number` or `SignedDecimal` input is shown
- **THEN** the EditText value MUST use JetBrains Mono

#### Scenario: Password visible toggle

- **WHEN** the user reveals password text on a Password or WiFi field
- **THEN** the EditText MUST switch to JetBrains Mono
- **AND WHEN** the user hides password again
- **THEN** the EditText MUST revert to masked display without requiring Mono for bullet glyphs

### Requirement: Long-press alternate popup uses Inter

Alternate character popups (letter triplets, quote/backtick pairs) SHALL use the Inter-based popup typography token.

#### Scenario: Quote long-press popup

- **WHEN** the user long-presses the quote key on the symbol layer
- **THEN** popup choices MUST render in Inter at the alternate popup token size
