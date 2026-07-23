# warn-dialog-severity Specification

## Purpose
TBD - created by archiving change warn-dialog-level-yellow-led. Update Purpose after archive.
## Requirements
### Requirement: Bypassable alarm dialog severity follows dangerous-operations toggles

For alarm codes **A001**, **C002**, **L001**, **W001**, and **W002**, the app SHALL resolve warn dialog `WarnDialogVo.type` from Advanced Settings **Dangerous Operations** bypass toggles:

| Alarm code | Bypass toggle field | Toggle OFF (default) | Toggle ON |
|------------|---------------------|----------------------|-----------|
| A001 | `allowWorkAfterGasAlarm` | `WARN_TYPE` | `INFO_TYPE` |
| C002 | `allowWorkAfterCameraAlarm` | `WARN_TYPE` | `INFO_TYPE` |
| L001 | `allowWorkAfterLensContamination` | `WARN_TYPE` | `INFO_TYPE` |
| W001, W002 | `allowWorkAfterFeederAlarm` | `WARN_TYPE` | `INFO_TYPE` |

All other alarm codes SHALL use `WARN_TYPE` regardless of dangerous-operations toggles.

Passive popups, laser-enable block dialogs, and demo alarm triggers for bypassable codes MUST use the same severity resolution.

#### Scenario: Camera alarm defaults to warn severity

- **WHEN** C002 is active
- **AND** `allowWorkAfterCameraAlarm` is false
- **THEN** any C002 warn dialog shown MUST use `WARN_TYPE`
- **AND** the dialog MUST play warn alarm sound

#### Scenario: Camera bypass downgrades to info severity

- **WHEN** C002 is active
- **AND** `allowWorkAfterCameraAlarm` is true
- **THEN** any C002 warn dialog shown MUST use `INFO_TYPE`
- **AND** the dialog MUST NOT play warn alarm sound

#### Scenario: Feeder alarm defaults to warn severity

- **WHEN** W001 is active from Modbus
- **AND** `allowWorkAfterFeederAlarm` is false
- **THEN** the W001 warn dialog MUST use `WARN_TYPE`

#### Scenario: Feeder bypass downgrades to info severity

- **WHEN** W002 is active from Modbus
- **AND** `allowWorkAfterFeederAlarm` is true
- **THEN** the W002 warn dialog MUST use `INFO_TYPE`

#### Scenario: Non-bypassable alarm stays warn severity

- **WHEN** Modbus alarm E006 is active
- **AND** any dangerous-operations bypass toggle is true
- **THEN** the E006 warn dialog MUST still use `WARN_TYPE`

### Requirement: Warn dialog icons use semantically named mipmaps

Warn dialog body icons SHALL use mipmap resources named for alarm severity:

- `WARN_TYPE` dialogs MUST use `R.mipmap.alarm_warn_icon`
- `INFO_TYPE` dialogs MUST use `R.mipmap.alarm_info_icon`

Legacy names `warn_info_icon` and `error_info_icon` MUST NOT remain referenced in production code.

#### Scenario: Warn dialog shows warn icon

- **WHEN** a `WARN_TYPE` warn dialog is displayed
- **THEN** the prompt icon MUST be `alarm_warn_icon`

#### Scenario: Info dialog shows info icon

- **WHEN** an `INFO_TYPE` warn dialog is displayed
- **THEN** the prompt icon MUST be `alarm_info_icon`

### Requirement: Active warn-severity predicate drives yellow LED

The app SHALL expose a single predicate (for example `WarnDialogSeverity.hasAnyActiveWarnSeverityAlarm`) that returns true when at least one active coded alarm resolves to `WARN_TYPE` under current dangerous-operations settings, including non-Modbus sources (C002, L001).

#### Scenario: Non-Modbus C002 triggers warn-severity predicate

- **WHEN** camera ping health reports unreachable
- **AND** `allowWorkAfterCameraAlarm` is false
- **THEN** the warn-severity predicate MUST be true
- **AND** `RgbLedDecision` yellow mode MUST be blink

#### Scenario: Bypassed C002 does not trigger warn-severity predicate

- **WHEN** camera ping health reports unreachable
- **AND** `allowWorkAfterCameraAlarm` is true
- **THEN** the warn-severity predicate MUST be false for C002
- **AND** yellow MUST be off unless another `WARN_TYPE` alarm is active

