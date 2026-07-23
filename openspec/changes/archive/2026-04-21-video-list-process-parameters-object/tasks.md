## 1. Data model and persistence

- [x] 1.1 Rename `ProcessParamsVideo` string field from `processData` to `processParametersJson` (Lombok getters/setters); add Room `@ColumnInfo` or migration to align SQLite column name per design (prefer migration renaming `processData` → `processParametersJson`).
- [x] 1.2 Bump `AppDatabase` version and add migration copying/rename column; register migration; update exported schema JSON if the repo tracks it.
- [x] 1.3 Update `ProcessParamsVideoVo` / `ProcessProcessVideoDao` `@Query` column lists and any `@Embedded` / constructors to use `processParametersJson`.
- [x] 1.4 Replace all Java call sites (`setProcessData`, `getProcessData`, Gson fields, tests) with `processParametersJson` equivalents.
- [x] 1.5 Remove legacy `status`: drop Room field `ProcessParamsVideo.status`, remove `ProcessProcessVideoDao.updateStatus` and all callers (`CameraController`, `ProcessVideoViewModel`, `DeviceWebSocketConnectionManager`); extend migration to `DROP`/recreate column `status` on `t_params_process_video`.

## 2. WebSocket list payload

- [x] 2.1 In `DeviceWsVideoListPayload.voToRow` (or helper used only from the video-list worker), parse `processParametersJson` with Gson into a `JsonElement`; if result is a JSON object, put map entry `processParameters` with that element; otherwise put `processParameters` → `null`. Remove wire key `processData`.
- [x] 2.2 Ensure parsing runs only on the existing background executor path for `command.video_list_request` (no main-thread parse).
- [x] 2.3 Update `DeviceWsVideoListPayloadTest` (and any WS integration tests) for `processParameters` object / null and absence of `processData`.

## 3. Related payloads and docs

- [x] 3.1 Review `DeviceWsVideoMetadataPayload` and HTTP beans; rename or alias fields to `processParametersJson` where they mirror the same DB column for consistency; **remove** `status` from `video.metadata` serialization and update `DeviceWsVideoMetadataPayloadTest`.
- [x] 3.2 Update in-repo OpenAPI / markdown references that mention list-item `processData` for `command.video_list_response` (if any).

## 4. Verification

- [x] 4.1 Run unit tests for affected modules; manually sanity-check one `command.video_list_response` frame: valid JSON → nested object under `processParameters`; garbage → `null`.
