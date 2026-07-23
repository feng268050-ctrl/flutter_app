## Why

LAN monitor clients already receive live machine status via `GET /v1/monitor/stat`, but alarm history still requires polling the cloud WebSocket (`command.stat_request` / `command.stat_response`) or inferring changes from the HMI. Remote operators need the same **warn list** as `command.stat_response` `payload.data.warns`, streamed in real time over the device-local HTTP server, plus a cloud path to **clear** stored alarms that stays consistent with what LAN subscribers see.

## What Changes

- Add **LAN local HTTP** endpoint **`GET /v1/monitor/alerts`** as **Server-Sent Events (SSE)** (`text/event-stream`).
- On connect, emit **`event: list`** whose `data` is a JSON array of current warn rows (same source, field set, and localization as `command.stat_response` `payload.data.warns`).
- When new warns are persisted, emit **`event: new`** with a single warn object per insertion (or per batch insert, one event per row).
- When warns are cleared (local UI or remote command), emit **`event: clear`** so subscribers drop the in-memory list.
- Handle inbound WebSocket **`command.clear_alerts`** with empty `payload` (unified envelope); respond with **`command.clear_alerts_ack`** using the same `payload` shape as `command.upload_video_ack` (`request_id`, `data.success`, `data.message`).
- Remote clear SHALL call the same persistence path as on-device “clear alarm log” (`WarnTableViewModel.deleteAll` / Room `warn_table` wipe).

## Capabilities

### New Capabilities

- `device-local-http-monitor-alerts-sse`: `GET /v1/monitor/alerts` SSE with `list` / `new` / `clear` events, fan-out hub, heartbeat, warn payload parity with `command.stat_response` `warns`.
- `device-ws-clear-alerts-command`: Inbound `command.clear_alerts`, outbound `command.clear_alerts_ack`, background execution, and notification of the alerts SSE publisher.

### Modified Capabilities

- `device-local-http-api`: Document the new `/v1/monitor/alerts` route on the embedded HTTP server alongside `/v1/monitor/stat`.

## Impact

- **API surface**: New route on `DeviceLocalHttpServer`; extends `docs/network-api-reference.md` Monitor section.
- **Runtime**: Event-driven fan-out from warn DB writes and clears; must not block Modbus/UI threads.
- **WebSocket**: New command branch in `DeviceWebSocketConnectionManager` next to existing `command.*` handlers.
- **Data**: Reuses `WarnTable` / `WarnTableViewModel`; may broaden `WarnLogChangedEvent` posting when warns are inserted (today only some paths post it).
