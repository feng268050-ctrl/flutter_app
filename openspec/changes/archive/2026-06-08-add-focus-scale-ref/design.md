## Context

`/system/etc/model.properties` already carries per-device keys (`model`, `sn`, `camera_ip`, `host_ip`, `camera_type`) injected by `make emulator` (`sync_model_properties`) and `make prepare` (`write_model_config`). `DeviceModelConfig` loads these once at process start.

The laser-enable safety dialog (`ReminderExactDialog`, layout `dialog_reminder.xml`) is opened from **quick mode** (`GeneralOperationsFragment`) and **engineer mode** (`EngineerModeActivity`) via `ReminderExactBuilder`. Cards 1–2 already show fixed icons and copy; card 3 is a placeholder (empty `ImageView`, text "Continuous Welding Operation Tips").

PNG illustrations for focus-scale values already exist under `app/src/main/res/mipmap-anydpi/focus-scale-ref/` for integers **-9 … 9** (e.g. `0.png`, `-5.png`, `9.png`). They are not yet wired to runtime config.

## Goals / Non-Goals

**Goals:**

- Persist `focus_scale_ref` in ROM via existing Make workflows (`FOCUS_SCALE_REF=<int>`, default `0`).
- Expose `DeviceModelConfig.getFocusScaleRef()` returning a non-negative or negative integer (default `0`).
- Show updated third-card copy and the matching illustration when the laser-enable reminder opens in quick/engineer modes.
- Leave cards 1–2, confirm button, and "don't show again this session" behavior unchanged.

**Non-Goals:**

- Localizing the new English string into zh/en resource files (copy is hardcoded in layout today, same as cards 1–2).
- Changing when the reminder is shown or suppressed (`ReminderExactBuilder` session map).
- Exposing `focusScaleRef` on WebSocket `deviceInfo` or cloud stat payloads.
- Validating that the operator actually adjusted the gun head (UI guidance only).

## Decisions

### 1. Property key: `focus_scale_ref` integer in `model.properties`

**Choice:** Store `focus_scale_ref=<n>` as an ASCII signed integer, mirroring `camera_type` style.

**Rationale:** Consistent with ROM config patterns; shell scripts and Java `Properties` already handle integer keys.

**Default:** `0` when env unset, key absent, empty, or unparsable (with warning log for invalid ROM values).

### 2. Build injection: extend shared resolver + existing sync helpers

**Choice:**

- Add `resolve_focus_scale_ref_value(from_file)` in `scripts/model-properties-common.sh`:
  - When `FOCUS_SCALE_REF` env is set: validate as signed integer (regex `^-?[0-9]+$`) or fail fast.
  - When unset: use existing key from merged/pulled file if valid; else default `0`.
- `sync_model_properties` (emulator): always write `focus_scale_ref=` line (like `camera_type`).
- `write_model_config` (prepare): write `focus_scale_ref=` when any model config key is written; trigger write when only `FOCUS_SCALE_REF` is set (extend early-return guard).

**Rationale:** Same pattern as `camera_type`; emulator merge preserves existing value when env unset.

### 3. App accessor on `DeviceModelConfig`

**Choice:** Add `getFocusScaleRef()` returning `int`, cached at preload with default `0`.

**Rationale:** Single read point for `ReminderExactDialog`; no new enum needed (open integer range).

### 4. Dialog wiring: bind card 3 in `ReminderExactDialog` constructor

**Choice:**

- Add `@+id/iv_focus_scale_ref` and `@+id/tv_focus_scale_ref_tip` to `dialog_reminder.xml` card 3.
- In `ReminderExactDialog`, after `setContentView`, set tip text to the required English string and load image via a small helper.

**Rationale:** Keeps layout IDs explicit; dialog already owns presentation; `ReminderExactBuilder` callers unchanged.

### 5. Dynamic image loading from `mipmap-anydpi/focus-scale-ref`

**Choice:** Resolve drawable at runtime with `Resources.getIdentifier(String.valueOf(focusScaleRef), "mipmap", packageName)`.

- If `getIdentifier` returns `0`, leave `ImageView` without `src` (blank).
- If non-zero, `setImageResource(id)` with `centerInside` scale type (match cards 1–2).

**Rationale:** User-specified path; filenames match integer values (`5`, `-3`, `0`). Avoids maintaining a large `switch` table.

**Alternatives considered:**

- **Static `@mipmap` in XML** — rejected; value is device-specific at runtime.
- **Assets folder** — rejected unless AAPT rejects nested `mipmap-anydpi/focus-scale-ref/` layout; implementer may relocate PNGs only if build fails (same filenames).

**Note on resource naming:** Android resource names for negative values use the literal filename stem (e.g. `-5`). If the nested folder structure fails AAPT, flatten PNGs into `res/mipmap-nodpi/` keeping integer stems, without changing runtime lookup logic.

### 6. Scope: quick mode + engineer mode only

**Choice:** Only flows that already call `ReminderExactBuilder.openReminderExactDialog` are in scope. No other laser-enable entry points.

**Rationale:** Matches user request; dialog is shared so one code change covers both modes.

## Risks / Trade-offs

- **[Risk] AAPT rejects nested `mipmap-anydpi/focus-scale-ref/` or invalid resource stems** → Mitigation: verify `make build`; flatten to `mipmap-nodpi` if needed; `getIdentifier` unchanged.
- **[Risk] `getIdentifier` returns 0 for valid values on some API levels** → Mitigation: unit-test loader with known `0` and `5` fixtures; log debug when missing.
- **[Risk] Prepare overwrites `model.properties` without full merge** → Mitigation: same as `camera_type`; emulator merge retains existing `focus_scale_ref` when env unset.
- **[Trade-off] English-only third-card string** → Acceptable; matches existing hardcoded cards 1–2 in `dialog_reminder.xml`.

## Migration Plan

1. Land script + App changes together; developers run `make build`.
2. Existing devices/emulators without `focus_scale_ref` behave as `0` (shows `0.png` if present, else blank).
3. Per-model tuning: `FOCUS_SCALE_REF=3 make prepare` or `FOCUS_SCALE_REF=-2 make emulator`.
4. Rollback: revert App + scripts; optional ROM key removal (App still defaults to `0`).

## Open Questions

- Should zh/en `strings.xml` gain a localized third-card string in a follow-up? (Deferred.)
- Is an allowed integer range (e.g. -9…9) required at script level, or accept any integer and rely on missing PNG → blank? (Default: accept any integer; images exist for -9…9 only.)
