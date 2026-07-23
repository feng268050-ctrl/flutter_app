## Why

The cloud must be able to start **monitor process video** uploads on the device without someone tapping **Upload** in the app. Today that flow is user-initiated; a server-driven WebSocket command closes the loop so remote operators or automation can enqueue the same upload pipeline the UI already uses.

## What Changes

- Subscribe to inbound WebSocket frames with `type` `command.upload_video` and payload `{ "videoId": "<uuid>" }` (field naming aligned with existing video rows and envelopes).
- On a valid command, start the **same** upload orchestration as the manual **Upload** action for that `videoId` (reuse existing code paths; no parallel implementation). When the user is already on the monitor **Videos** tab, show the same upload progress UI as manual **Upload**; otherwise run without that dialog.
- Send `command.upload_video_ack` after the command is **handled** (accepted and upload started, or rejected with a clear reason). The outbound payload SHALL be `{ "request_id": "<inbound-top-level-id>", "data": { "success": <boolean>, "message": "<string>" } }` where `request_id` is the **top-level** `id` of the inbound `command.upload_video` frame. On failure, `message` SHALL carry a human-readable error; on success, `message` MAY be empty or a short confirmation per app convention.
- The ack MUST NOT wait for the multipart upload or final `video.uploading` terminal state; it only reflects whether the **instruction** was executed correctly (including validation failures such as unknown `videoId` or upload already in progress, as defined in design/spec).

## Capabilities

### New Capabilities

- `device-ws-upload-video-command`: Server-initiated upload trigger, correlation with inbound message `id`, ack payload shape and timing relative to upload lifecycle (ack after start/validation, not after upload completion).

### Modified Capabilities

- `device-ws-unified-envelope`: Add normative inbound envelope for `command.upload_video` and outbound envelope for `command.upload_video_ack`, consistent with existing command/ack pairs (unified top-level fields, `request_id` semantics, new outbound `id` per message).

## Impact

- Device WebSocket connection manager / message router (likely `DeviceWebSocketConnectionManager` and related handlers).
- Video upload / queue code paths shared with the **Upload** UI action.
- Outbound frame construction alongside existing command acknowledgements.
- Tests for envelope parsing, ack correlation, and success/failure branches (invalid id, missing row, etc.).
