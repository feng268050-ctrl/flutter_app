## 1. Adapter mask helper

- [x] 1.1 Add a small pure helper (e.g. `EstopCommAlarmMask`) that, given e-stop latch + raw laser/wire-feeder comm bits, returns effective active flags for H022/W001 (effective = raw && !eStop)
- [x] 1.2 Unit-test the helper for: e-stop off keeps raw; e-stop on forces both inactive; other codes out of scope

## 2. Wire into Modbus alarm adapter

- [x] 2.1 Include `machine.emergency_stop` in `ModbusAlarmAttributeAdapter` watch ids (alongside existing alarm/meta ids)
- [x] 2.2 Track e-stop latch and raw H022/W001 attribute state; emit `AlarmSignalEvent`s from effective flags only
- [x] 2.3 On e-stop rising: emit falling for any currently effective-active H022/W001; while e-stop holds, drop raw rising/reminder for those codes
- [x] 2.4 On e-stop falling: if raw laser/wire-feeder comm still true, emit rising for the corresponding code(s)
- [x] 2.5 Keep Alarm Information / status `monitorChanges` as raw Modbus values (do not mask status lights under e-stop)
- [x] 2.6 Do not modify `modbus.json`, HAL decode, or `packages/cyber_alarm` episode policy

## 3. Tests and verification

- [x] 3.1 Adapter/controller unit tests: e-stop active + laser/wire bits true → no coordinator rising / no history insert; unrelated code still rises
- [x] 3.2 Adapter unit tests: H022 already active then e-stop rises → falling delivered; e-stop clears with bit still true → rising delivered
- [x] 3.3 Adapter unit tests: status monitor feed keeps raw laser/wire feeder bits under e-stop while warn signals stay suppressed
- [x] 3.4 Run focused `app/hmi` tests for the adapter/mask (and `flutter analyze` on touched files)
