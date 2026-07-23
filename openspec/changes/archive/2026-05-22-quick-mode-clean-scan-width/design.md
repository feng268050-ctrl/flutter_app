## Context

Quick Mode `GeneralOperationsFragment` renders a central circular gauge (`LaserProgress`) with a **left** gear picker (`GearPickV2`) and a **right** dimension picker (`ThicknessPickV2`). The right picker layout (`thickness_pick_v2.xml`) always shows `@string/thickness_text` and unit brackets (mm/in).

`GeneralOperationsFragment.initGearAndThickness` builds the right wheel from distinct `ProcessParametersData.thickness` values per material + gear. `findNowProcessParametersData` matches `activeMaterials`, `activeThickness` (via `thicknessKey`), and `activeGear`.

For **Weld Path Clean** and **Ultra-wide Clean**, process rows use **`swingWidth`** (0–6 mm); thickness is often null and already treated as 0 via `thicknessMmOrZero`. The UI label and selection axis do not match operator expectations or engineer-mode labeling (`swing_width_text` → "Scan Width" in English).

## Goals / Non-Goals

**Goals:**

- Right picker label shows **Scan Width** for `WELD_CLEAN` and `WIDTH_CLEAN` only.
- Right wheel values and selection state reflect **`swingWidth`** for those modes.
- Changing scan width still triggers the existing debounced `sendProcessConfigData` / Modbus path with the correct row.

**Non-Goals:**

- Changing the center gauge (gas pressure) or left gear picker behavior.
- Engineer mode, advanced settings, or process-library schema changes.
- New string resources if `swing_width_text` suffices.

## Decisions

### 1. Reuse `ThicknessPickV2` with mode-aware label and data binding

**Choice:** Keep the existing right-side component; add `modeType` (already in binding) to switch title string and data source in `GeneralOperationsFragment`, rather than a separate `ScanWidthPick` layout.

**Rationale:** Minimal layout duplication; same wheel styling and unit toggle (`useMmUnit`) as thickness.

**Alternative:** New `ScanWidthPickV2` — rejected as unnecessary duplication.

### 2. Track `activeSwingWidth` for clean modes; keep `activeThickness` for others

**Choice:** Introduce `activeSwingWidth` (Double) used when `generalOperations.type` is `WELD_CLEAN` or `WIDTH_CLEAN`. `initGearAndThickness` branches: build right-wheel map keyed by `swingWidth` (with null → 0 helper mirroring thickness). `findNowProcessParametersData` matches `swingWidth` instead of `thicknessKey(activeThickness)` on that branch.

**Rationale:** Avoid overloading `activeThickness` with swing width semantics in welding modes.

### 3. Label via data binding in `thickness_pick_v2.xml`

**Choice:** Bind title `TextView` to `@string/swing_width_text` when `modeType` is clean; else `@string/thickness_text`. Unit row unchanged (mm/in from `useMmUnit`).

**Rationale:** No Java string logic in the picker; consistent with mode-colored assets elsewhere.

### 4. Display formatting for swing width values

**Choice:** Reuse the same mm/in conversion pattern as `convertToThicknessData`, applied to `swingWidth` (format as decimal string; inch path via `InchMillimeterUtils.mmToInStr` when unit is inch).

**Rationale:** Parity with thickness display rules in Quick Mode.

## Risks / Trade-offs

- **[Risk] Duplicate `swingWidth` values in DB for same material+gear** → Multiple wheel entries; same as thickness today. **Mitigation:** Keep first-match iteration order unchanged.
- **[Risk] `activeThickness` left stale when switching from welding to clean in same fragment instance** → Unlikely (separate fragment instances per mode in `QuickModeActivity`). **Mitigation:** Reset selection on `initGearAndThickness` when mode is clean.
- **[Risk] Process rows with null `swingWidth`** → Treat as 0 for keying and display, consistent with thickness null handling.

## Migration Plan

- Ship in app release only; no data migration.
- Rollback: revert UI branch; clean modes fall back to thickness label (functional regression only).

## Open Questions

- None for v1. If product later wants scan width unit suffix distinct from thickness (e.g. fixed mm only), that would be a follow-up.
