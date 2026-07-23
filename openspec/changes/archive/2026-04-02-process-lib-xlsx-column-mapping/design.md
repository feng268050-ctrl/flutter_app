## Context

- **Current**: `EasyExcelUtil.proFileConvert` uses `LinkedHashMap` integer keys (column index) and skips row 0 as header without using header text. Comments listed columns (e.g. 激光频率) that **do not appear** in the reference `工艺库_V1.4.xlsx`; the real template has 22 columns A–V matching `ProcessParametersData` non-deprecated fields.
- **Consumers**: `UpgradeActivity.proUp` → `resetAllProcessData` → `ProcessParametersDataDao.batchInsert`.
- **Constraints**: Android, existing EasyExcel dependency; keep Room entity and DAO unchanged.

## Goals / Non-Goals

**Goals:**

- Header-driven mapping aligned with `工艺库_V1.4.xlsx` column names and `ProcessParametersData` fields.
- Reusable API: header map + row → entity, so future templates or MQTT/import can share the same core.
- Normalized header matching (trim; optional case-folding for English aliases later).
- Explicit failure when configured **required** headers are missing (see spec).

**Non-Goals:**

- Changing database schema or adding migration for new columns in this change.
- Supporting `.xls` or CSV in this change.
- UI for user-edited mapping files (configuration can be code/constants first).

## Decisions

1. **EasyExcel read mode**  
   - **Choice**: Keep EasyExcel; first `invoke` builds header index map from row 0 (`LinkedHashMap` keys = column indices, values = header strings). Subsequent rows use that map to read by header name.  
   - **Alternative**: EasyExcel `@ExcelProperty` entity — rejected for flexibility (aliases, multiple profiles) and to avoid one giant annotated DTO tied to one template.

2. **Mapping definition**  
   - **Choice**: Central constant map `canonical Chinese header → setter or FieldBinder` (or enum `ProcessLibColumn` with `header`, `apply(row, entity)`). Optional second map `alias → canonical` for future English headers.  
   - **Alternative**: JSON config in assets — deferred until product needs non-code updates.

3. **Type conversion**  
   - **Choice**: Reuse `ProcessDataExcelConvert` for 材料 / 工艺类型 / 数据类型; reuse existing string→int/double helpers with empty → null.

4. **Import profile**  
   - **Choice**: Introduce a small `ProcessLibImportProfile` (or named constant) holding required header set + canonical map, so OTA vs future “full” template can diverge without forking parsers.

5. **Deprecated entity fields**  
   - **Choice**: Do not map columns unless they appear in a future spec; `工艺库_V1.4.xlsx` has no 激光频率/穿孔频率 columns — leave those fields null on import.

## Risks / Trade-offs

- **[Risk] Header typo in shipped xlsx** → silent skip or wrong column ignored. **Mitigation**: required-header check; log first row headers at info/debug on parse start.
- **[Risk] Duplicate header names** → ambiguous column. **Mitigation**: detect duplicates when building map; fail fast with message.
- **[Risk] Extra whitespace / full-width characters** → no match. **Mitigation**: `trim()`; optional NFKC later if needed.

## Migration Plan

- Ship new parser behind same entry point `EasyExcelUtil.proFileConvert(File)` or rename with adapter in `UpgradeActivity` to minimize call sites.
- Validate with on-device test using `工艺库_V1.4.xlsx` and one OTA zip in staging.
- Rollback: revert to previous commit (restore index-based parser) if critical; keep old implementation in git history only.

## Open Questions

- Whether **参数名称** / **工艺类型** / **数据类型** should be the only required headers, or **材料** / **档位** must also be required for OTA — confirm with product; spec currently marks three as required for OTA profile.
- If platform later ships English column headers, confirm alias list (e.g. `Material` → 材料) before adding to `ProcessLibImportProfile`.
