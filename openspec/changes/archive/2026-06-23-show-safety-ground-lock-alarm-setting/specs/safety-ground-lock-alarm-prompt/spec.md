## ADDED Requirements

### Requirement: Safety ground lock disconnect prompt uses Frost dialog

When laser enable is active, the gun switch is on, and the safety ground lock is **not** conducting (`DeviceStatus.isSafetyGroundLockLocked()` is false), the app SHALL show an informational Frost prompt (`SafetyGroundLockPrompt`) with title and message for safety ground lock not connected when `t_common_settings.showSafetyGroundLockAlarm` is true. The prompt is NOT a logged alarm entry.

The prompt SHALL auto-dismiss and reset its per-gun-press latch when laser enable turns off, the gun switch releases, or the safety ground lock begins conducting.

#### Scenario: Prompt shows when enabled and interlock open

- **WHEN** `t_common_settings.showSafetyGroundLockAlarm` is true
- **AND** laser enable is active, gun switch is on, and safety ground lock is not conducting
- **AND** the prompt has not yet been shown for the current gun press
- **THEN** the app MUST show the Frost safety ground lock not connected prompt
- **AND** MUST play the standard warn sound while the prompt is visible

#### Scenario: Prompt suppressed when preference disabled

- **WHEN** `t_common_settings.showSafetyGroundLockAlarm` is false
- **AND** laser enable is active, gun switch is on, and safety ground lock is not conducting
- **THEN** the app MUST NOT show the safety ground lock not connected prompt
- **AND** MUST NOT play warn sound for that condition

#### Scenario: Auto reset on interlock connect

- **WHEN** the safety ground lock not connected prompt was latched for the current gun press
- **AND** `DeviceStatus.isSafetyGroundLockLocked()` becomes true
- **THEN** any visible prompt MUST dismiss
- **AND** the per-gun-press latch MUST reset

#### Scenario: One prompt per gun press

- **WHEN** the prompt was shown and dismissed for the current continuous gun press
- **AND** safety ground lock remains not conducting
- **THEN** the app MUST NOT show the prompt again until the gun switch releases and is pressed again
