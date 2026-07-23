## ADDED Requirements

### Requirement: Date and time pickers use FrostedGlassDialog shell

Manual date, time, and timezone picker dialogs in the Date & Time settings page SHALL use `FrostedGlassDialog` with picker content in the custom body slot. Automatic/manual toggle behavior and system apply semantics MUST NOT change.

#### Scenario: Date picker overlay

- **WHEN** the user opens manual date selection with automatic date & time disabled
- **THEN** the picker MUST appear inside `FrostedGlassDialog`
- **AND** cancel dismisses without changing system date

#### Scenario: Time picker overlay

- **WHEN** the user opens manual time selection with automatic date & time disabled
- **THEN** hour and minute pickers MUST render in a frosted-glass custom body
- **AND** confirm applies time through existing `SystemSettingUtils` paths

#### Scenario: Timezone picker overlay

- **WHEN** the user opens manual timezone selection with automatic time zone disabled
- **THEN** search and list UI MUST render in a frosted-glass custom body
- **AND** soft-keyboard/window behavior MUST remain usable on device hardware
