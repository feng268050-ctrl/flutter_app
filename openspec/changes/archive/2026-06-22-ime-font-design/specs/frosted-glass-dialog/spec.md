## ADDED Requirements

### Requirement: Text input dialog EditText uses IME Inter font

Frosted Glass text input dialogs that host the custom IME with `ImeFieldType.Text` SHALL apply Inter Medium to the input `EditText` via the shared IME font resolver, matching Compose keyboard typography.

#### Scenario: Process parameter name dialog

- **WHEN** `FrostedGlassTextInputDialog` is shown for text entry
- **THEN** the input field MUST display typed characters in Inter
- **AND** the custom IME keyboard MUST remain visible with unchanged frosted glass key styling
