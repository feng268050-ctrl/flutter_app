## Context

`migrate-advanced-settings` shipped UI + AI/dangerous JSON toggles. Thresholds are local-only; warn dialogs always use red WARN title. lws-ui commits thresholds on slider stop via Modbus write + Room cache, and `WarnDialogSeverity` flips bypassable codes to INFO when allow-* is ON.

## Goals / Non-Goals

**Goals:**
- Watch + write catalogued Advanced Settings holding attributes via HAL.
- Cache last-known numerics in `advanced-settings.json`.
- Warn presentation INFO styling when dangerous bypass treats code as info.
- Wire `onBypassDisabled` to a laser re-evaluate entry point (soft until interrupt ready).

**Non-Goals:**
- Zero Offset Auto progress / camera daemon.
- StreamDetect / stain / zero-point AI coordinators.
- Full LaserWorkGuard GPIO/ready LED (beyond soft-disable laser_enable if clearly available).

## Decisions

### 1. Threshold controller in App application layer

**Choice:** `AdvancedSettingsThresholdsController` (ChangeNotifier) owns doubles, syncs from Modbus watch, commits `writeAttribute` on `onChangeEnd`, mirrors into `AdvancedSettingsStore` numeric keys.

**Rationale:** Matches Device Information watch pattern; keeps widgets thin.

### 2. Modbus ids

| UI field | Attribute id |
|----------|--------------|
| Zero Offset | `setting.zero_point_correction` |
| Proper Swing Width | `setting.swing_width_correction` |
| Laser start/end | `setting.laser_start_power` / `laser_end_power` |
| Blow pressure | `setting.blowing_pressure_threshold` |
| Motor/driver/protective/collimating temp | existing `*_temp_alarm_threshold` |
| Recovery interval | `setting.temp_alarm_recovery_interval` |

Signed UI ranges for zero/swing: interpret/write as signed 16-bit on the wire when catalog type is u16/s16 (two's-complement for zero_point u16).

### 3. Write timing

**Choice:** Preview on drag; `writeAttribute` + JSON cache on change end (parity with lws-ui `onStopTrackingTouch` → `updateAndSendData`). Soft-fail writes (log, keep UI value).

### 4. Warn severity

**Choice:** App resolves `LaserAlarmPolicy.treatBypassableAsInfo` when building warn dialog; `WarnDialogBody` takes `infoStyle` (black title). Catalog severity enum unchanged.

### 5. Laser re-evaluate

**Choice:** `LaserWorkGuard.evaluateAndInterruptIfNeeded` App stub: if work blocked by policy and laser enable can be cleared via `control.laser_enable`, write false; else no-op. Hook from DangerousOperationsSettings.

## Risks

- [Risk] Board offline → cache still drives UI; label soft-fail with last known.
- [Risk] zero_point catalogued as u16 — signed cast must match controller.
- [Trade-off] No batch FC16 multi-register write like lws-ui list; per-attribute writes acceptable for Settings.

## Migration Plan

1. Store numeric keys + Modbus id constants.
2. Controller + ModbusRtuClient.writeAttribute.
3. Wire Advanced tab.
4. Warn INFO style + LaserWorkGuard stub.
5. Tests.
