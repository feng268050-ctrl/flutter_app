## Why

Warn dialog severity (`WARN_TYPE` vs `INFO_TYPE`) is currently hard-coded per alarm source and does not reflect the operator's **Dangerous Operations** bypass choices. Side-panel yellow LED only follows Modbus hardware alarm segments, so non-Modbus faults such as C002 and L001 do not blink the alarm indicator even when the operator sees a serious warn dialog. Icon mipmap names are also misleading (`warn_info_icon` for serious warns, `error_info_icon` for info prompts), and W001 uses a content string resource as its dialog title.

## What Changes

- Tie warn dialog severity to **Allow Work after … Alarm** toggles in Advanced Settings → Dangerous Operations:
  - Matching toggle **OFF** (default) → `WARN_TYPE` (serious warn: red title, warn sound, blocks dismiss semantics)
  - Matching toggle **ON** → `INFO_TYPE` (informational prompt: black title, no warn sound)
- Applies to coded alarms with per-alarm bypass toggles: **A001**, **C002**, **L001**, **W001**, **W002**. All other alarms remain `WARN_TYPE`.
- Centralize dialog creation so passive popups, laser-enable blocks, and demo triggers share the same severity rule.
- Rename warn-dialog icon mipmaps to match semantics (`alarm_warn_icon` / `alarm_info_icon`) and update references.
- Add missing `wire_feeder_communication_alarm_title` string; fix `AlarmCodeEnums.W001` to use title/content resources correctly.
- Extend yellow GPIO alarm indicator: blink when **any** active alarm resolves to `WARN_TYPE`, including non-Modbus sources (C002, L001) and Modbus feeder alarms when bypass is OFF; stay off for `INFO_TYPE`-only states.
- Refresh side-panel LEDs when non-Modbus alarm edges fire and when dangerous-operations toggles change.

## Capabilities

### New Capabilities

- `warn-dialog-severity`: Central rules mapping alarm codes + dangerous-operations toggles to `WARN_TYPE` vs `INFO_TYPE`; shared factory for warn dialog VOs and yellow-LED predicate input.

### Modified Capabilities

- `advanced-settings-dangerous-operations`: Per-alarm bypass toggles also downgrade dialog severity to INFO when ON; GPIO refresh on toggle change.
- `rgb-gpio-indicator-lights`: Yellow LED blinks for any active `WARN_TYPE` alarm, not only Modbus hardware segments.
- `camera-communication-alarm`: C002 passive and laser-enable dialogs follow `warn-dialog-severity` (WARN by default, INFO when `allowWorkAfterCameraAlarm` is ON).
- `alarm-code-naming`: W001 alarm title/content string resource IDs are correct and distinct.

## Impact

- **Java**: `DeviceStatusConvert`, `CameraCommunicationWarnAlarm`, `LensHeavyContaminationWarnAlarm`, `LaserEnableAlarmGuard`, `RgbLedDecision`, `GpioLedHandler`, `CameraCommunicationAlarmController`, `DangerousOperationsSettings`, new `WarnDialogSeverity` (or equivalent)
- **Resources**: `values` / `values-en` / `values-zh` strings; mipmap rename `warn_info_icon` → `alarm_warn_icon`, `error_info_icon` → `alarm_info_icon`
- **Enums**: `AlarmCodeEnums.W001` titleId
- **Tests**: `RgbLedDecision` yellow-mode tests, warn severity factory tests, W001 resource wiring, C002 severity with bypass toggle
- **Specs**: `rgb-gpio-indicator-lights`, `advanced-settings-dangerous-operations`, `camera-communication-alarm`, `alarm-code-naming`
