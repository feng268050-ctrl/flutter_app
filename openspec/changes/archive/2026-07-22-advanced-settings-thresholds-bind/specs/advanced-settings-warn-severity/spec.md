## ADDED Requirements

### Requirement: Bypassable alarms use INFO warn chrome when allow-* is ON

When a dangerous-operations allow-* bypass is ON for a bypassable code (A001/C002/L001/W001/W002), warn presentation SHALL use INFO styling (black title) rather than WARN red title, parity with lws-ui `WarnDialogSeverity`. Non-bypassable codes remain WARN styling. Presentation MUST resolve style via App `LaserAlarmPolicy` / `DangerousOperationsSettings`, not widget state.

#### Scenario: Gas allow shows INFO title

- **WHEN** `allowWorkAfterGasAlarm` is ON
- **AND** a warn dialog is shown for A001
- **THEN** the dialog title uses INFO (non-red) styling

#### Scenario: No bypass keeps WARN

- **WHEN** all allow-* toggles are OFF
- **AND** a warn dialog is shown for A001
- **THEN** the dialog title uses WARN red styling
