## 1. Constants and enums

- [x] 1.1 Rename `ALARM_H0010`–`ALARM_H0034` string values to `H010`–`H034` in `AlarmCodeConstants.java` (update constant identifiers and comments)
- [x] 1.2 Rename `AlarmCodeEnums` members `H0010`–`H0034` to `H010`–`H034` and wire to new constants
- [x] 1.3 Run `rg 'H00(1[0-9]|2[0-9]|3[0-4])'` and update all Java/Kotlin references (`DeviceStatusConvert`, `ZeroPointOffsetWarnAlarm`, `WarnTableViewModel`, etc.)

## 2. Documentation

- [x] 2.1 Update `docs/alarm-codes-reference.md` (H010–H034 table, appendix comm codes H022/H026/H027)
- [x] 2.2 Update Makefile help / OpenSpec examples referencing `H0034` or other legacy H codes where applicable

## 3. Verification

- [x] 3.1 Unit test: `AlarmCodeEnums.findByCode("H022")` resolves; `findByCode("H0022")` returns null
- [x] 3.2 Manual: `make alarm CODE=H022` and `CODE=H034` show correct titled dialogs
- [x] 3.3 Manual: trigger gun/laser comm faults — dialog and warn list show `H001` / `H022` (not four-digit codes)
- [x] 3.4 Manual: clear `warn_table` via engineer UI or adb before/after upgrade (no app auto-cleanup)
