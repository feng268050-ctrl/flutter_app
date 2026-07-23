## Context

Advanced Settings already stores app-only boolean toggles (AI Assistance) in `t_advanced_settings` and exposes them via a cached reader (`AiAssistanceSettings`). Laser enable in Quick Mode and Engineer Mode flows through `EngineerModeCheck.enableLaser` → `checkWorkStatus` (E-stop, key switch, gas) → `DeviceDialogHandler.quickCheckDeviceStatus` (Modbus warn scan with `isActiveDetection=true`).

Current alarm behavior at laser-enable time:

| Alarm | Code | Current laser-enable behavior |
|-------|------|-------------------------------|
| Shielding gas | A001 | Blocked in `checkWorkStatus` with a generic error dialog (not the full warn dialog) |
| Camera comm | C002 | **Not** checked on laser enable; passive popup only via ping monitor |
| Lens heavy contamination | L001 | Deferred popup after laser OFF; **not** checked on subsequent laser-enable attempts |

Product requires all three to block laser enable by default and re-show the proper alarm dialog on each attempt, unless the operator enables the matching dangerous-operations toggle.

## Goals / Non-Goals

**Goals:**

- Add **Dangerous Operations** Advanced Settings group with three toggles, default OFF
- Persist toggles in `t_advanced_settings`; exclude from Modbus write payloads and remote stat snapshots
- Centralize laser-enable alarm evaluation with bypass support
- Unify gas laser-enable blocking to use the same warn dialog pipeline as passive A001 alarms
- Add camera (C002) and lens (L001) to laser-enable guard path
- Preserve laser **disable** path — closing laser / end-of-work MUST NOT be blocked by these alarms
- Force laser **off at runtime** when a guarded alarm becomes active and bypass is OFF (Quick + Engineer)
- Play warn alarm sound on all serious (`WARN_TYPE`) warn dialogs, including immediate laser-enable blocks
- Show operator hint text under each Dangerous Operations toggle

**Non-Goals:**

- Clearing underlying faults (ping recovery, Modbus gas bits, stain level 0) — toggles only affect HMI laser-enable gating
- Remote WebSocket exposure of dangerous-operations toggles
- Changing first-pass passive alarm popups while faults rise (only repeat blocking on laser-enable attempts)
- Disabling AI detection (`lensContaminationDetectionEnabled`) — orthogonal to dangerous-operations override

## Decisions

### 1. Persist in `t_advanced_settings`

