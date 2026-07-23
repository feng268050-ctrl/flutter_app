## MODIFIED Requirements

### Requirement: frostui framework layer lives inside app module

The system SHALL provide a logically independent framework package at `com.lasercyber.lws.frostui` under `app/src/main/kotlin/`. The framework MUST NOT be delivered as a separate Gradle library module in this change. Source MUST be organized into top-level subpackages including `border`, `card`, `dialog`, `blur`, `clock`, and `control`, with dependency direction `dialog` → `card` → `border`, `clock` → `blur`, and `control` → `border`. The `control` layer SHALL host form controls including `FrostSwitch`, `FrostCheckbox`, `FrostSlider`, `FrostSegmentedControl`, and `FrostCapsuleSlider`, each with Compose implementations and `interop` View bridges. The `control` package MUST NOT depend on `card` or `dialog`, and MUST NOT depend on `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`.

#### Scenario: frostui does not depend on ui or ai packages

- **WHEN** frostui framework sources are compiled
- **THEN** no frostui source file MUST import `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`
- **AND** ui business code MAY import `com.lasercyber.lws.frostui`

#### Scenario: Package structure layers are enforced

- **WHEN** new frostui framework types are added
- **THEN** border drawing and design tokens MUST reside under `frostui.border`
- **AND** card, button, blur, and click-sound types MUST reside under `frostui.card`
- **AND** dialog overlay and prompt shell types MUST reside under `frostui.dialog`
- **AND** clock types MUST reside under `frostui.clock`
- **AND** switch, checkbox, linear slider, segmented control, and capsule slider primitives MUST reside under `frostui.control`

#### Scenario: Control primitives live under frostui.control

- **WHEN** a layout references `com.lasercyber.lws.frostui.control.interop.FrostSwitchView`, `FrostSegmentedControlView`, or `FrostCapsuleSliderView`
- **THEN** the implementation resides under `app/src/main/kotlin/com/lasercyber/lws/frostui/control/`
- **AND** no `frostui` source file imports `com.lasercyber.lws.ui`
