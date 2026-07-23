## Context

Warn dialogs use `WarnDialogVo.type`: `WarnUtil.WARN_TYPE` (0) for serious alarms (red title, warn sound, non-dismissible semantics) and `WarnUtil.INFO_TYPE` (1) for informational prompts (black title, no warn sound). `DeviceStatusConvert.createSeriousHit` / `createNormalHit` hard-code these types. Most Modbus alarms always call `createSeriousHit`; W001/W002 always call `createNormalHit`. Non-Modbus alarms (`CameraCommunicationWarnAlarm`, `LensHeavyContaminationWarnAlarm`) always build `WARN_TYPE` dialogs.

Advanced Settings **Dangerous Operations** already exposes per-alarm **Allow Work after … Alarm** toggles (`allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, `allowWorkAfterLensContamination`, `allowWorkAfterFeederAlarm`) that gate laser-enable blocking via `LaserEnableAlarmGuard`, but they do not change dialog severity.

Side-panel yellow GPIO is driven by `RgbLedDecision.yellowMode(DeviceStatus)`, which only checks `DeviceStatus.hasAnyHardwareAlarm()` (Modbus gun/laser/feeder/control-card segments). Non-Modbus faults (C002 ping, L001 lens AI) never blink yellow.

Dialog icons use `R.mipmap.warn_info_icon` for `WARN_TYPE` and `R.mipmap.error_info_icon` for `INFO_TYPE` — names are inverted relative to semantics. `AlarmCodeEnums.W001` binds `titleId` to `wire_feeder_communication_alarm_content` instead of a dedicated title string.

## Goals / Non-Goals

**Goals:**

- Single source of truth for dialog severity: bypass toggle ON → `INFO_TYPE`; OFF → `WARN_TYPE` for A001, C002, L001, W001, W002
- All dialog entry points (passive Modbus poll, external alarm pipeline, laser-enable block, demo trigger) use the shared factory
- Yellow LED blinks when any active alarm resolves to `WARN_TYPE`, including non-Modbus sources
- Fix W001 title resource and rename alarm icon mipmaps to `alarm_warn_icon` / `alarm_info_icon`
- Unit tests for severity resolution and yellow-LED predicate

**Non-Goals:**

- Changing `keepLaserOnWhileAlarmed` semantics or laser-enable/runtime guard ordering
- Retrofitting `warn_table.level` (`WarnLevelConstant`) — that field is log metadata, not dialog type
- Yellow blink for `INFO_TYPE` alarms when bypass is ON
- Migrating `ZeroPointOffsetWarnAlarm` (H0034) — remains `WARN_TYPE` always

## Decisions

### 1. Central helper: `WarnDialogSeverity`

**Choice:** Add `WarnDialogSeverity` in `common.handler` (or `common.utils`) with:

- `int dialogTypeForCode(String alarmCode, Context context)` → `WARN_TYPE` or `INFO_TYPE`
- `boolean isWarnSeverity(String alarmCode, Context context)` convenience for LED
- `boolean hasAnyActiveWarnSeverityAlarm(@Nullable DeviceStatus status, Context context)` for yellow LED

Mapping table:

| Code | Bypass toggle field | Default severity |
|------|---------------------|------------------|
| A001 | `allowWorkAfterGasAlarm` | WARN |
| C002 | `allowWorkAfterCameraAlarm` | WARN |
| L001 | `allowWorkAfterLensContamination` | WARN |
| W001, W002 | `allowWorkAfterFeederAlarm` | WARN |
| All others | *(none)* | WARN |

When bypass is **ON**, severity is **INFO** for that code only.

**Rationale:** Avoids scattering `if (DangerousOperationsSettings…)` across `DeviceStatusConvert`, external alarms, and LED code.

### 2. Extend `DeviceStatusConvert` dialog factories

**Choice:** Add `createAlarmHit(String code, String title, String content, boolean needCheck)` that reads `WarnDialogSeverity.dialogTypeForCode` and delegates to `createNoCharts` with the resolved type. Replace direct `createSeriousHit` / `createNormalHit` calls for the five bypassable codes; keep `createSeriousHit` for all other Modbus alarms.

**Alternative considered:** Override type on `WarnDialogVo` after creation — rejected because laser-enable and passive paths would still diverge.

### 3. Yellow LED predicate

**Choice:** Replace `RgbLedDecision.yellowMode(DeviceStatus)` with overload `yellowMode(DeviceStatus, Context)`:

1. If `WarnDialogSeverity.hasAnyActiveWarnSeverityAlarm(status, context)` → `BLINK`
2. Else → `OFF`

`hasAnyActiveWarnSeverityAlarm` checks:

- Modbus segment alarms via existing `convertToWarnDialogVo` alarm predicates OR targeted bit checks, resolved per-code through `isWarnSeverity`
- `CameraCommStatus.isFault()` for C002
- `LensHeavyContaminationWarnAlarm.INSTANCE.isFaultActive()` (or equivalent) for L001
- Demo-sticky alarms if applicable

For Modbus hardware alarms without bypass (H*, E*, C001, etc.), active segment → WARN → yellow blinks (same as today for `hasAnyHardwareAlarm`, except W001/W002 respect feeder bypass).

**Rationale:** User rule is "warn level → yellow blink", not "Modbus segment non-zero".

### 4. LED refresh triggers

**Choice:** Call `GpioLedHandler.refresh()` on:

- Existing Modbus poll path (unchanged)
- `CameraCommunicationAlarmController` fault/recovery edges
- Lens heavy contamination fault/clear events
- `AdvancedSettingFragment` dangerous-operations toggle changes (already refreshes for some toggles — ensure all five bypass toggles)

**Rationale:** Yellow state can change without the next Modbus poll.

### 5. Icon mipmap rename

**Choice:** Rename assets:

- `warn_info_icon` → `alarm_warn_icon`
- `error_info_icon` → `alarm_info_icon`

Update `WarnDialogUtil.bindBody` and `SafetyGroundLockPrompt`. No behavior change — naming only.

### 6. W001 string resources

**Choice:** Add `wire_feeder_communication_alarm_title` in `values`, `values-en`, `values-zh`. Point `AlarmCodeEnums.W001.titleId` to the new title; keep `contentId` as `contact_cyber_after_sales_team_text` (or matching body copy if product prefers full body — align with W002 pattern).

## Risks / Trade-offs

- **[Risk] `hasAnyActiveWarnSeverityAlarm` duplicates Modbus alarm detection logic** → Reuse existing `DeviceStatus` bit helpers and `ShieldingGasAlarmMessageUtil`; unit-test parity with `convertToWarnDialogVo` for bypassable codes.
- **[Risk] Performance on every LED refresh** → Predicate is cheap boolean checks; no DB access (`DangerousOperationsSettings` is cached).
- **[Risk] W001/W002 behavior change** (currently always INFO) → Intentional product change; default OFF bypass means WARN, matching user request.
- **[Trade-off] INFO-level bypassed alarms do not blink yellow** → Matches "warn level only" rule; operators who enable bypass accept lower visual urgency.

## Migration Plan

- Ship in one app release; no DB migration
- Mipmap rename is internal resource ID change only
- No `warn_table` backfill

## Open Questions

- None — product intent is explicit: bypass ON = info dialog, bypass OFF = warn dialog; yellow follows warn severity only.
