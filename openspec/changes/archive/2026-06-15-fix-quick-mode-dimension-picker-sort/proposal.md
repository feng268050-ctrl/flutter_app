## Why

In Quick Mode, the right-side dimension picker (Thickness / Scan Width) beside the circular gauge is built by deduplicating values while iterating `ProcessParametersData` rows. Row order today follows xlsx / DB insertion order (unordered `SELECT *`), so:

1. **Wheel display** — distinct thickness or swing-width values appear in arbitrary order, not ascending.
2. **Hidden parameters** — dedup keeps the **first encountered row** per thickness/swing-width key; lookup (`findNowProcessParametersData`) also returns the **first matching row** in list order. If rows are not canonically ordered, the wheel can show the correct label while the underlying row (laser power, swing frequency, delays, etc.) comes from the wrong library entry when duplicates or ambiguous ordering exist.

Fixing display-only sort would not align row-backed behavior with what the operator sees.

## What Changes

- Introduce a **canonical ascending sort** for quick-mode process rows: `materialType` → dimension (`thickness` or `swingWidth`, null → 0) → `gear` (null → last).
- Apply sort when **persisting** quick-mode rows (`ProcessLibraryImporter` before `batchInsert`) and when **reading** (`listAllMaterials` `ORDER BY` or equivalent) so existing DBs are covered without re-import.
- In `GeneralOperationsFragment.initGearAndThickness`, iterate the **sorted row list** and use **ordered dedup** (`LinkedHashMap`) so picker entries follow row order; do **not** add a separate display-only sort on wheel items.
- `findNowProcessParametersData` SHALL scan the same canonically ordered list so first-match semantics are deterministic and consistent with picker construction.
- Welding/cutting modes use `thickness`; Weld Path Clean / Ultra-wide Clean use `swingWidth`. No label, unit, or Modbus field mapping changes.

## Capabilities

### New Capabilities

- `quick-mode-process-row-order`: Canonical sort order for quick-mode process library rows and ordered picker derivation.

### Modified Capabilities

- `quick-mode-clean-scan-width-display`: Scan-width wheel population SHALL require ascending order derived from sorted rows.
- `process-lib-xlsx-import`: Quick-mode rows SHALL be stored in canonical sort order after parse/filter.

## Impact

- `ProcessLibraryImporter.java` — sort quick-mode rows before insert.
- `ProcessParametersDataDao.java` — `ORDER BY` on `listAllMaterials` (and related quick-mode list queries if any).
- New sort helper (e.g. `QuickModeProcessRowSort`) + unit tests.
- `GeneralOperationsFragment.java` — `LinkedHashMap` ordered dedup from sorted rows; remove any display-only sort approach.
- No xlsx schema, Modbus, or string resource changes.
