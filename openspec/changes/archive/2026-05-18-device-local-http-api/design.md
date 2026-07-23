## Context

The Android HMI app persists process videos in Room (`t_params_process_video` / `ProcessParamsVideo`). Remote inventory already flows over **outbound** WebSocket: `command.video_list_request` → `command.video_list_response`, with list rows built by `DeviceWsVideoListPayload` and filtered to **`uploadStatus != 0`**. Local UI delete removes the filesystem file then `deleteById` on the local row id. There is **no** embedded HTTP server today; OkHttp is used only as a **client** to Worker APIs.

Mobile onboarding docs reference mDNS discovery; this change adds a **stable local REST surface** on port **8080** for the same video operations, plus a probe path for app connectivity checks.

## Goals / Non-Goals

**Goals:**

- Run a small HTTP server on **`0.0.0.0:8080`** for LAN/direct access.
- Implement the six routes/commands in the proposal with **`ApiResult`** JSON (except `/lasercyber` plain text).
- Reuse **`DeviceWsVideoListPayload`** row maps for HTTP `data.list` / single-video `data`.
- Extend list filtering for **`processType`** / date range on **both** HTTP query params and WS `process_type` / `start_date` / `end_date`.
- Implement **`command.delete_video`** / **`command.delete_video_ack`** mirroring HTTP DELETE.

**Non-Goals:**

- TLS termination on device (cleartext local HTTP only).
- Authentication on local HTTP (trust LAN boundary; same class of exposure as mDNS TXT).
- Cloud Worker API changes or uploading videos via this server.
- Changing `uploadStatus` visibility rule (`!= 0`) for list endpoints.

## Decisions

1. **HTTP stack — NanoHTTPD**  
   **Decision:** Add `org.nanohttpd:nanohttpd` (or maintained fork) as the embedded server.  
   **Rationale:** Minimal footprint, widely used on Android for LAN APIs; no servlet container.  
   **Alternative:** Ktor CIO — heavier dependency and coroutine surface for a handful of routes.

2. **Server lifecycle**  
   **Decision:** Start/stop from an `Application`-scoped component (e.g. `DeviceLocalHttpServer` singleton) when application context is available; bind `0.0.0.0:8080`. Log bind failures; do not crash the process.  
   **Rationale:** Matches “always on while app runs” for factory/LAN tools.  
   **Alternative:** Tie strictly to mDNS publish — rejected because HTTP should be reachable even if discovery TXT fails.

3. **Shared domain service — `ProcessVideoQueryService` (name TBD)**  
   **Decision:** One class (package under `network` or `common/handler`) exposing:
   - `list(page, pageSize, processType, startDate, endDate)` → `{ list, total }`
   - `getByVideoId(videoId)` → row map or null
   - `openVideoStream(videoId)` → `File` / stream + content type
   - `deleteByVideoId(videoId)` → success / error  
   Used by `DeviceWebSocketConnectionManager`, NanoHTTPD router, and optionally refactored from `ProcessVideoViewModel.delete` (local id path unchanged for UI).  
   **Rationale:** Prevents HTTP/WS drift on filters and delete semantics.

4. **Filter field naming (1:1 with persistence)**  
   **Decision:**
   - HTTP query **`processType`** (camelCase) and WS payload **`process_type`** (snake_case) both filter the **`processType`** column when present (integer; `ModelConstant` 工艺类型 0–5).
   - HTTP **`startDate`** / **`endDate`** and WS **`start_date`** / **`end_date`** filter **`createTime`** (epoch ms): inclusive lower bound on `start`, inclusive upper bound on `end` when provided; omitted bounds mean open-ended.  
   **Rationale:** Wire names mirror the stored field / list JSON key `processType`; only HTTP vs WS casing convention differs.  
   **Alternative:** Filter inside `processParameters` JSON — rejected (slower, ambiguous).

5. **DAO queries**  
   **Decision:** Add `countWhereUploadStatusNonZeroFiltered(...)` and `selectPageWhereUploadStatusNonZeroFiltered(...)` with optional `AND processType = :processType` and `AND createTime >= :start` / `<= :end` (Room nullable args).  
   **Rationale:** Keeps filtering in SQLite; same path for HTTP and WS.

6. **`ApiResult` JSON**  
   **Decision:** Serialize using existing `ApiResult` shape (`success`, `code`, `message`, `data`) and Gson; success `code` **200**, logical failures use `success: false` with appropriate `code`/`message` (e.g. 404 video not found).  
   **Rationale:** Consistent with Worker clients already in the repo.

7. **Stream endpoint**  
   **Decision:** `GET /v1/videos/:video_id/stream` serves bytes from `ProcessParamsVideo.videoPath` with `Content-Type: video/mp4` (or sniff from extension); support `Range` if NanoHTTPD helper allows, otherwise full file 200. Return 404 `ApiResult` or plain 404 if file missing.  
   **Rationale:** Direct device playback for mobile app.

8. **Delete semantics**  
   **Decision:** Resolve by business **`videoId`** (UUID string), not local row `id`. Delete local file when `videoPath` exists (log failure but still attempt DB delete if file already gone — align with `ProcessVideoViewModel` behavior).  
   **WS ack:** `command.delete_video_ack` with the same payload shape as `command.upload_video_ack`: `payload.request_id` = inbound top-level `id`, `payload.data` = `{ "success", "message" }` (see `sendUploadVideoAck`).

9. **WebSocket `command.video_list_request` extension**  
   **Decision:** Parse new optional payload fields in existing handler; pass into shared list service. **No** breaking change to required fields (`page`, `page_size` remain as today).

10. **Path parameter name**  
    **Decision:** Route template `/v1/videos/:video_id` uses **business** `videoId` string from DB, not numeric local `id`.

## Risks / Trade-offs

- **[Risk] Port 8080 conflict** with legacy fallback API host `http://47.86.53.176:8080` — that is **remote**; local bind on device is independent. Document that mobile must target **device LAN IP**, not the fallback Worker host.  
- **[Risk] Cleartext video on LAN** → Accept for factory Wi‑Fi; do not expose beyond LAN interface.  
- **[Risk] Main-thread DB** → All handlers MUST dispatch to `ThreadPoolManager.getExecutor()` like existing WS list handler.  
- **[Risk] Large video streams blocking NanoHTTPD thread** → Use streaming response / chunked read; cap concurrent streams if needed in follow-up.

## Migration Plan

- Ship behind normal app release; no DB migration required for HTTP itself.
- Optional follow-up: DAO migration only if filter indexes needed (not required for v1).
- Rollback: stop starting local server (feature flag or revert) — no data migration.

## Open Questions

- Whether mobile expects **`Range`** support on stream (default: best-effort full file).
- Exact failure body for `/lasercyber` on server error (non-goal unless product requires).
