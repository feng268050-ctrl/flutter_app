## ADDED Requirements

### Requirement: Record start conflict on device LAN API

When **`POST /v1/camera/record`** receives `{ "switch": "on" }` while PR0 recording is already active, the local HTTP server SHALL return an **`ApiResult` failure** documented alongside other `/v1/camera/record` error codes, with **`recording_in_progress`** and user-visible text **`另一个线程正在录制中`** (localized). Successful `data` shape for start/stop remains `{ "switch": "on" | "off" }`.

#### Scenario: Documented conflict response

- **WHEN** a client sends `POST http://<device-lan-ip>:5580/v1/camera/record` with `{ "switch": "on" }` while recording is already active
- **THEN** `docs/network-api-reference.md` MUST list `recording_in_progress` with the Chinese operator message and MUST state that duplicate `on` is no longer idempotent success
