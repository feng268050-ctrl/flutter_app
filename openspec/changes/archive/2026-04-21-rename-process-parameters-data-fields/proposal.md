## Why

`ProcessParametersData` uses legacy names (`paramsName`, `materials`, `materialsName`) that are inconsistent with the rest of the domain model (for example `ProcessParamsVideo.materialType`) and with clearer Java naming. Renaming aligns the entity, Room columns, Gson JSON, and queries; the user will align cloud and other clients separately.

## What Changes

- **BREAKING**: Rename `ProcessParametersData` fields: `paramsName` → `name`, `materials` → `materialType`, `materialsName` → `materialName`.
- **BREAKING**: Rename matching SQLite columns on `t_process_parameters_data` with a Room migration (no dual-column or read fallback for legacy names).
- **BREAKING**: Gson (de)serialization for `ProcessParametersData` and any nested JSON (for example `processParametersJson`, WebSocket/MQTT payloads) uses the new property names only; **no** `@SerializedName` compatibility for old keys.
- Update all Java, XML data binding, DAO `@Query` projections, Excel/process-library import mappers, tests, and related DTOs (for example `ProcessParametersNameData` used for name-list queries) so names stay consistent end-to-end.
- Bump Room schema version and export the new schema JSON artifact.

## Capabilities

### New Capabilities

- _(none — behavior is a rename of an existing persistence and wire shape.)_

### Modified Capabilities

- `device-ws-unified-envelope`: Clarify that `command.send_process_param` payload process-parameter JSON uses the renamed camelCase properties on `ProcessParametersData` (same model as MQTT `ONE_PROCESS_DATA` body).
- `device-websocket-connectivity`: Require that outbound `processParameters` snapshots use the same JSON property names as the renamed `ProcessParametersData` fields.
- `device-ws-video-list-command`: Require that parsed `processParameters` objects in list items follow the same property names when sourced from persisted JSON.

## Impact

- Android app: entities, DAOs, migrations, ViewModels, fragments, layouts (`@{...paramsName}` → `name`), converters, tests, OpenSpec root specs after archive.
- **Wire / storage JSON**: Any consumer expecting `paramsName` / `materials` / `materialsName` must switch to `name` / `materialType` / `materialName` in lockstep (user handles cloud and other endpoints).
- **Existing DB rows**: After migration, column names change; existing **`processParametersJson`** strings in `t_params_process_video` still contain old keys until re-saved or migrated separately — user chose no compat fields; design calls out optional one-time JSON rewrite if needed.
