## 1. Data access and domain service

- [x] 1.1 Add sync DAO methods: `selectEngineerAllNameSync(processType)`, `selectByIdSync(id)` on `ProcessParametersDataDao`
- [x] 1.2 Implement `ProcessParametersRemoteService` (list, get, create, update, delete, setDefault) with engineer-mode validation and custom-only delete rule
- [x] 1.3 Add WS helpers: parse inbound `id`/`originId` from string or number (`DeviceWsRowId` or similar); serialize outbound list/full/ack with string `id`/`originId`; map snake_case (`process_type`, `material_type`, `material_name`) to `ProcessParametersData`
- [x] 1.4 Wire `ProcessParametersSnapshotStore.update` and `ENGINEER_DATA_CACHE_KEY` updates when set-default or mutating the active preset

## 2. WebSocket commands

- [x] 2.1 Dispatch inbound types in `DeviceWebSocketConnectionManager`: `process_library_request`, `process_parameters_request`, `process_parameters_create`, `process_parameters_update`, `process_parameters_delete`, `process_parameters_set_default` (ONLINE gate, background executor)
- [x] 2.2 Implement `sendProcessLibraryResponse` / `sendProcessParametersResponse` (payload: `request_id`, `data`)
- [x] 2.3 Implement `*_ack` sends via `sendCommandDataAck` (include optional `id` in create ack `data`)
- [x] 2.4 Add unit tests for ack/response JSON shape (mirror `DeviceWebSocketConnectionTest` video/delete patterns)

## 3. Local HTTP API

- [x] 3.1 Register routes on `DeviceLocalHttpServer`: `GET /v1/process-library`, `GET/POST/PUT/DELETE /v1/process-parameters`, `POST /v1/process-parameters/:id/set-default` (no body)
- [x] 3.2 Return `ApiResult` via `DeviceApiResultHttp` for all routes; parse camelCase query/body
- [x] 3.3 Add `DeviceLocalHttpServerTest` cases for list, get, create, update, delete (default rejected), set-default

## 4. Documentation

- [x] 4.1 Update `docs/network-api-reference.md` with WS command table and `/v1` HTTP route table for process library
- [x] 4.2 Note `set_default` = active preset switch vs create/update = persist custom row (per design)
