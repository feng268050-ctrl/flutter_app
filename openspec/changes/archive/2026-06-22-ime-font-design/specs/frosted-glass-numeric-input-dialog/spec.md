## ADDED Requirements

### Requirement: Numeric input dialog EditText uses JetBrains Mono

Frosted Glass numeric input dialogs that host the custom IME for `ImeFieldType.Number` or `SignedDecimal` SHALL apply JetBrains Mono Medium to the input `EditText`.

#### Scenario: Numeric parameter entry

- **WHEN** `FrostedGlassNumericInputDialog` is shown
- **THEN** digits, decimal point, and minus sign in the EditText MUST render in JetBrains Mono
