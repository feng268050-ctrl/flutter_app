## Context

Quick Mode loads rows via `ProcessParametersDataDao.listAllMaterials(processType, QUICK_MODE_DATA)` — currently `SELECT *` with **no `ORDER BY`**, so order is insertion/id order from xlsx.

`GeneralOperationsFragment.initGearAndThickness` walks `dataList`, dedupes gears and thickness/swing-width into `HashMap`, then uses `map.values()` for pickers. `HashMap` iteration order is undefined.

Selection path:

1. Picker callback sets `activeThickness` / `activeSwingWidth` / `activeGear` from `DoubleWheelViewItem.getValue()`.
2. `findNowProcessParametersData()` linear-scans `listLiveData` and returns the **first** row matching material + dimension + gear.
3. `sendProcessConfigData()` writes **all** fields from that row to Modbus (most are not shown on the dashboard).

Therefore **row order is functional**, not cosmetic: dedup and first-match both depend on iteration order. A display-only sort on wheel items would leave row-backed hidden parameters tied to the wrong library entry when multiple rows share a displayed thickness/swing-width across gears or when first-match is ambiguous.

## Goals / Non-Goals

**Goals:**

- One canonical sort for quick-mode rows used at **import**, **read**, and **picker build**.
- Right wheel shows distinct thickness/swing-width values **ascending**, derived from sorted row traversal (ordered dedup), not a post-hoc UI sort.
- `findNowProcessParametersData` first-match uses the same ordering.
- Unit-testable sort comparator shared by importer and fragment.

**Non-Goals:**

- Reordering xlsx source files on disk.
- Changing engineer-mode rows (`ENGINEER_MODE_DATA`).
- Sorting the left gear picker in this change (can follow same pattern later).
- Changing how rows are matched (still material + gear + thickness/swingWidth).

## Decisions

### 1. Canonical row comparator

**Choice:** Sort by:

1. `materialType` ascending (nulls last),
2. dimension ascending — `thickness` (null → 0) for non-clean process types; `swingWidth` (null → 0) for `WELD_CLEAN` / `WIDTH_CLEAN`,
3. `gear` ascending (nulls last).

**Rationale:** For a fixed material, dimension-primary order makes ordered dedup emit ascending thickness/swing-width. Gear as tie-breaker picks the lowest gear row as the representative for `DoubleWheelViewItem.dataId` and for first-match when keys overlap.

**Alternative:** Sort dimension-only — rejected; gear tie-breaker needed for deterministic row choice.

### 2. Apply sort at import **and** read

**Choice:**

- `ProcessLibraryImporter.resetQuickModeProcessData` sorts before `batchInsert`.
- `listAllMaterials` adds explicit `ORDER BY materialType, gear, thickness, swingWidth` (or app-layer sort via `Transformations.map` if SQL null ordering is awkward).

**Rationale:** Import fixes new libraries; read path fixes already-persisted DBs without forcing OTA re-import.

**Alternative:** Import-only — rejected; existing devices keep wrong order until re-import.

### 3. Ordered dedup in `initGearAndThickness` (not display sort)

**Choice:** Replace `HashMap` with `LinkedHashMap` for `gearMap` and `rightDimensionMap`; iterate **already-sorted** `dataList`. First encounter per key wins; `values()` preserves insertion order from sorted traversal.

**Rationale:** Picker order and hidden-parameter row choice share one source of truth. No separate `Collections.sort` on wheel items.

**Alternative:** Sort `rightDimensionList` after `HashMap` — rejected per product: display decoupled from row semantics.

### 4. Shared helper `QuickModeProcessRowSort`

**Choice:** Static `sort(List<ProcessParametersData> rows, int processType)` + `Comparator` unit tests.

**Rationale:** Importer, DAO transform, and fragment can share one definition; tests document contract.

## Risks / Trade-offs

- **[Risk] SQL `ORDER BY` on nullable columns** → Use COALESCE in SQL or sort in ViewModel `Transformations.map`; prefer one path and test.
- **[Risk] Re-import changes row ids** → Quick mode rows are deleted and re-inserted on import today; ids already change. No new migration.
- **[Risk] First-match row changes for edge-case duplicates** → Intended: canonical order replaces arbitrary xlsx order.

## Migration Plan

Ship in app release. On next process-library import or app read with new `ORDER BY`, pickers and Modbus payloads align to canonical order. No manual migration.

## Open Questions

(none)
