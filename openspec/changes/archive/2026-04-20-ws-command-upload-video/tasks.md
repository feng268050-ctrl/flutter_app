## 1. Protocol handling

- [x] 1.1 Add inbound dispatch in `DeviceWebSocketConnectionManager` (or equivalent) for `type` `command.upload_video` when the socket is in the same “online” state used for other handled commands; validate unified envelope and non-empty `payload.videoId`.
- [x] 1.2 Implement outbound `command.upload_video_ack` helper: new top-level `id`, `v`/`ts` per existing patterns, `payload` with `request_id` (inbound top-level `id`) and `data: { success, message }`.
- [x] 1.3 On malformed frames (missing fields, bad types), send failure ack when an inbound top-level `id` exists; otherwise log and drop per existing policy.

## 2. Upload orchestration

- [x] 2.1 Resolve `videoId` string via `ProcessParamsVideo` / DAO to local row primary key; map “not found” to failure ack with non-empty `message`.
- [x] 2.2 Start `MonitorProcessVideoListUploadRunner` (same entry as list upload) with application context; if the monitor **Videos** tab is the active visible host, attach the same `VideoUploadProgressDialog` + `Listener` behavior as manual **Upload**; otherwise use a headless `Listener` (log-only or minimal). Satisfy main-thread expectations of the runner.
- [x] 2.3 Apply the same single-runner cancel/replace semantics as `ProcessVideoViewModel.startMonitorListForegroundUpload` (coordinate with list uploads so two runners do not run concurrently).

## 3. Ack timing and outcomes

- [x] 3.1 Send success ack after validation passes and the runner has been started (or synchronously entered) without waiting for multipart completion or terminal `video.uploading`.
- [x] 3.2 Send failure ack for unknown `videoId`, missing payload, DB errors, or failure to schedule/start the runner; ensure `data.message` is non-empty when `success` is false.

## 4. Verification

- [x] 4.1 Add unit tests for ack JSON shape and `request_id` correlation (mirror patterns from existing WS envelope/command tests).
- [x] 4.2 Add tests or instrumentation tests for resolver + “start runner” branch where feasible; at minimum cover ack success/failure matrix and idempotence of correlation.
