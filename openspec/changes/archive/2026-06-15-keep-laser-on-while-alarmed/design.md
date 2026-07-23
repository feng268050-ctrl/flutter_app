## Context

Advanced Settings **Dangerous Operations** already exposes three per-alarm bypass toggles (camera C002, gas A001, lens L001) that affect laser-enable **preflight** and runtime interrupt for those codes only. All other coded alarms always force laser off at runtime via `LaserEnableAlarmGuard.isWorkBlocked` → `LaserWorkGuard` / Quick/Engineer `deviceStatusListen`.

Operators need a single override to **keep laser on while already emitting** when any coded alarm appears, without changing preflight rules for starting laser enable.

## Goals / Non-Goals

**Goals:**

- Add **Keep Laser On while Alarmed** as the **first** row in Dangerous Operations (default OFF)
- Persist `keepLaserOnWhileAlarmed` in `t_advanced_settings` (app-only, not Modbus)
- When ON: suppress **runtime** laser interrupt for all coded alarms; warn dialogs still show
- When OFF: preserve current runtime interrupt semantics (including A001/C002/L001 per-alarm bypass)
- Extend `DangerousOperationsSettings` cache reader and Room migration 48→49
- Unit tests for migration default, cache, and `isWorkBlocked` bypass

**Non-Goals:**

- Changing laser-enable **preflight** (`passesPreflight`) — operators still cannot turn laser on while blocked unless existing per-alarm bypass applies
- Remote WebSocket / Modbus exposure of the new field
- Disabling warn dialogs or alarm sound when the toggle is ON
- Firmware-side laser safety interlocks (HMI-only behavior)

## Decisions

### 1. Persist in `t_advanced_settings`

**Choice:** Add `keepLaserOnWhileAlarmed` boolean with `@ColumnInfo(defaultValue = "0")`.

**Rationale:** Same pattern as other dangerous-operations toggles; default OFF preserves safe interrupt behavior.

### 2. Extend `DangerousOperationsSettings`

**Choice:** Add `isKeepLaserOnWhileAlarmed(Context)`, setter, cache field, test override, and include in `refreshCacheFromAdvancedSettings` / DB warm path.

**Rationale:** Laser runtime checks must stay off the UI thread; mirror existing three-toggle cache.

**When toggled OFF while laser is on and alarms active:** call `LaserWorkGuard.evaluateAndInterruptIfNeeded` (same as turning off a per-alarm bypass).

### 3. Runtime bypass in `LaserEnableAlarmGuard.isWorkBlocked`

**Choice:** At the top of `isWorkBlocked`, if `DangerousOperationsSettings.isKeepLaserOnWhileAlarmed(context)` is true, return **false** immediately (no runtime block).

**Rationale:** Single choke point used by `LaserWorkGuard`, Quick Mode `deviceStatusListen`, and Engineer Mode `deviceStatusListen`. Preflight path (`passesPreflight`) is unchanged and does not consult this toggle.

**Alternatives considered:**

- Skip interrupt only in `LaserWorkGuard` — rejected; Engineer/Quick `deviceStatusListen` also call `isWorkBlocked` directly and would still force laser off
- Per-alarm granularity — rejected; product asks for one master runtime override

### 4. UI placement

**Choice:** Insert new `InsetListRow` + divider **before** the camera-alarm row in `fragment_advanced_setting.xml`. Wire switch in `AdvancedSettingFragment` with the same suppress-callback pattern as other dangerous toggles.

**EN label:** Keep Laser On while Alarmed  
**ZH label:** 告警时保持出光 (or equivalent product copy in strings)

### 5. Interaction with existing bypass toggles

**Choice:** Independent settings:

| Setting | Affects preflight | Affects runtime interrupt |
|---------|-------------------|---------------------------|
| Per-alarm allow-work toggles | Yes (A001/C002/L001 only) | Yes (those codes only) |
| Keep Laser On while Alarmed | No | Yes (all coded alarms) |

When **Keep Laser On while Alarmed** is ON, runtime interrupt is suppressed even for E006 and other non-trio alarms. Per-alarm toggles remain relevant for **starting** laser enable while faults persist.

### 6. Room migration 48→49

**Choice:** `ALTER TABLE t_advanced_settings ADD COLUMN keepLaserOnWhileAlarmed INTEGER NOT NULL DEFAULT 0`.

## Risks / Trade-offs

- **[Risk] Operator keeps laser on during serious faults (overtemp, E-stop class)** → Mitigation: default OFF; localized hint warns that laser continues during alarms; warn dialogs and sounds unchanged; operator can still manually disable laser
- **[Risk] Confusion between “allow work after X alarm” and “keep laser on while alarmed”** → Mitigation: hint text explains runtime-only scope; first-row placement signals master override
- **[Risk] Turning toggle OFF mid-weld with active alarms** → Mitigation: immediate `evaluateAndInterruptIfNeeded` restores interrupt behavior

## Migration Plan

1. Ship Room 48→49 migration, UI, guard change, and tests in one release
2. Existing rows get `keepLaserOnWhileAlarmed = false` — no behavior change until operator enables
3. Rollback: revert app; column is harmless if left in DB

## Open Questions

- None — scope limited to runtime interrupt override with safe default OFF.
