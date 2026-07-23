## Context

Engineer-mode process presets live in Room table **`t_process_parameters_data`** (`ProcessParametersData`). The UI loads list summaries via `ProcessParametersDataDao.selectEngineerAllName(processType)` (`ProcessParametersNameData`: `id`, `name`, `dataType`, `processType`, `materialType`, `materialName`) and full rows via `selectEngineerById`. Only rows with **`dataType`** in **`ENGINEER_MODE_DEFAULT_DATA` (1)** or **`ENGINEER_MODE_CUSTOM_DATA` (2)** participate in engineer pages; quick-mode (`0`) and video-embedded (`3`) rows are out of scope.

Remote **process videos** already use `DeviceWsVideoListPayload` + `ProcessVideoQueryService` + `DeviceLocalHttpServer` routes under **`/v1/videos`**. Process library remote management should mirror that split: one domain service, two transports, identical business semantics.

Existing UI flows to align with:

| UI action | ViewModel method | Remote command |
| --- | --- | --- |
| Open preset list | `selectEngineerAllName` | `process_library_request` |
| Switch active preset | `switchProcessParametersData` + `ENGINEER_DATA_CACHE_KEY` | `process_parameters_set_default` |
| Save as custom preset | `saveCommonlyUsedParameter` | `process_parameters_create` (from default) or `process_parameters_update` (existing custom) |
| Edit fields | `updateDataToDb` | `process_parameters_update` |
| Reset to bundled default | `resetDefaultData` | **not** exposed remotely (delete custom + reload origin) |
| Delete custom row | `deleteById` (via reset path) | `process_parameters_delete` |

Ack frames follow **`command.upload_video_ack`** / **`command.delete_video_ack`**: outbound new top-level `id`, `payload.request_id` = inbound `id`, `payload.data` = `{ success, message }`.

## Goals / Non-Goals

**Goals:**

- Implement all six WS command pairs and six HTTP routes on the existing **`DeviceLocalHttpServer`** (port **8080**).
- Share one **`ProcessParametersRemoteService`** for list/get/create/update/delete/set-default.
- Serialize JSON with **camelCase** property names matching `ProcessParametersData` / Gson defaults.
- WS `payload` uses **snake_case** keys where they differ from camelCase (`process_type`, `request_id`, `material_type` only when needed — prefer mirroring video list: `process_type` in WS, `processType` in HTTP).
- Off-main-thread Room access; update **`ProcessParametersSnapshotStore`** when the active preset changes.

**Non-Goals:**

- Remote management of quick-mode (`QUICK_MODE_DATA`) or video-embedded (`VIDEO_PROCESS_DATA`) rows.
- Replacing cloud **`command.send_process_lib`** OTA bulk library push (unchanged).
- TLS or auth on local HTTP (same LAN trust model as `/v1/videos`).
- Exposing `resetDefaultData` (restore from `originId`) over remote API.
- Changing OTA xlsx import or bundled library bootstrap.

## Decisions

1. **Shared service — `ProcessParametersRemoteService`**
   - **Decision:** Package under `network` or `common/handler`; methods: `listLibrary(processType)`, `getById(id)`, `create(body)`, `update(id, body)`, `delete(id)`, `setDefault(id)`.
   - **Rationale:** Prevents HTTP/WS drift; same pattern as `ProcessVideoQueryService`.

2. **List scope**
   - **Decision:** `process_library_request` / `GET /v1/process-library` return an **array** of summary objects (same fields as `ProcessParametersNameData`), filtered by `process_type` / `processType`, `dataType IN (1, 2)`, ordered **`dataType DESC`** then stable tie-break (e.g. `id DESC`) — matching `selectEngineerAllName`.
   - **Rationale:** Matches engineer popup list; avoids shipping full parameter blobs in list.

3. **Full parameter object**
   - **Decision:** `process_parameters_request` / `GET /v1/process-parameters/:id` return one **`ProcessParametersData`** map (all non-null fields Gson emits; include `id`, `dataType`, `originId`, deprecated fields if present in DB). **WS** responses stringify **`id`** / **`originId`**; **HTTP** `ApiResult.data` MAY use JSON numbers for those fields.
   - **Rationale:** Remote clients need full edit surface; WS safe for JS server, HTTP aligned with existing local API numeric paths.

4. **Create semantics**
   - **Decision:** `process_parameters_create` inserts a row with **`dataType = ENGINEER_MODE_CUSTOM_DATA`**, **`processType`** from payload (required), **`originId`** optional (string or number on WS). Device assigns **`id`** via Room `insert`; WS ack **`data`** MAY include `{ "id": "<decimal string>" }` on success.
   - **Alternative:** Return id only via follow-up GET — rejected (extra round trip).

5. **Update semantics**
   - **Decision:** `process_parameters_update` requires **`id`** in payload; updates only rows with `dataType` custom **or** allows updating default row fields in place when `dataType = DEFAULT`? **Choice:** Allow update for both engineer types; reject updates to rows outside engineer types or wrong `processType`.
   - **Rationale:** UI updates both; remote edit of bundled default is rare but valid for field tuning.

