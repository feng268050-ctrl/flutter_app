## MODIFIED Requirements

### Requirement: Bypassable alarms use INFO warn chrome when allow-* is ON

When a dangerous-operations allow-* bypass is ON for a bypassable code (A001/C002/L001/W001/W002), warn presentation SHALL use INFO styling (black title) rather than WARN red title. Non-bypassable codes remain WARN styling. Presentation MUST resolve style via App `LaserAlarmPolicy` / `DangerousOperationsSettings`, not widget state.

When a showing warn dialog’s code resolves to INFO under that policy, the App MUST NOT play the looping warn alarm sound for that dialog. WARN-styled dialogs SHALL play sound only while that dialog is presented (`showingCode` set). The App MUST NOT start warn SFX for a code that is merely queued or fault-active without a visible dialog.

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
- **AND** a C002 warn dialog is showing
- **THEN** the looping warn alarm sound MUST NOT play for C002
- **AND** the dialog chrome for C002 MUST remain INFO

#### Scenario: No dialog means no warn SFX

- **WHEN** one or more coded faults are active but no warn dialog is showing
- **THEN** the looping warn alarm sound MUST NOT play
