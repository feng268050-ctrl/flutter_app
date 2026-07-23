## MODIFIED Requirements

### Requirement: frostui framework layer lives inside app module

The system SHALL provide a logically independent framework package at `com.lasercyber.lws.frostui` under `app/src/main/kotlin/`. The framework MUST NOT be delivered as a separate Gradle library module. Source MUST be organized into top-level subpackages `border`, `card`, `dialog`, and `control`, with dependency direction `dialog` → `card` → `border`, and `control` → `border`. The `control` package MUST NOT depend on `card` or `dialog`.

#### Scenario: frostui does not depend on ui or ai packages

- **WHEN** frostui framework sources are compiled
- **THEN** no frostui source file MUST import `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`
- **AND** ui business code MAY import `com.lasercyber.lws.frostui`

#### Scenario: Four-layer package structure is enforced

- **WHEN** new frostui framework types are added
- **THEN** border drawing and shared design tokens MUST reside under `frostui.border`
- **AND** card, button, blur, and click-sound registry types MUST reside under `frostui.card`
- **AND** dialog overlay and prompt shell types MUST reside under `frostui.dialog`
- **AND** switch, checkbox, and linear slider primitives MUST reside under `frostui.control`

## ADDED Requirements

### Requirement: Interactive frostui controls use click sound registry

`frostui.control` interactive components (`FrostSwitch`, `FrostCheckbox`, and `FrostSlider` when configured for click feedback on discrete commits) MUST invoke click sound only through `FrostUiClickSoundRegistry`, consistent with `FrostButton`.

#### Scenario: Control toggle plays injected click sound

- **WHEN** a user successfully toggles `FrostSwitch` or `FrostCheckbox`
- **THEN** the control MUST call the frostui click-sound registry
- **AND** frostui control code MUST NOT reference `GlobalSoundManager` directly
