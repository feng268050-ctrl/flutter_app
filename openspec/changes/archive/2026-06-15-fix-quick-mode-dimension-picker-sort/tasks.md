## 1. Canonical row sort helper

- [x] 1.1 Add `QuickModeProcessRowSort` with `sort(rows, processType)` — order: `materialType` → `thickness` or `swingWidth` (null→0) → `gear`
- [x] 1.2 Unit tests: unsorted rows → canonical order; clean mode uses `swingWidth`; null material/gear handling

## 2. Persist and load sorted rows

- [x] 2.1 `ProcessLibraryImporter.resetQuickModeProcessData` — sort quick-mode rows before `batchInsert`
- [x] 2.2 `QuickProcessParametersDataViewModel` — `Transformations.map` + `QuickModeProcessRowSort.sortedCopy` so reads return canonical order without re-import

## 3. GeneralOperationsFragment picker build

- [x] 3.1 Replace `HashMap` with `LinkedHashMap` for `gearMap` and `rightDimensionMap`
- [x] 3.2 Iterate sorted `dataList`; do **not** add display-only sort on `rightDimensionList`
- [x] 3.3 Confirm `findNowProcessParametersData` scans the same ordered list from LiveData

## 4. Verification

- [x] 4.1 Unit tests for sort helper and importer integration (rows reordered before insert)
- [x] 4.2 Manual: Quick Mode Continuous Welding — thickness wheel ascending; Modbus/hidden params match lowest-gear row for selected thickness
- [x] 4.3 Manual: Quick Mode Weld Path Clean — scan width wheel ascending with correct backing row
- [x] 4.4 `make sync` on emulator