6. **Delete semantics**
   - **Decision:** Only **`ENGINEER_MODE_CUSTOM_DATA`** rows may be deleted remotely; default rows (`ENGINEER_MODE_DEFAULT_DATA`) return ack/HTTP failure with clear message.
   - **Rationale:** Matches `resetDefaultData` which deletes custom then reloads origin — defaults are restored by OTA/import, not DELETE.

7. **Set default semantics**
   - **Decision:** `process_parameters_set_default` carries **`id`** only (WS `payload.id`). The device loads the row, rejects if missing or not engineer-mode, then writes **`MemoryCacheManager`** key `ENGINEER_DATA_CACHE_KEY + row.processType` with that row (same as `switchProcessParametersData` + cache observer). **`processType`** is derived from the stored row, not from the request. Does **not** change `dataType` or DB ordering.
   - **Rationale:** “设为默认参数” = **switch active preset** for the row’s process type; create/update persist custom rows separately.

8. **HTTP route map (camelCase params)**

| WS `type` | HTTP | Notes |
| --- | --- | --- |
| `command.process_library_request` | `GET /v1/process-library?processType=` | `data` = array |
| `command.process_parameters_request` | `GET /v1/process-parameters/:id` | `data` = object |
| `command.process_parameters_create` | `POST /v1/process-parameters` | JSON body = fields without `id` |
| `command.process_parameters_update` | `PUT /v1/process-parameters/:id` | body = partial or full object |
| `command.process_parameters_delete` | `DELETE /v1/process-parameters/:id` | |
| `command.process_parameters_set_default` | `POST /v1/process-parameters/:id/set-default` | no body; `:id` = Room primary key |

9. **`ApiResult`**
   - **Decision:** List/get success: `data` = array or object directly. Mutations: `success` + optional `data` (e.g. new `id`). Failure: `success: false`, `message` set, `code` e.g. 400/404.
   - **Rationale:** Same as `/v1/videos` handlers via `DeviceApiResultHttp`.

10. **DAO additions**
    - **Decision:** Add synchronous (non-LiveData) queries for background executor: `List<ProcessParametersNameData> selectEngineerAllNameSync(int processType)`, `ProcessParametersData selectByIdSync(long id)`, reuse `insert`/`update`/`deleteById`.
    - **Rationale:** WS/HTTP handlers cannot use LiveData.

11. **WebSocket dispatch**
   - **Decision:** Extend `DeviceWebSocketConnectionManager.onMessage` with branches; reuse `sendCommandDataAck` for `*_ack` types; use dedicated `sendProcessLibraryResponse` for `process_library_response` / `process_parameters_response` (payload: `request_id` + `data`, like `video_list_response`).
   - **Rationale:** Consistent with existing video list / stat handlers.

12. **WebSocket row ids — string on the wire**
   - **Decision:** Inbound WS `payload.id` / `originId` accept JSON **string or number**; parse via shared helper (e.g. `DeviceWsRowId.parse`) to `long`. Outbound WS list items, full `data` objects, and create-ack `data.id` emit **`id`** and **`originId` as decimal strings**. HTTP `/v1` paths and `ApiResult` keep numeric `id` (no JS bigint issue in URL path from mobile native clients).
   - **Rationale:** Cloud server is JavaScript; Room auto-increment ids can exceed `Number.MAX_SAFE_INTEGER`.
   - **Alternative:** Always number — rejected (server would corrupt large ids).

13. **Validation**
    - **Decision:** Require device **ONLINE** for WS handlers (same as `video_list_request`). HTTP has no ONLINE gate.
    - **Reject** missing `process_type` on list, missing `id` on get/update/delete/set-default (WS `payload.id` or HTTP path `:id`).

## Risks / Trade-offs

- **[Risk] Confusion between set-default vs save-as-custom** → Mitigation: spec names `set_default` as **active preset switch**; document create/update for persisting new custom rows.
- **[Risk] Snapshot stale after remote edit** → Mitigation: call `ProcessParametersSnapshotStore.update` when mutating the row currently cached for that `processType`, or after set-default.
- **[Risk] Concurrent UI + remote writes** → Mitigation: last-write-wins at DB level; acceptable for LAN tooling (same as video delete).
- **[Risk] Large POST bodies** → Mitigation: cap JSON size in HTTP parser if NanoHTTPD allows; optional follow-up.

## Migration Plan

- Ship in normal app release; no DB migration.
- Register new WS types in server/mobile clients in the same release.
- Rollback: remove dispatch branches and HTTP routes; data unchanged.

## Open Questions

- Whether **`process_parameters_create_ack`** / create HTTP should return full created object or only `{ id }` (default: **`{ id }`** plus `success`).
- Whether **PUT** vs **PATCH** for update (default: **PUT** full replacement of provided fields, merge nulls as “leave unchanged” vs Gson null — align with existing local HTTP video POST style).
