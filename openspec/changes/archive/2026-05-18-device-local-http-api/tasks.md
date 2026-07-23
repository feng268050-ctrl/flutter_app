## 1. Dependencies and shared service

- [x] 1.1 Add NanoHTTPD (or agreed lightweight server) dependency to `app/build.gradle.kts`
- [x] 1.2 Add filtered DAO methods: `countWhereUploadStatusNonZeroFiltered` and `selectPageWhereUploadStatusNonZeroFiltered` with optional `processType`, `startDate`, `endDate`
- [x] 1.3 Implement `ProcessVideoQueryService` (list / getByVideoId / openStreamFile / deleteByVideoId) using `DeviceWsVideoListPayload` for row maps and `ThreadPoolManager` for blocking work
- [x] 1.4 Add unit tests for filter SQL / service pagination defaults and clamped `pageSize` (max 100)

## 2. Local HTTP server

- [x] 2.1 Implement `DeviceLocalHttpServer` singleton: bind `0.0.0.0:8080`, start/stop from `Application`, non-fatal bind failure logging
- [x] 2.2 Route `GET /lasercyber` → 200 + `Hello LaserCyber` plain text
- [x] 2.3 Route `GET /v1/videos` → `ApiResult` with `{ list, total }` and query params `page`, `pageSize`, `processType`, `startDate`, `endDate`
- [x] 2.4 Route `GET /v1/videos/:video_id` → single list-item-shaped `ApiResult.data` or not-found failure
- [x] 2.5 Route `GET /v1/videos/:video_id/stream` → file stream with video content type; 404 when missing
- [x] 2.6 Route `DELETE /v1/videos/:video_id` → `ApiResult` success/failure via shared delete helper
- [x] 2.7 Add instrumented or unit tests with NanoHTTPD test client / MockWebServer-style local calls for probe + list + 404 paths

## 3. WebSocket extensions

- [x] 3.1 Extend `handleInboundVideoListRequest` to parse `process_type`, `start_date`, `end_date` and call shared list service
- [x] 3.2 Add `command.delete_video` branch in `DeviceWebSocketConnectionManager`: validate `video_id`, delete off main thread, send `command.delete_video_ack` via same helper shape as `sendUploadVideoAck` (`request_id` + `data.success` / `data.message`)
- [x] 3.3 Add tests for WS list filters and delete ack correlation (mirror existing `DeviceWsVideoListPayloadTest` style)

## 4. Integration and docs

- [x] 4.1 Refactor `ProcessVideoViewModel.delete` to delegate file+DB delete by `videoId` to shared helper where practical (keep UI local-id lookup unchanged)
- [x] 4.2 Update `docs/network-api-reference.md` (or device onboarding doc) with local HTTP base `http://<lan-ip>:8080` and endpoint summary

## 5. Video upload (follow-up)

- [x] 5.1 `POST /v1/videos` multipart ingest (`ProcessVideoLocalUpload`)
- [x] 5.2 Background cover upload via `ProcessVideoCoverWorker` + `ProcessVideoCoverR2Upload`
