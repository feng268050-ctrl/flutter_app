## MODIFIED Requirements

### Requirement: Bypassable alarms use INFO warn chrome when allow-* is ON

When a dangerous-operations allow-* bypass is ON for a bypassable code (A001/C002/L001/W001/W002), warn presentation SHALL use INFO styling (black title) rather than WARN red title. Non-bypassable codes remain WARN styling. Presentation MUST resolve style via App `LaserAlarmPolicy` / `DangerousOperationsSettings`, not widget state.

When a showing or alerting episode resolves to INFO under that policy, the App MUST NOT play the looping warn alarm sound for that code. WARN-styled bypassable codes and non-bypassable WARN codes SHALL continue to play sound per existing warn SFX rules.

#### Scenario: Gas allow shows INFO title

- **WHEN** `allowWorkAfterGasAlarm` is ON
- **AND** a warn dialog is shown for A001
- **THEN** the dialog title uses INFO (non-red) styling

#### Scenario: No bypass keeps WARN

- **WHEN** all allow-* toggles are OFF
- **AND** a warn dialog is shown for A001
- **THEN** the dialog title uses WARN red styling

#### Scenario: Camera bypass suppresses warn SFX

- **WHEN** `allowWorkAfterCameraAlarm` is ON
- **AND** a C002 episode is active and eligible for sound sync
- **THEN** the looping warn alarm sound MUST NOT play for C002
- **AND** the dialog chrome for C002 MUST remain INFO
