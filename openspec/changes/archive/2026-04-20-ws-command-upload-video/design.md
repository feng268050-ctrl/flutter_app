## Context

The app already uploads monitor list videos through `ProcessVideoFragment` → `ProcessVideoViewModel.startMonitorListForegroundUpload(rowId, listener)`, which owns at most one `MonitorProcessVideoListUploadRunner` and cancels any previous runner when starting a new one. The runner performs metadata (when needed) and STS multipart upload and is the canonical implementation for **Videos** tab uploads.

Inbound WebSocket commands are dispatched today in `DeviceWebSocketConnectionManager` (for example `command.video_list_request`), using the unified envelope (`v`, `type`, `id`, `ts`, `payload`) and sending responses with a **new** top-level `id` while correlating via `request_id` in the payload.

The manual list action passes the Room row primary key (`ProcessParamsVideo.id`) into the runner. The server contract for this change uses **`videoId`** in the command payload as the **business UUID** (`ProcessParamsVideo.videoId`), which the app must resolve to a local row before starting the runner.

## Goals / Non-Goals

**Goals:**

- Handle `command.upload_video` on the device WebSocket and resolve `payload.videoId` to a persisted `t_params_process_video` row.
- Start the same upload pipeline as the **Upload** list action (`MonitorProcessVideoListUploadRunner` / equivalent `runForeground` entry used from `ProcessVideoViewModel`), without requiring the monitor UI to be open.
- Send `command.upload_video_ack` promptly with `request_id` equal to the inbound frame’s top-level `id`, and `data.success` / `data.message` reflecting whether the **command** was executed (validation + enqueue / start), not whether the file reached the cloud.
- Follow existing envelope rules: outbound ack uses a newly generated top-level `id`; `v` and `ts` consistent with other device-originated frames.

**Non-Goals:**

- Waiting for upload completion or mirroring final `video.uploading` / DB terminal state inside the ack.
- Changing server-side upload APIs, presigning, or `video.uploading` reporting semantics.
- Replacing or refactoring the entire upload stack; only add a WebSocket entry point and ack.

## Decisions

1. **Resolve `videoId` (UUID) to a local row**  
   **Decision:** Look up `ProcessParamsVideo` by `videoId` string in the DAO; use the row’s primary key `id` as `rowId` for `MonitorProcessVideoListUploadRunner.runForeground`.  
   **Rationale:** Matches domain naming in `device-ws-video-metadata` / `video.uploading` specs and the user’s payload. Manual UI currently passes `id`; resolution keeps one runner API.  
   **Alternative considered:** Require the server to send numeric row id — rejected to align with stated `{ videoId }` contract.

2. **Progress UI for WS-triggered uploads**  
   **Decision:** Always use the same runner and ack rules; **if** the monitor **Videos** tab is currently the active, user-visible context (same screen where manual **Upload** would show `VideoUploadProgressDialog`), the implementation SHOULD show that same progress dialog and wire the runner’s `Listener` to update/dismiss it—matching manual upload UX. **If** the Videos UI is not in the foreground (or no suitable `Activity`/`Fragment` host exists), use a headless listener (log-only or minimal telemetry) so the upload still runs without blocking or leaking dialogs.  
   **Rationale:** Remote start should feel identical to tapping **Upload** when the user is already on the list; when they are elsewhere, avoid orphaned UI from a non-UI entry point.  
   **Alternative considered:** Always headless — rejected per product preference; always show dialog — rejected as unsafe without a resumed host Activity.

3. **Concurrency with an in-flight list upload**  
   **Decision:** Reuse the **single-runner** policy of `ProcessVideoViewModel.startMonitorListForegroundUpload`: starting a new upload cancels the previous `MonitorProcessVideoListUploadRunner`. A remotely accepted `command.upload_video` SHALL follow that same policy so behavior matches the list **Upload** button (including switching from row A to row B).  
   **Rationale:** Matches the user requirement that the remote path behave like the manual one at the orchestration layer.  
   **Alternative considered:** Reject new commands while busy — rejected as diverges from ViewModel semantics.

4. **Where to handle the command**  
   **Decision:** Extend `DeviceWebSocketConnectionManager` (or the same layer that handles `command.video_list_request`) with a branch for `command.upload_video`, reuse envelope parsing/validation, and a small helper to build/send `command.upload_video_ack` JSON.  
   **Rationale:** Keeps protocol handling in one place and matches existing patterns.

5. **Ack timing**  
   **Decision:** Send ack after synchronous validation (envelope, `videoId` present, row found, state allows starting upload) and after `runForeground` has been **scheduled** or **synchronously entered** such that a duplicate command would observe “already uploading” — still **before** multipart completion. If validation fails, send failure ack immediately.

## Risks / Trade-offs

- **[Risk] ViewModel and WS each owning a runner** → Mitigation: prefer one application-level owner for `MonitorProcessVideoListUploadRunner` (or route WS through the same coordinator the list uses) so cancel/replace semantics stay consistent; cover with tests.
- **[Risk] `videoId` valid on server but missing locally** → Mitigation: failure ack with explicit message; log inbound `id` for support.
- **[Trade-off] Dialog only when Videos is visible** → When the user is not on the Videos tab, they rely on `video.uploading` / DB state like today; when they are on the tab, they get the same dialog as manual upload.

## Migration Plan

No data migration. Deploy with app update; server can gate sending `command.upload_video` until clients reach the min version that sends `command.upload_video_ack`.

## Open Questions

- Exact copy for success `message` (empty vs localized short string) — pick one consistent with other acks in the app.
