## 1. Snapshot and WebSocket protocol

- [x] 1.1 Expand remote snapshot packer to canonical roots (`staticData` / `deviceInfo` / `commonSettings` / `wifiInfo` null-or-object)
- [x] 1.2 Send `device.online` under `payload.stat`; answer `command.stat_response` with `request_id` + `data`
- [x] 1.3 Lock/unlock without typed ack; clear_alerts + process/video ack shapes per lws-ui
- [x] 1.4 Wire process library/parameters WS request/response and video list/upload/delete (R2 + metadata)
- [x] 1.5 Auth latch clear on successful users probe; boot/Wi‑Fi retry for users probe

## 2. LAN HTTP and mDNS

- [x] 2.1 Process-parameters CRUD + set-default on `:5580`
- [x] 2.2 Monitor/camera routes return structured 501 until backends exist
- [x] 2.3 Withdraw mDNS on Wi‑Fi / LAN address loss

## 3. Origin and registration UX

- [x] 3.1 Restore hyurl candidates for test/prod origin probe
- [x] 3.2 Classify `INVALID_SN` as needs-registration vs empty users as unbound
- [x] 3.3 Registration/bind prompts + Reconnect re-probe paths

## 4. Verification and OpenSpec

- [x] 4.1 Unit tests for snapshot validator helpers and WS ack/carrier shapes
- [x] 4.2 Update OpenSpec main specs + this change deltas; fix Purpose TBD stubs
- [ ] 4.3 Board verify: `device.online` ingest without `VALIDATION_ERROR`; cloud shows online
