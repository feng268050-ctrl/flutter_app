# safety-interlock-prompts Specification

## Purpose
Non-logged Warn Frost tips for key-switch off and E-stop on product work screens (Quick / Engineer): Misc-gated WARN vs INFO for key-off edges, INFO-only for Enable Laser key-off and all E-stop prompts.

## Requirements

### Requirement: Key-switch edge uses WARN or INFO from Misc toggle

When the product work screen receives a key-switch **off** safety edge, the App SHALL present a non-logged Warn Frost (`WarnFrostShell` + `WarnDialogBody`) and MUST NOT use `OperationFailedDialogHost` for that edge. If Misc `showKeySwitchAlarm` is **on**, the frost SHALL use **WARN** chrome (red siren + red title). If that toggle is **off**, the frost SHALL use **INFO** chrome (info icon + non-red title). Laser Enable session state MUST NOT suppress or change this edge presentation. The App MUST NOT add a new Settings switch for this policy.

#### Scenario: Toggle on — key off is red alarm

- **WHEN** Misc Show Key Switch Alarm is on
- **AND** the key switch turns off
- **THEN** Quick or Engineer shows a WARN-chrome frost with the key-switch-off title and body copy

#### Scenario: Toggle off — key off is yellow warning

- **WHEN** Misc Show Key Switch Alarm is off
- **AND** the key switch turns off
- **THEN** Quick or Engineer shows an INFO-chrome frost with the same key-switch-off title and body copy
- **AND** the presentation does not depend on whether Laser Enable is on

#### Scenario: Confirm or restore dismisses key-switch frost

- **WHEN** a key-switch WARN or INFO frost is visible
- **AND** the operator taps Confirm **OR** the key switch returns on
- **THEN** the frost dismisses and its warn loop SFX stops

### Requirement: Enable Laser while key off always uses INFO chrome

When Laser Enable is blocked because the key switch is off, the App SHALL present (or replace with) an INFO-chrome Warn Frost using the key-switch-off title and body. This SHALL apply whether Misc Show Key Switch Alarm is on or off. If a WARN frost for the current key-off is still visible, the App SHALL dismiss it before showing the INFO frost so at most one frost is visible. The App MUST NOT use `OperationFailedDialogHost` for this block.

#### Scenario: Toggle on — Enable Laser after key off is yellow

- **WHEN** Misc Show Key Switch Alarm is on
- **AND** the key switch is still off
- **AND** the operator attempts Enable Laser
- **THEN** the App shows an INFO-chrome frost (not WARN) with the key-switch-off copy

#### Scenario: Toggle off — Enable Laser key-off is yellow

- **WHEN** Misc Show Key Switch Alarm is off
- **AND** the operator attempts Enable Laser with the key switch off
- **THEN** the App shows an INFO-chrome frost with the key-switch-off copy
- **AND** it MUST NOT show Operation Failed tip chrome

### Requirement: E-stop prompts are INFO only

The App SHALL present a non-logged INFO-chrome Warn Frost for E-stop **on** safety edges and for Laser Enable blocked by E-stop. The App MUST NOT present WARN chrome for these E-stop prompts, MUST NOT add a Misc switch that gates them, and MUST NOT use `OperationFailedDialogHost` for them. INFO chrome MUST NOT play warn-loop SFX. Confirm or E-stop release SHALL dismiss the frost.

#### Scenario: E-stop press is yellow warning

- **WHEN** the E-stop button becomes active
- **THEN** Quick or Engineer shows an INFO-chrome frost with the emergency-stop title and body copy

#### Scenario: Enable Laser while E-stop is yellow warning

- **WHEN** the operator attempts Enable Laser while E-stop is active
- **THEN** the App shows the same INFO-chrome emergency-stop frost
- **AND** it MUST NOT show WARN chrome or Operation Failed tip chrome

#### Scenario: Confirm or E-stop release dismisses

- **WHEN** the E-stop INFO frost is visible
- **AND** the operator taps Confirm **OR** E-stop is released
- **THEN** the frost dismisses
- **AND** no warn-loop SFX was playing for that frost
