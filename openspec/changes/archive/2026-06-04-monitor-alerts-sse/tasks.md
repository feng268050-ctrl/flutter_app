## 1. Shared warn snapshot and change signals

- [x] 1.1 Expose a shared warn-list loader (refactor from `DeviceStatusPut.getWarnList` or equivalent) used by stat packing and the alerts SSE hub
- [x] 1.2 Extend `WarnLogChangedEvent` (or add detail type) for insert vs clear; post after `saveWarnTables` batch insert, `creationAddOrUpdate` insert, lens/camera alarm saves, and after `deleteAll` completes
- [x] 1.3 Wire `WarnLogFragment` / `WarnTableViewModel.deleteAll` to post clear notification on the background thread after DB wipe

## 2. Monitor alerts SSE hub and HTTP route

- [x] 2.1 Add `MonitorAlertsSseJson`, `MonitorAlertsSseHub`, and `MonitorAlertsHttpPublisher` (fan-out, `list` on connect, `new`/`clear` from EventBus, 15s `heartbeat`, `SseFlushingResponse`)
- [x] 2.2 Register `GET /v1/monitor/alerts` in `DeviceLocalHttpServer`
- [x] 2.3 Add unit tests for hub: initial `list`, `new` fan-out, `clear`, heartbeat, two subscribers

## 3. WebSocket clear alerts command

- [x] 3.1 Handle inbound `command.clear_alerts` in `DeviceWebSocketConnectionManager` (online gating, empty payload)
- [x] 3.2 Run `deleteAll` off main thread; on success notify alerts hub and send `command.clear_alerts_ack` via `sendCommandDataAck`
- [x] 3.3 Add tests or extend `DeviceWebSocketConnectionTest` for ack shape (`request_id`, `data.success`, `data.message`)

## 4. Documentation

- [x] 4.1 Update `docs/network-api-reference.md` Monitor section with `/v1/monitor/alerts` events (`list`, `new`, `clear`, `heartbeat`) and curl example
- [x] 4.2 Document `command.clear_alerts` / `command.clear_alerts_ack` in `docs/device-websocket-migration.md` or network API reference