**Choice:** Add `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, `allowWorkAfterLensContamination` booleans with Room `@ColumnInfo(defaultValue = "0")`.

**Rationale:** Same pattern as AI Assistance toggles; co-located with Advanced Settings UI. Defaults OFF preserves safe behavior.

### 2. Cached reader: `DangerousOperationsSettings`

**Choice:** Mirror `AiAssistanceSettings` — volatile cache, async DB write on toggle, test overrides, warm on app start / Advanced Settings load.

**Rationale:** Laser-enable clicks must not hit Room on the UI thread.

### 3. Central guard: `LaserEnableAlarmGuard`

**Choice:** New small helper (same package as `EngineerModeCheck`) with `boolean passesLaserEnablePreflight(Activity)` returning false when any **unguarded** active alarm blocks enable. Each alarm type consults `DangerousOperationsSettings` before blocking.

**Rationale:** Keeps `EngineerModeCheck` readable; one place for ordering (gas → camera → lens → existing Modbus scan).

**Alarm active predicates:**

| Toggle field | Active when | Dialog source |
|--------------|-------------|---------------|
| `allowWorkAfterGasAlarm` | `ShieldingGasAlarmMessageUtil.hasActiveAlarm(deviceStatus)` | `DeviceStatusConvert.convertShieldingGasAlarmDialogVo(..., true)` |
| `allowWorkAfterCameraAlarm` | `CameraCommStatus.isFault()` | `CameraCommunicationWarnAlarm.buildActiveBlockDialogVo()` (not passive cache) |
| `allowWorkAfterLensContamination` | `LensHeavyContaminationWarnAlarm.INSTANCE.isLaserEnableBlocked()` (new method: pending heavy episode **or** acknowledged-but-still-dirty per live L001 state) | Build same content as deferred L001 dialog |

**On block:** enqueue via `AutoDialogQueue.enqueueImmediateWarn` (same as existing `quickCheckDeviceStatus`) and return false even when dialog VO is null. **On bypass:** skip block and dialog for that alarm only; continue evaluating others.

**Gas refactor:** Remove the separate `OperationDialogBuilder.openErrorDialog` branch from `checkWorkStatus`; gas blocking moves entirely into `LaserEnableAlarmGuard` so repeat attempts re-show the A001 warn dialog.

### 7. Runtime work guard: `LaserWorkGuard`

**Choice:** Quick Mode and Engineer Mode register a host; when laser enable is active and `LaserEnableAlarmGuard.isWorkBlocked()` is true, force laser off. Triggers include Modbus status (A001), camera ping fault (C002), live L001 detect, and turning a bypass toggle OFF while alarm persists.

**Rationale:** Moving A001 out of `checkWorkStatus` removed automatic laser-off on gas alarm; runtime guard restores safe default when bypass is OFF.

### 8. C002 active block dialog

**Choice:** `CameraCommunicationWarnAlarm.buildActiveBlockDialogVo()` uses `createSeriousHit(..., needCheck=false)` so laser-enable attempts are not skipped when passive reminder was consumed.

### 9. Warn alarm sound

**Choice:** `WarnDialogUtil.openDialog` plays `GlobalSoundManager.warnSound()` for all `WARN_TYPE` dialogs when shown.

### 10. Dangerous Operations toggle hints

**Choice:** Each switch row shows title plus secondary hint text (`advanced_setting_item_hint`) with localized EN/ZH strings.

### 11. Quick Mode laser power preflight

**Choice:** `GeneralOperationsFragment.laserEnableClick` calls `EngineerDataCheck.checkLaserPower` before `EngineerModeCheck.enableLaser`.

### 4. Lens contamination “still active” semantics

**Choice:** `LensHeavyContaminationWarnAlarm` exposes `isLaserEnableBlocked()` true when:

- `pendingReminder` is true, **or**
- heavy contamination was acknowledged this boot (`dialogAcknowledgedThisBoot`) but no `onFaultCleared` / level-0 event occurred since the episode

**Rationale:** Matches operator expectation — dismiss dialog once after laser OFF, but next laser-enable attempt blocks again until lens clears or dangerous toggle is ON.

### 5. UI pattern

**Choice:** Reuse AI Assistance layout pattern — `SectionHeader` + `SectionContent` with two switch rows per card styling, placed **after** AI Assistance in `fragment_advanced_setting.xml`. Wire in `AdvancedSettingFragment` with `suppressDangerousOpsCallbacks` guard mirroring AI Assistance.

### 6. Integration point

**Choice:** `EngineerModeCheck.enableLaser` calls `LaserEnableAlarmGuard.passesLaserEnablePreflight` **before** `DeviceDialogHandler.quickCheckDeviceStatus`, then existing Modbus scan runs for unrelated alarms unchanged.

**Alternatives considered:**

- Per-alarm checks inside `DeviceStatusConvert.convertToWarnDialogVo` — rejected; C002/L001 are non-Modbus and bypass logic would scatter
- Storing bypass in `WarnCacheManager` — rejected; product wants persistent Advanced Settings toggles, not per-session dismiss state

## Risks / Trade-offs

- **[Risk] Operators force laser with degraded safety (camera offline, low gas, dirty lens)** → Mitigation: toggles default OFF; labels explicitly name “Dangerous Operations”; warn-table / monitor alarms remain visible
- **[Risk] Lens “still dirty” state diverges from native lensinspector lock** → Mitigation: HMI guard follows app L001 episode state; native lock is separate (out of scope)
- **[Risk] Gas blocking regression** → Mitigation: unit tests assert A001 blocks by default, bypass when toggle ON, dialog re-shown on repeat attempt

## Migration Plan

1. Room migration adds three columns default `0` (false) on existing rows
2. Ship UI + guard in one release; no server dependency
3. Rollback: revert migration only if no production rows depend on toggles (safe — defaults OFF)

## Open Questions

- None — product text and default-safe behavior are specified in the request.
