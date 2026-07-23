## 1. Spec and contract

- [x] 1.1 Read delta specs under `openspec/changes/device-online-ws-stat-sync/specs/` (ADDED / REMOVED / MODIFIED) before coding
- [x] 1.2 After implementation, archive the change so deltas merge into `openspec/specs/` per team process

## 2. Remove `connected` lifecycle dependency

- [x] 2.1 Remove **online state transition** from inbound `type` `connected` in `DeviceWebSocketConnectionManager` (delete or narrow `onConnectedFrameReceived` / `connected` branch so it does not set `ONLINE`)
- [x] 2.2 Move **transition to `ONLINE`** (and backoff reset/cancel-reconnect behavior currently tied to `connected`, if any) to **WebSocket transport open** (`onOpen` / equivalent listener callback) for the active session generation
- [x] 2.3 Decide legacy behavior: if inbound `connected` is still received, **ignore** for state machine (optional log at debug); do not block or delay `device.online`
- [x] 2.4 Update **exponential backoff reset** to run on **transport open** instead of on `connected` receipt
- [x] 2.5 Search codebase/tests/docs for `connected` / `isValidConnectedPayload` assumptions; update or remove tests that required `connected` before online

## 3. `device.online` implementation

- [x] 3.1 On **transport open** for the active session, **immediately** enqueue snapshot build (`DeviceStatusPut().packRemoteSnapshot`) on the same executor pattern as `handleInboundStatRequest`, with null-safe `Utils.getApp()`
- [x] 3.2 Add send path for unified-envelope `device.online` with `payload` = snapshot map (reuse `snapshotToMap` / shared path with `sendStatResponse` so payload matches `command.stat_response`’s `payload.data`)
- [x] 3.3 On snapshot/send failure, log and skip; on generation/socket mismatch before send, drop with diagnostic log; ensure **one** `device.online` attempt per **transport-open** event for a session
- [x] 3.4 Confirm `sendRawJson` / outbound guards align with new **ONLINE** definition (transport-open) so `device.online` is not blocked waiting for removed gating

## 4. Tests and verification

- [x] 4.1 Unit tests: `device.online` envelope and payload shape (`v`, `type`, no `request_id` wrapper, no nested `data` key)
- [x] 4.2 Integration / manual: open WS **without** sending `connected`; confirm `device.online` is sent as soon as transport is up; reconnect and confirm a second push
- [x] 4.3 With backend + user app wired to stored snapshot (if applicable), confirm user app sees fresh data right after device transport connect

## 5. Server coordination (outside this repo if applicable)

- [x] 5.1 Server: stop depending on device processing `connected`; optionally stop emitting `connected`; treat session + `device.online` as source of fresh cache for apps
