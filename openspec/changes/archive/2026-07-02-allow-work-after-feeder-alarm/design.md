## Context

Advanced Settings **Dangerous Operations** already provides four toggles (`keepLaserOnWhileAlarmed`, camera/gas/lens bypass) persisted in `t_advanced_settings` and read via `DangerousOperationsSettings`. Laser-enable preflight runs through `LaserEnableAlarmGuard.passesPreflight`, which handles A001/C002/L001 with per-toggle bypass and treats all other active coded warn episodes as blocking via `WarnEpisodeController.findFirstBlockingOtherCodedWarn()`.

Wire feeder alarms **W001** (communication) and **W002** (current) are Modbus-driven, surfaced through `DeviceStatusConvert` and the warn-episode pipeline. Today they fall into the "other coded warn" bucket and always block laser enable and runtime work unless `keepLaserOnWhileAlarmed` is ON.

Product requires a fifth toggle **Allow Work after Feeder Alarm** with the same bypass semantics as the camera/gas/lens trio. The hint text about continuous welding is **informational only** — the app MUST NOT enforce process-type-based blocking based on that copy (operators may run continuous welding without wire feed in some setups).

## Goals / Non-Goals

**Goals:**

- Add fifth Dangerous Operations toggle with EN/ZH label and informational hint
- Persist `allowWorkAfterFeederAlarm` in `t_advanced_settings` (default OFF, app-only)
- Extend `LaserEnableAlarmGuard` with explicit W001/W002 handling mirroring A001/C002/L001 bypass
- Mirror bypass semantics for runtime `LaserWorkGuard` / `isWorkBlocked` / `isReadyIndicatorBlocked`
- Update `WarnEpisodeController.LaserEnableAlarmGuardCompat` so W001/W002 join the bypassable code set
- Unit tests for block/bypass and persistence

**Non-Goals:**

- Enforcing hint text at runtime (no process-type gating for feeder bypass)
- Clearing underlying feeder Modbus faults — toggle only affects HMI gating
- Remote WebSocket exposure of the new toggle
- Changing passive feeder alarm popups while faults rise (first-pass behavior unchanged)

## Decisions

### 1. Persist in `t_advanced_settings`

**Choice:** Add `allowWorkAfterFeederAlarm` boolean with Room `@ColumnInfo(defaultValue = "0")`; migration 50→51.

**Rationale:** Same pattern as existing dangerous-operations fields.

### 2. Cached reader extension

**Choice:** Extend `DangerousOperationsSettings` with `isAllowWorkAfterFeederAlarm`, setter, cache refresh, and test override; call `LaserWorkGuard.evaluateAndInterruptIfNeeded` when toggled OFF.

**Rationale:** Consistent with camera/gas/lens toggles.

### 3. Dedicated feeder guard in `LaserEnableAlarmGuard`

**Choice:** Add `isFeederBlocking(context, deviceStatus)` evaluated **before** the generic `findFirstBlockingOtherCodedWarn` path:

| Condition | Blocks laser enable |
|-----------|---------------------|
| No active W001/W002 (incl. demo-sticky) | No |
| Toggle OFF | Yes |
| Toggle ON | No |

**Active predicates:** `deviceStatus.isWireFeederCommunicationAlarm()` OR `deviceStatus.isWireFeederCurrentAlarm()` OR demo-sticky W001/W002.

**On block:** enqueue W001/W002 warn dialog via active detection path; same immediate-show behavior as gas/camera/lens guards.

**Rationale:** Simple toggle-only gating; hint is display copy only.

### 4. Bypassable code set

**Choice:** Extend `isBypassableAlarmCode` and `LaserEnableAlarmGuardCompat.isBypassable` to include W001 and W002 unconditionally (same as A001/C002/L001). Generic `findFirstBlockingOtherCodedWarn` skips these codes when the matching bypass toggle is ON.

**Rationale:** Feeder bypass follows the established trio pattern; no process-type branching.

### 5. UI placement

**Choice:** Add switch row after **Allow Work after Lens Contamination** in `fragment_advanced_setting.xml`; wire in `AdvancedSettingFragment` with existing `suppressDangerousOpsCallbacks` guard.

**Strings:**

- EN title: `Allow Work after Feeder Alarm`
- EN hint: `Continuous welding will not work properly when the wire feeder is abnormal, but other modes can continue.`
- ZH title: `送丝机告警后允许作业`
- ZH hint: `送丝机异常时连续焊接模式将无法正常工作，但其他模式可以继续工作。`

### 6. Ready indicator

**Choice:** Include feeder bypass in `isReadyIndicatorBlocked` using the same `isFeederBlocking` predicate (respects toggle only; ignores `keepLaserOnWhileAlarmed`).

**Rationale:** Matches trio bypass behavior for green ready GPIO.

## Risks / Trade-offs

- **[Risk] Operator enables laser with dead feeder in continuous welding despite hint** → Mitigation: hint warns operator; toggle default OFF; operator explicitly opts in
- **[Risk] W001/W002 slip through generic blocking when bypass ON** → Mitigation: `LaserEnableAlarmGuardCompat` updated; unit tests assert generic scan skips feeder codes when bypass applies

## Migration Plan

1. Room migration 50→51 adds `allowWorkAfterFeederAlarm` default `0`
2. Ship UI + guard in one release
3. Rollback safe — default OFF preserves current blocking behavior

## Open Questions

- None.
