## ADDED Requirements

### Requirement: Input overlay stepper controls use FrostButton glass interaction

Numeric and other input overlay bodies that expose in-body stepper or auxiliary action controls (for example `FrostNumericStepper` minus and plus buttons) SHALL render those controls with `com.lasercyber.lws.frostui.card.FrostButton` (or equivalent frostui Compose API) so they share FrostedGlass border/fill primitives, visible press interaction, and click sound via `FrostUiClickSoundRegistry`. Stepper controls MUST NOT use plain `TextView` plus legacy drawable-only backgrounds as the long-term implementation.

#### Scenario: Numeric stepper minus and plus use FrostButton

- **WHEN** `FrostNumericStepper` renders with `showStepper = true`
- **THEN** the minus and plus controls MUST be implemented as `FrostButton` with `FrostButtonVariant.DEFAULT`
- **AND** tapping either control MUST play the shared frostui click sound and apply the existing step increment/decrement logic

#### Scenario: Stepper buttons use default glass not primary orange

- **WHEN** stepper minus or plus buttons are rendered in an input overlay body
- **THEN** they MUST use the default/neutral glass variant
- **AND** MUST NOT use `FrostButtonVariant.PRIMARY` orange styling reserved for confirmation actions

### Requirement: Custom IME Enter key uses FrostButton PRIMARY orange variant

The custom in-app IME Enter key on the keyboard bottom row MUST always use `FrostButtonVariant.PRIMARY` with the shared primary orange fill and border tokens defined for FrostedGlass confirmation buttons, independent of whether the key face shows text, an icon, or both.

#### Scenario: IME Enter uses primary orange styling for text face

- **WHEN** the custom IME Enter key is configured with text-only display
- **THEN** the Enter key MUST use `FrostButtonVariant.PRIMARY`
- **AND** MUST match the primary orange token styling in this specification

#### Scenario: IME Enter uses primary orange styling for icon face

- **WHEN** the custom IME Enter key is configured with icon-only display
- **THEN** the Enter key MUST still use `FrostButtonVariant.PRIMARY`
- **AND** MUST NOT fall back to default glass key styling used for letter keys

### Requirement: Input dialog primary confirm uses FrostButton PRIMARY orange variant

When an input overlay shows an on-screen primary confirm action in the dialog action slot (in addition to the custom IME Enter key), that control MUST use `FrostButtonVariant.PRIMARY` with the shared primary orange fill and border tokens defined for FrostedGlass confirmation buttons.

#### Scenario: Numeric dialog confirm is primary orange

- **WHEN** a numeric input overlay displays a confirm action in the prompt action bar
- **THEN** the confirm button MUST use `FrostButtonVariant.PRIMARY`
- **AND** MUST match the primary orange token styling in `frosted-glass-components`

#### Scenario: WiFi password has no on-screen primary confirm

- **WHEN** the WiFi password overlay is shown per `wifi-password-connect-dialog`
- **THEN** the dialog MUST NOT show a separate on-screen Connect button
- **AND** primary submission MUST occur through the IME custom connect action only
