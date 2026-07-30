## MODIFIED Requirements

### Requirement: Online snapshot and stat responses

On successful WebSocket connect, the system SHALL send `device.online` with a remote snapshot under **`payload.stat`**. The snapshot MUST be acceptable to the cloud canonical validator: `staticData`, `deviceInfo`, and `commonSettings` (or legacy `advancedSettings`) as objects; `deviceStatus` / `deviceData` as objects or null; `warns` as an array. `wifiInfo` MUST be a Wi‑Fi detail object or JSON `null` (not `{}`). The system SHALL answer `command.stat_request` with `command.stat_response` whose payload uses **`request_id`** (inbound frame id) and **`data`** (same snapshot shape as `payload.stat`).

#### Scenario: Online sent after connect

- **WHEN** the WebSocket connection becomes ready
- **THEN** the system MUST send a `device.online` envelope whose `payload.stat` includes a remote snapshot object

#### Scenario: Stat response carrier

- **WHEN** the device answers `command.stat_request`
- **THEN** the outbound `command.stat_response` payload MUST include `request_id` and `data` (MUST NOT place the snapshot under `stat`)

### Requirement: Non-OTA command dispatch

The system SHALL handle at least: `command.send_process_param`, `command.send_process_lib`, process-library CRUD request/response types used by lws-ui, process-parameters list/CRUD/set-default request/response types, `command.video_list_request`, `command.upload_video`, `command.delete_video`, `command.lock`, `command.unlock`, `command.clear_alerts`, and `command.disconnect`. Process-library writes MUST go through the shared local importer/rules when wired (structured failure when not). Acknowledgements MUST follow lws-ui ack naming for implemented commands. `command.lock` / `command.unlock` MUST NOT send a typed ack.

#### Scenario: Remote lock command persists

- **WHEN** `command.lock` is received on an active connection
- **THEN** the device MUST enter the locked state
- **AND** subsequent snapshot payloads MUST report locked
- **AND** the device MUST NOT emit `command.lock_ack`

### Requirement: Auth failure classification

When the WebSocket handshake fails with HTTP `401`, the connection closes with auth-invalid classification, or the users probe / upgrade path reports Worker `INVALID_SN`, the system MUST enter an auth-error offline state, MUST NOT schedule exponential-backoff reconnect for that failure, and MUST surface the registration UI defined by `device-registration-ui`. When a later users probe succeeds (`ok`), the system MUST clear the auth latch and MAY reconnect (`resumeAfterAuth`).

#### Scenario: Handshake 401 suppresses backoff reconnect

- **WHEN** the WebSocket upgrade fails with HTTP `401`
- **THEN** the system MUST NOT schedule automatic backoff reconnect for that failure
- **AND** the registration UI MAY be shown when a foreground route is available

#### Scenario: Valid users clears auth latch

- **WHEN** the auth latch is set after `INVALID_SN` or `401`
- **AND** a subsequent users probe returns success (`ok`)
- **THEN** the system MUST clear the auth latch
- **AND** MUST allow a new `/ws/device` connect attempt

## ADDED Requirements

### Requirement: Ack and lock semantics (lws-ui parity)

`command.lock` / `command.unlock` MUST persist remote lock state and MUST NOT send a typed ack. `command.clear_alerts` MUST clear local alarm history and reply with `command.clear_alerts_ack` using `payload.request_id` and `payload.data.{success,message}`. Process push acks (`command.send_process_param_ack` / `command.send_process_lib_ack`) MUST use `payload.request_id`, `payload.code` (200|500), and `payload.message`. Video and process-parameters mutation acks MUST use the `request_id` + `data.{success,message}` shape.

#### Scenario: Lock without ack

- **WHEN** the server sends `command.lock`
- **THEN** the device MUST set the persisted lock flag and MUST NOT emit `command.lock_ack`

#### Scenario: Clear alerts ack shape

- **WHEN** the server sends `command.clear_alerts`
- **THEN** the device MUST clear local alarm history
- **AND** MUST reply with `command.clear_alerts_ack` whose payload includes `request_id` and `data.success`
