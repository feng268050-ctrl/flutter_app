## 1. Entity and database

- [x] 1.1 Rename fields on `ProcessParametersData` (`name`, `materialType`, `materialName`) and align `ProcessParametersNameData` the same way.
- [x] 1.2 Add Room `Migration` to rename SQLite columns on `t_process_parameters_data` (`paramsName`→`name`, `materials`→`materialType`, `materialsName`→`materialName`); bump `AppDatabase` version; register migration.
- [x] 1.3 Export/update Room schema JSON under `app/schemas/...` for the new version.

## 2. Data access and import

- [x] 2.1 Update `ProcessParametersDataDao` (and any `@Query` / projection strings) to use new column names; fix any `@Embedded` / constructor mappings for `ProcessParametersNameData`.
- [x] 2.2 Update `ProcessLibRowMapper`, `ProcessLibColumn`, `ProcessLibraryImporter`, and Excel converters to read/write the new field names where they bind columns or headers.

## 3. UI and ViewModels

- [x] 3.1 Replace DataBinding / observable accessors: `paramsName`→`name`, `materials`→`materialType`, `materialsName`→`materialName` in XML layouts and `ProcessParametersDataViewModel` / `BaseProcessParametersDataViewModel` (including `setMaterials`→`setMaterialType` or equivalent public API as decided in code review).
- [x] 3.2 Update fragments/activities (`GeneralOperationsFragment`, engineer wash/cutting/welding, `EngineerModeActivity`, `InputDialogBuilder`, `DataListPopupUtils`, `EngineerDataCheck` method names if they expose legacy terms), `CameraController` (`getMaterials`→`getMaterialType` for `setMaterialType` on video entity), and `ProcessVideoDetailsViewModel` if it overrides getters.
- [x] 3.3 Update `ProcessParametersDataConvert` and any merge/clone utilities.

## 4. Tests and specs merge

- [x] 4.1 Fix unit/Android tests and fixtures that reference old JSON keys or getters (`DeviceWsVideoListPayloadTest`, metadata tests, snapshot/parser tests, etc.).
- [x] 4.2 After implementation, merge delta specs from `openspec/changes/rename-process-parameters-data-fields/specs/` into `openspec/specs/` for `device-ws-unified-envelope`, `device-websocket-connectivity`, and `device-ws-video-list-command` (or archive per project workflow).

## 5. Verification

- [x] 5.1 Run relevant Gradle test tasks; smoke-test engineer + quick mode list, save, Modbus send path, and WebSocket process-param ingest if available locally.
