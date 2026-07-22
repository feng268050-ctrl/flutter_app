## 1. Camera → AlarmSignalSource adapter

- [ ] 1.1 Add App adapter implementing `AlarmSignalSource`; map `IpCameraController.health` unhealthy↔healthy to C002 rising/falling; ignore `unknown`
- [ ] 1.2 Edge-dedupe sustained unhealthy; unit-test unknown/healthy/unhealthy transitions (fake/stub HAL camera)
- [ ] 1.3 Confirm no second ICMP/timer loop — subscribe only to existing HAL health Stream from product session

## 2. Wire into existing warn stack

- [ ] 2.1 Merge Modbus adapter + camera adapter into one `AlarmSignalSource` for `WarnAlarmCoordinator` (App helper preferred)
- [ ] 2.2 Wire in `WarnAlarmController` via `ensureIpCamera` / session `camera`; reuse `BootSelfCheckWarnGate` and existing `flushPresentation`
- [ ] 2.3 On C002 rising/falling, call existing `LaserWorkGuard.evaluateAndInterruptIfNeeded`
- [ ] 2.4 Tests: fake unhealthy arms C002 episode + Monitor `activeAlarms`; Modbus path unchanged; gated presentation suppresses modal

## 3. SFX via existing policy

- [ ] 3.1 Skip looping warn SFX when `LaserAlarmPolicy.treatBypassableAsInfo` is true for the alerting code
- [ ] 3.2 Tests: `allowWorkAfterCameraAlarm` ON → INFO + no SFX; OFF → WARN + SFX

## 4. Verification

- [ ] 4.1 `flutter analyze` + focused App (and package, if any) tests
- [ ] 4.2 Device: unreachable IPC → one C002 via existing warn UI + history + Monitor row; recover clears; self-check gate suppresses modal; bypass affects severity/SFX
