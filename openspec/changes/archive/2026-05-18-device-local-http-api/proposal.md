## Why

Mobile apps and LAN clients need to discover the HMI device and read or manage process videos **without** going through the cloud Worker API. Today, video inventory and deletion are only available over the outbound WebSocket to the server (`command.video_list_request` / `command.video_list_response`). A lightweight **on-device HTTP API** on a fixed port enables direct device access (alongside mDNS discovery) while reusing the same persistence and row-serialization rules as the existing WebSocket list command.

## What Changes

- Add an embedded HTTP server bound to **`0.0.0.0:8080`**, started when the app is running and LAN is usable, stopped on teardown.
- **`GET /lasercyber`**: health probe for the mobile app; HTTP **200**, body plain text **`Hello LaserCyber`** (not `ApiResult`).
- **`GET /v1/videos`**: paginated video list with query params `page`, `pageSize`, `processType`, `startDate`, `endDate`; response **`ApiResult`** with `data: { list, total }`; each list item matches `command.video_list_response` row shape.
- **`GET /v1/videos/:video_id`**: single video metadata (same item shape as list rows).
- **`GET /v1/videos/:video_id/stream`**: stream the local video file for that `video_id`.
- **`DELETE /v1/videos/:video_id`**: delete local video file and DB row; **`ApiResult`** envelope.
- **WebSocket** inbound **`command.delete_video`** with `payload.video_id`; respond with **`command.delete_video_ack`** (same semantics as HTTP DELETE).
- **WebSocket** inbound **`command.video_list_request`**: extend `payload` with optional **`process_type`**, **`start_date`**, **`end_date`** (same filter semantics as HTTP query params).
- Extract shared list/filter/delete logic so HTTP and WebSocket paths stay consistent (pagination defaults, `uploadStatus != 0` filter, row serialization via `DeviceWsVideoListPayload`).

## Capabilities

### New Capabilities

- `device-local-http-api`: Embedded server lifecycle, bind address/port, routes (`/lasercyber`, `/v1/videos*`), `ApiResult` JSON responses, streaming, and alignment with existing video row serialization.
- `device-ws-delete-video-command`: Inbound `command.delete_video` / outbound `command.delete_video_ack` envelope, correlation, and delete semantics tied to business `video_id`.

### Modified Capabilities

- `device-ws-video-list-command`: Optional filters (`process_type` / `processType`, `start_date` / `startDate`, `end_date` / `endDate`) applied to count and list queries; shared with HTTP list.
- `device-ws-unified-envelope`: Document extended `command.video_list_request` payload fields and new `command.delete_video` / `command.delete_video_ack` message types.

## Impact

- **New dependency**: lightweight embedded HTTP library (e.g. NanoHTTPD) in `app` module.
- **Code**: new `network/http/local` (or similar) server + route handlers; refactored video list service used by `DeviceWebSocketConnectionManager` and HTTP; DAO queries with optional filters; delete helper shared by HTTP, WS, and existing UI delete path.
- **Security**: LAN-only exposure on device hotspot/LAN; no new cloud surface. Cleartext HTTP on 8080 is intentional for local discovery (complements mDNS).
- **Specs**: new capabilities under `openspec/specs/` after archive; deltas in this change directory during proposal.
