## 1. Mapping model and header resolution

- [x] 1.1 Add canonical header → `ProcessParametersData` binding (enum or map) matching `工艺库_V1.4.xlsx` and `specs/process-lib-xlsx-import/spec.md` table
- [x] 1.2 Implement header row parser: trim, duplicate-header detection, optional alias map hook
- [x] 1.3 Define `ProcessLibImportProfile` (or equivalent) with required headers: 参数名称, 工艺类型, 数据类型 for OTA import

## 2. EasyExcel integration

- [x] 2.1 Refactor `EasyExcelUtil` (or new class) to two-phase read: first row builds column index by header name; data rows use map + `ProcessDataExcelConvert` / numeric helpers
- [x] 2.2 Ignore unknown columns; empty cells → null for nullable fields
- [x] 2.3 On missing required headers, fail with clear `IllegalArgumentException` or domain exception and log header list

## 3. Wiring and verification

- [x] 3.1 Keep `UpgradeActivity.proUp` calling the refactored parser API (single entry point)
- [x] 3.2 Manual or instrumented test: import `/Users/ayon/Downloads/V1.2.18/工艺库_V1.4.xlsx`, assert row count and spot-check fields vs file
- [x] 3.3 Regression: reorder two columns in a copy of the xlsx and confirm same entity values (header-driven behavior)

## 4. Documentation

- [x] 4.1 Javadoc on public parser API describing extension point (profiles, aliases)
- [x] 4.2 Remove or fix obsolete column-order comments in old `EasyExcelUtil` after refactor
