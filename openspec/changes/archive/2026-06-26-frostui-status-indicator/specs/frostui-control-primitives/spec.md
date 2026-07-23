## MODIFIED Requirements

### Requirement: control package provides switch checkbox and linear slider primitives

The system SHALL provide a `com.lasercyber.lws.frostui.control` package containing Compose implementations and XML/Java interop Views for `FrostSwitch`, `FrostCheckbox`, `FrostSlider` (linear variant only), and read-only `FrostStatusIndicator`. The package MUST depend on `frostui.border` and MUST NOT depend on `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`.

#### Scenario: Control package compiles without ui imports

- **WHEN** frostui control sources are compiled
- **THEN** no file under `frostui.control` MUST import `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`
- **AND** ui code MAY import `com.lasercyber.lws.frostui.control`
