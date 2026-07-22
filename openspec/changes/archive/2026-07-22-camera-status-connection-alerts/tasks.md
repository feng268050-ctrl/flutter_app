## 1. Camera → AlarmSignalSource adapter

- [x] 1.1 Add App adapter implementing `AlarmSignalSource`; map `IpCameraController.health` unhealthy↔healthy to C002 rising/falling; ignore `unknown`
- [x] 1.2 Edge-dedupe sustained unhealthy; unit-test unknown/healthy/unhealthy transitions (fake/stub HAL camera)
- [x] 1.3 Confirm no second ICMP/timer loop — subscribe only to existing HAL health Stream from product session

## 2. Wire into existing warn stack

- [x] 2.1 Merge Modbus adapter + camera adapter into one `AlarmSignalSource` for `WarnAlarmCoordinator` (App helper preferred)
- [x] 2.2 Wire in `WarnAlarmController` via `ensureIpCamera` / session `camera`; reuse `BootSelfCheckWarnGate` and existing `flushPresentation`
- [x] 2.3 On C002 rising/falling, call existing `LaserWorkGuard.evaluateAndInterruptIfNeeded`
- [x] 2.4 Tests: fake unhealthy arms C002 episode + Monitor `activeAlarms`; Modbus path unchanged; gated presentation suppresses modal

## 3. SFX via existing policy

- [x] 3.1 Play looping warn SFX only while a warn dialog is showing (`showingCode`); skip INFO-styled codes; never play for queued-only faults
- [x] 3.2 Tests: `allowWorkAfterCameraAlarm` ON → INFO + no SFX; OFF → WARN + SFX when dialog showing

## 4. Verification

- [x] 4.1 `flutter analyze` + focused App (and package, if any) tests
- [x] 4.2 Device: unreachable IPC → one C002 popup + SFX with dialog; Camera Comm Status updates; Alarm Logs row for C002; recover clears; self-check gate; bypass INFO/SFX
