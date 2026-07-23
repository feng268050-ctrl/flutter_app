## MODIFIED Requirements

### Requirement: frostui framework layer lives inside app module

The system SHALL provide a logically independent framework package at `com.lasercyber.lws.frostui` under `app/src/main/kotlin/`. The framework MUST NOT be delivered as a separate Gradle library module in this change. Source MUST be organized into top-level subpackages including `border`, `card`, `dialog`, `blur`, and `clock`, with dependency direction `dialog` → `card` → `border` and `clock` → `blur`.

#### Scenario: frostui does not depend on ui or ai packages

- **WHEN** frostui framework sources are compiled
- **THEN** no frostui source file MUST import `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`
- **AND** ui business code MAY import `com.lasercyber.lws.frostui`

#### Scenario: Three-layer package structure is enforced

- **WHEN** new frostui framework types are added
- **THEN** border drawing and design tokens MUST reside under `frostui.border`
- **AND** card, button, blur, and click-sound types MUST reside under `frostui.card`
- **AND** dialog overlay and prompt shell types MUST reside under `frostui.dialog`

## ADDED Requirements

### Requirement: Frost backdrop blur uses HokoBlur via registry injection

The `frostui.blur` package SHALL provide `FrostBitmapBlur` using HokoBlur static API. `FrostBackdropBlurRegistry` MUST receive its implementation from the app layer (`FrostUiDialogBridge`) using HokoBlur, not RenderScript `BlurUtils`. frostui MUST NOT import `com.lasercyber.lws.ui.common.utils.BlurUtils`.

#### Scenario: Registry blur uses HokoBlur after bridge init

- **WHEN** `FrostUiDialogBridge` initializes frostui registries
- **THEN** `FrostBackdropBlurRegistry` MUST be registered with a HokoBlur-backed implementation
- **AND** frost dialog snapshot blur MUST not call RenderScript blur APIs
