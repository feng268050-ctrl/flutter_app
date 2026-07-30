## Why

Cloud/mobile operators expect HMI device WebSocket behavior to match lws-ui. Partial scaffolding left process push unwired, video list/upload semantics incomplete, lock/disconnect side effects thin, and OTA acks misleading (`ota_deferred`). Full command-matrix parity is required before treating Linux HMI as a drop-in cloud peer.

## What Changes

- Document the full lws-ui device WS command matrix (envelope, payloads, acks, side effects) and HMI gap status in this change’s design.
- Expand `device-cloud-websocket` requirements to cover full non-OTA dispatch plus OTA **protocol** outcomes (no firmware apply in this change).
- Wire process push import (`send_process_param` / `send_process_lib`) with 200/500 acks.
- Align process-library/parameters CRUD shapes (empty library when `process_type` missing, string ids, set-default semantics).
- Align video list filters/pagination, upload ack = accepted/start, emit `video.metadata`, delete error codes.
- Lock: Modbus safety stop + mode eject callback; disconnect: forced suppression + user-visible notice.
- OTA: correct `check_update_ack` / `update_system_ack` data shapes with explicit `error_code` when unsupported; no fake success.

## Capabilities

### New Capabilities

- (none — extends existing cloud WS capability)

### Modified Capabilities

- `device-cloud-websocket`: Full command matrix requirements; process push must apply; video/OTA/lock/disconnect parity; OTA no longer silent no-op with wrong ack shape.

## Impact

- App: `lib/platform/cloud/*`, process library/video repositories, `app.dart` lock/disconnect UX hooks.
- Specs: `openspec/specs/device-cloud-websocket/spec.md`.
- Tests: dispatcher protocol + payload parser/mapper unit tests; board `build-app` / `push-app`.
- Out of scope: full OTA download/apply UI; LAN `:5580` full parity; AI WS (none in lws-ui).
