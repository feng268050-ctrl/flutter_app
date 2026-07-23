## 1. Data access

- [x] 1.1 Add `ProcessProcessVideoDao` queries: count rows `WHERE syncStatus != 0`, and paged `SELECT` with the same filter, `ORDER BY createTime DESC`, reusing the VO column projection pattern used by `selectPage` (no `processData` in list rows).
- [x] 1.2 Verify Room compiles and, if the project uses them, add or extend DAO unit tests for count + page boundaries (empty set, single page, second page).

## 2. WebSocket handling

- [x] 2.1 In `DeviceWebSocketConnectionManager`, handle inbound `type` `command.video_list_request`: validate protocol version and non-empty inbound top-level `id`, require `ONLINE`, parse `page` / `page_size` with defaults and a hard cap on `page_size`.
- [x] 2.2 Run count + list queries off the main thread (same executor pattern as `command.stat_request`), build `payload` with `request_id`, `data.list`, and `data.total`.
- [x] 2.3 Send outbound `command.video_list_response` via `DeviceWebSocketEnvelope.toJson` with a **new** top-level `id`, and add logging consistent with `command.stat_response` for success/failure to send.

## 3. Specification sync

- [x] 3.1 After implementation, fold the delta specs from `openspec/changes/ws-video-list-command/specs/` into `openspec/specs/device-ws-unified-envelope/spec.md` and add `openspec/specs/device-ws-video-list-command/spec.md` (or follow the repo’s archive/apply workflow so published specs match runtime).

## 4. Verification

- [x] 4.1 Manually or with an integration test: send `command.video_list_request` with sample `page`/`page_size` and confirm `command.video_list_response` `request_id` matches inbound `id`, `total` matches DB count for `syncStatus != 0`, and `list` excludes `syncStatus == 0` rows.
