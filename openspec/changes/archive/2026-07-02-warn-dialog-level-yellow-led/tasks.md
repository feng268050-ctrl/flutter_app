## 1. Warn dialog severity core

- [x] 1.1 Add `WarnDialogSeverity` with `dialogTypeForCode`, `isWarnSeverity`, and `hasAnyActiveWarnSeverityAlarm` wired to `DangerousOperationsSettings` and active-alarm predicates (Modbus bits, C002, L001)
- [x] 1.2 Add `DeviceStatusConvert.createAlarmHit(code, title, content, needCheck)` that resolves type via `WarnDialogSeverity`
- [x] 1.3 Route A001, C002, L001, W001, W002 dialog creation through `createAlarmHit` in `DeviceStatusConvert`, `CameraCommunicationWarnAlarm`, `LensHeavyContaminationWarnAlarm`, and `LaserEnableAlarmGuard`
- [x] 1.4 Unit-test severity mapping for each bypassable code (toggle ON → INFO, OFF → WARN) and non-bypassable codes (always WARN)

## 2. Resource fixes

- [x] 2.1 Add `wire_feeder_communication_alarm_title` to `values`, `values-en`, `values-zh`
- [x] 2.2 Fix `AlarmCodeEnums.W001.titleId` to use the new title resource
- [x] 2.3 Rename mipmaps `warn_info_icon` → `alarm_warn_icon` and `error_info_icon` → `alarm_info_icon`; update `WarnDialogUtil` and `SafetyGroundLockPrompt`

## 3. Yellow LED for warn-severity alarms

- [x] 3.1 Extend `RgbLedDecision.yellowMode` to accept `Context` and use `WarnDialogSeverity.hasAnyActiveWarnSeverityAlarm`
- [x] 3.2 Update `GpioLedHandler.applyLedStates` to pass application context into yellow decision
- [x] 3.3 Call `GpioLedHandler.refresh()` on C002 fault/recovery (`CameraCommunicationAlarmController`), L001 fault/clear, and all dangerous-operations bypass toggle changes
- [x] 3.4 Unit-test yellow mode: C002 active + bypass OFF blinks; C002 + bypass ON off; Modbus E006 still blinks; W001 + feeder bypass ON off

## 4. Verification

- [x] 4.1 Run targeted unit tests (`WarnDialogSeverity*`, `RgbLedDecision*`, `CameraComm*`, `AlarmCodeEnums` W001)
- [x] 4.2 `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync` and smoke-test: C002 fault blinks yellow; enabling camera bypass shows info dialog and stops yellow when sole alarm
