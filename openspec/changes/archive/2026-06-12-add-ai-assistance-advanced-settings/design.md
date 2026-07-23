## Context

Advanced Settings today exposes device parameters in three groups (Offset & Correction, Power Thresholds, Temperature Thresholds). Most numeric fields in `t_advanced_settings` are written to Modbus, but the table is the home for **all Advanced Settings page state**—not every column maps to a device register.

Production laser-on AI already runs via:

- `OpencvStainDetectCoordinator` — live PR1 stain detect while laser ON; heavy contamination sets pending alert shown after laser OFF (`production-lens-det-dirty-alerts`)
- `ZeroPointDetectCoordinator` — continuous zero-point samples while laser ON; finalize on laser OFF applies 0090H correction and may set offset alert pending (`zero-point-detect-on-laser-on`, `production-zero-point-offset-alerts`)

Neither path has an operator-facing enable switch.

## Goals / Non-Goals

**Goals:**

- Expose **AI Assistance** group on Advanced Settings with two Switch controls (Lens Contamination Detection, Zero Point Offset Detection), default ON
- Persist toggles in `t_advanced_settings` alongside other Advanced Settings fields
- Gate production laser-on inference, pending alerts, and zero-point Modbus writes when the corresponding toggle is OFF
- Preserve Manual Auto zero-point flow in Advanced Settings (operator-initiated) independent of the production laser-on toggle
- Keep AI assistance toggles **out of** Modbus write payloads and remote stat snapshots

**Non-Goals:**

- Modbus register mapping for these toggles
- Disabling AI Vision offline/preview stain detect or engineer lens-guard tooling
- Changing sampling intervals, cluster reducer, or alert dialog copy when features are enabled

## Decisions

### 1. Persist in `t_advanced_settings`

**Choice:** Add `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled` booleans to `AdvancedSettings` / `t_advanced_settings`.

**Rationale:** These are Advanced Settings page controls; co-locating data with the page avoids split persistence. Product confirms `t_advanced_settings` is not exclusively Modbus-backed—app-only columns are allowed when excluded from device writes.

**App-only vs Modbus-backed:** Existing Modbus-mapped fields (0090H zero offset, thresholds, etc.) continue through `ModbusFiledBuilder`. New boolean columns are read by coordinators and the Advanced Settings UI only; `ModbusFiledBuilder` MUST NOT include them in write payloads.

Language, unit, sound effect, and boot self-check remain in `t_common_settings` per existing split.

### 2. Cached settings reader: `AiAssistanceSettings`

**Choice:** Small cached reader (pattern similar to `BootSelfCheckSettings`) backed by `AdvancedSettingsDao`, with `isLensContaminationDetectionEnabled(Context)` / `isZeroPointOffsetDetectionEnabled(Context)`, test overrides, and async DB write on toggle change.

**Rationale:** Coordinators run on PR1 frame cadence; they must not query Room per frame. Cache defaults to `true` when unloaded (preserve current behavior).

### 3. Gating points

| Toggle | Gate location | Behavior when OFF |
|--------|---------------|-------------------|
| Lens contamination | `OpencvStainDetectCoordinator.onPr1I420Frame` early return | No live stain JNI calls; no `LensCheckResultEvent` from live weld path; clear any production heavy-dirty pending on laser OFF without showing dialog |
| Zero point offset | `ZeroPointDetectCoordinator.applyLaserState` / `shouldStartTaskOnLaserRisingEdge` | No round start, no PR1 samples, no finalize/0090H write, no offset alert pending for that session |

Manual Auto (`ZeroPointManualAutoCoordinator`) is **not** gated — it is an explicit operator action on Advanced Settings, not automatic laser-on assistance.

`EdgeDrawingDetectCoordinator` on L1 Pro shares PR1 sampling infrastructure but is part of the zero-point production path; it SHALL follow the same zero-point toggle gate.

### 4. UI pattern

**Choice:** Reuse Common Settings Switch styling (`switch_thumb` / `switch_track`) inside a new `SectionHeader` + `SectionContent` block at the bottom of `fragment_advanced_setting.xml` (after Temperature Thresholds). Wire in `AdvancedSettingFragment` with `suppressCallbacks` guard.

Bind via `AdvancedSettingViewModel` / `AdvancedSettingVo` from the existing `t_advanced_settings` load path.

### 5. Room migration `46 → 47`

```sql
ALTER TABLE t_advanced_settings ADD COLUMN lensContaminationDetectionEnabled INTEGER NOT NULL DEFAULT 1;
ALTER TABLE t_advanced_settings ADD COLUMN zeroPointOffsetDetectionEnabled INTEGER NOT NULL DEFAULT 1;
```

Existing rows receive default ON (no behavior change on upgrade).

### 6. Remote snapshot and Modbus

- AI assistance toggles follow existing **Advanced settings excluded from remote snapshot** rule—no new stat_response fields.
- Toggle changes do not trigger Modbus device-setting writes.

## Risks / Trade-offs

- **[Risk] Stale cache after external DB edit** → Mitigation: refresh cache on toggle write and on `AdvancedSettingViewModel.init`; warm at `LaserApplication` startup.
- **[Risk] Pending alert from session before toggle off** → Mitigation: on toggle OFF, clear production pending state for that feature; on laser OFF with toggle OFF, skip dialog presentation.
- **[Risk] Accidental Modbus inclusion** → Mitigation: spec + code review that `ModbusFiledBuilder` unchanged for new columns; unit test if builder has coverage.

## Migration Plan

1. Ship Room migration 46→47 on `t_advanced_settings` with DEFAULT 1 columns.
2. Deploy app; existing devices keep AI features enabled.
3. Rollback: downgrade leaves new columns unused; no data loss for other fields.

## Open Questions

- None — Manual Auto exclusion and default ON are confirmed by product request.
