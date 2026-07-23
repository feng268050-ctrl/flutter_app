## 1. Config and serial command gate (Phase 1)

- [x] 1.1 Add `ModbusConfig.COMMAND_INTERVAL_MS = 50`; add `DeviceStatusConstant.POLL_TIMER_INTERVAL_MS = 100`; deprecate/remove `LOOP_DEVICE_STATUS_TIME_INTERVAL`, `SAME_PROTOCOL_INTERVAL`, and `DIFF_PROTOCOL_INTERVAL` (no function-code-specific interval on RTU path)
- [x] 1.2 Implement `ModbusSerialGate` with `awaitBeforeCommand()`, `markCommandEnd()`, `isCommandInFlight()` (set at executor task start, clear at terminal end including after gate sleep completes)
- [x] 1.3 Wrap all `ModbusManagerRtu` RTU I/O on `serialSendExecutor` with gate + in-flight tracking; skip gate sleep when `ModbusConfig.isMock()`
- [x] 1.4 Set `setSendIntervalTime(0)` in `openSerialPort`
- [x] 1.5 Add `ModbusSerialGateTest`: 50ms wait when elapsed < 50; no wait when ≥ 50; mock skips sleep

## 2. Poll timer and discard-on-busy (Phase 2)

- [x] 2.1 Refactor poll entry to `tryStartPollCycle()`: discard if `ModbusPollCycleGuard` / cycle in flight OR `ModbusSerialGate.isCommandInFlight()`; debug log discard reason
- [x] 2.2 Register poll refresh Timer at `POLL_TIMER_INTERVAL_MS` (100ms) via `DeviceStatusTaskHandler` / `RxTaskManager` or thin `ModbusPollScheduler` wrapper; remove unconditional cycle start on tick
- [x] 2.3 Keep chained status→data in one cycle (`RxModbusPollResults`); `ModbusPollCycleGuard.end()` only after data terminal + `finishPollCycle`
- [x] 2.4 Update `LaserApplication.initSerialPort` and mock path to use 100ms poll timer constant
- [x] 2.5 Add `ModbusPollDiscardTest`: tick discarded when cycle in flight; tick discarded when bus in flight; tick starts cycle when idle

## 3. OTA exclusive session and boot self-check (Phase 3)

- [x] 3.1 Implement `ModbusOtaExclusiveSession`: on OTA start pause poll timer; reject all non-whitelist Modbus including **any read**; whitelist **OTA writes only**; clear on `controllerUpgradeEnd` and restart poll timer
- [x] 3.2 Refactor `ControllerUpgradeHandler`: after firmware info write, **sequential** firmware data Modbus writes (app-side offset); next frame only after previous write success + `COMMAND_INTERVAL_MS` gate; remove OTA dependence on `upgradeHandler` / status poll; do NOT `recreateDeviceStatusTask` on OTA start
- [x] 3.3 Keep `checkControllerUpgradeStatusTask` for stall/timeout using cache/timers only (no Modbus read during OTA session)
- [x] 3.4 Boot self-check synchronous reads use gated `ModbusManagerRtu` (50ms); defer/block if OTA exclusive session active

## 4. Observability and cleanup (Phase 4)

- [x] 4.1 Throttled debug logs: `gateWaitMs`, discard reason, `cycleMs`
- [x] 4.2 Update comments in `RxModbusTaskBuilder`, `RxModbusDeviceStatusAndDataPollTask` to document 100ms attempt / 50ms gate / discard semantics
- [x] 4.3 Run `./gradlew :app:testDebugUnitTest`; emulator sync smoke

## 5. Verification

- [x] 5.1 Device/debug: inter-command spacing ≥ 50ms via logs or serial capture
- [x] 5.2 Device/debug: under steady poll, refresh attempts ~100ms; discard logs present when cycle > 100ms or under write load — no unbounded queue growth
- [x] 5.3 Regression: alarm pipeline, LED, Monitor readiness; OTA upgrade exclusive (no param writes during OTA); post-OTA poll resumes at 100ms
