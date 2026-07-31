# device-cloud-websocket Specification

## Purpose

Outbound device WebSocket to the pinned Worker origin: lifecycle, unified envelope, canonical online/stat snapshots, full non-OTA command dispatch matching lws-ui, ack semantics, lock/disconnect side effects, process push import, video lifecycle, OTA protocol acknowledgements (apply deferred), and auth-failure classification for registration UX.

## Requirements

### Requirement: Network-driven WebSocket lifecycle

After first frame, when a suitable network is available and an API origin is pinned, the system SHALL connect to `/ws/device` using a proxy-aware WebSocket client. Connectivity loss MUST close or reset the session; recovery MUST reconnect unless forced-disconnect suppression is active. The system MUST NOT start the device WebSocket from `main()` before the first frame. While connected, the client SHALL enable WebSocket protocol ping/pong (default interval 30s, matching lws-ui) so idle proxies and NAT timeouts do not leave a half-open session without reconnect.

#### Scenario: Connect after pin and network available

- **WHEN** a pinned API origin exists and a suitable network is available after first frame
- **THEN** the system MUST attempt a WebSocket connection to the derived `/ws/device` URL

#### Scenario: Transport keepalive detects dead sockets

- **WHEN** the device WebSocket is connected
- **THEN** the client MUST send protocol-level ping frames on a bounded interval
- **AND** a missed pong MUST close the socket so backoff reconnect can run (unless forced-disconnect or auth latch is active)

#### Scenario: Forced disconnect suppresses auto-reconnect

- **WHEN** the server sends `command.disconnect` (or equivalent forced-evict)
- **THEN** the system MUST close the socket and MUST NOT auto-reconnect until an explicit user or network-policy retry clears suppression

### Requirement: Unified message envelope

Inbound and outbound device WebSocket messages SHALL use JSON envelope fields `v`, `type`, `id`, `ts`, and `payload` (version `1` unless a later negotiated version is specified). Unknown non‑OTA `type` values MUST be logged and MUST NOT crash the process. Legacy `connected` and inbound `ack` MUST be ignored. Frames with `v` not equal to `1` MUST be discarded.

#### Scenario: Malformed envelope is ignored safely

- **WHEN** an inbound frame is not valid envelope JSON
- **THEN** the system MUST discard it without terminating the Flutter process

### Requirement: Online snapshot and stat responses

On successful WebSocket connect, the system SHALL send `device.online` with a remote snapshot under **`payload.stat`**. The snapshot MUST be acceptable to the cloud canonical validator and MUST match lws-ui `DeviceStatusPut.packRemoteSnapshot` field assembly: `staticData`, `deviceInfo` (identity + Modbus info: `firmwareVersion` from control-card software version, `gunSn` / laser / wire-feeder / gun-head version strings, `processLibVersion`, camera/host/focus fields), and `commonSettings` (or legacy `advancedSettings`) as objects; `deviceStatus` / `deviceData` as objects packed from live Modbus status/data (camelCase segment/telemetry fields, plus `cameraStatus` 0|1); `warns` as an array of WarnTable-shaped rows from persisted alarm history (`id`, `code`, `content`, `time`, `newTime`, `level`, `ymdDate`, `hmDate`); optional `processParameters`; `isLocked`; `wifiInfo` as a Wi‑Fi detail object or JSON `null` (not `{}`). Packed `deviceData` gun temperatures MUST use lws-ui register-scale `*TempRaw` ints (×10 °C), same rule as LAN Monitor SSE (`device-local-http-api`). The system SHALL answer `command.stat_request` with `command.stat_response` whose payload uses **`request_id`** (inbound frame id) and **`data`** (same snapshot shape as `payload.stat`).

#### Scenario: Online sent after connect

- **WHEN** the WebSocket connection becomes ready
- **THEN** the system MUST send a `device.online` envelope whose `payload.stat` includes a remote snapshot object

#### Scenario: Stat response carrier

- **WHEN** the device answers `command.stat_request`
- **THEN** the outbound `command.stat_response` payload MUST include `request_id` and `data` (MUST NOT place the snapshot under `stat`)

#### Scenario: Warns come from alarm history

- **WHEN** the device has persisted alarm-log rows
- **AND** it sends `device.online` or `command.stat_response`
- **THEN** `warns` MUST include those rows in WarnTable field shape (MUST NOT always be an empty array while history exists)

### Requirement: Ack and lock semantics (lws-ui parity)

`command.lock` / `command.unlock` MUST persist remote lock state, apply lock safety side effects, and MUST NOT send a typed ack. `command.clear_alerts` MUST clear local alarm history and reply with `command.clear_alerts_ack` using `payload.request_id` and `payload.data.{success,message}`. Process push acks (`command.send_process_param_ack` / `command.send_process_lib_ack`) MUST use `payload.request_id`, `payload.code` (200|500), and `payload.message`. Video and process-parameters mutation acks MUST use the `request_id` + `data.{success,message}` shape.

#### Scenario: Lock without ack

- **WHEN** the server sends `command.lock`
- **THEN** the device MUST set the persisted lock flag and MUST NOT emit `command.lock_ack`

#### Scenario: Clear alerts ack shape

- **WHEN** the server sends `command.clear_alerts`
- **THEN** the device MUST clear local alarm history
- **AND** MUST reply with `command.clear_alerts_ack` whose payload includes `request_id` and `data.success`

### Requirement: Remote lock safety stop and mode eject

On `command.lock`, the system MUST persist the lock flag, MUST write Modbus control bits to clear laser enable, manual gas, and wire-feed job bits (best-effort), MUST eject or block Quick/Engineer/Monitor sessions when active, MUST enqueue remote-lock feedback on the global prompt queue when a UI host is available, and MUST NOT send a lock ack. On `command.unlock`, the system MUST clear the lock flag and dismiss the remote-lock global prompt entry (and any visible lock dialog), with no ack.

#### Scenario: Lock clears emission controls

- **WHEN** `command.lock` is received
- **THEN** the device MUST set persisted lock true
- **AND** MUST attempt to clear laser enable and related job control bits on Modbus
- **AND** MUST NOT emit `command.lock_ack`

### Requirement: Forced disconnect notice

On `command.disconnect`, the system MUST close the socket, MUST suppress auto-reconnect for the process lifetime until an explicit retry clears suppression, and MUST surface a user-visible notice when a foreground UI host is available.

#### Scenario: Disconnect suppresses reconnect

- **WHEN** `command.disconnect` is received
- **THEN** the WebSocket MUST disconnect with forced suppression
- **AND** MUST NOT schedule backoff reconnect until suppression is cleared

### Requirement: Full device WebSocket command matrix

The device WebSocket SHALL implement the lws-ui command set for envelope `v=1` frames: unsolicited `device.online`; request/response pairs for stat, process push, process library/parameters CRUD, video list/upload/delete; lock/unlock/disconnect without typed ack; and OTA check/update with protocol-shaped acknowledgements. Unknown types MUST be logged without crashing. Legacy `connected` and inbound `ack` MUST be ignored.

#### Scenario: Envelope version mismatch discarded

- **WHEN** an inbound frame has `v` not equal to `1`
- **THEN** the system MUST discard the frame without applying side effects

### Requirement: Process push import

`command.send_process_param` and `command.send_process_lib` MUST accept legacy push envelopes (`data`/`msgType`/…) or bare business objects. Successful param import MUST persist a user/cloud preset. Successful lib import MUST replace quick/engineer builtin presets (keeping user presets), record library version from `versionCode`, and reply with `code` 200. Failures MUST reply with `code` 500 and a message.

#### Scenario: Param push success ack

- **WHEN** a valid `command.send_process_param` payload is applied
- **THEN** the device MUST reply `command.send_process_param_ack` with `request_id`, `code` 200, and `message`

### Requirement: Process library request empty without type

When `command.process_library_request` omits `process_type` / `processType`, the response `data` MUST be an empty array (MUST NOT dump the full library).

#### Scenario: Missing process_type yields empty list

- **WHEN** `command.process_library_request` arrives without a process type field
- **THEN** `command.process_library_response` `data` MUST be `[]`

### Requirement: Non-OTA command dispatch

The system SHALL handle: `command.send_process_param`, `command.send_process_lib`, process-library/parameters request/CRUD/set-default types, `command.video_list_request`, `command.upload_video`, `command.delete_video`, `command.lock`, `command.unlock`, `command.clear_alerts`, and `command.disconnect`. Process-library writes MUST go through the shared local importer/rules. Acknowledgements MUST follow lws-ui ack naming. `command.lock` / `command.unlock` MUST NOT send a typed ack.

#### Scenario: Remote lock command persists

- **WHEN** `command.lock` is received on an active connection
- **THEN** the device MUST enter the locked state
- **AND** subsequent snapshot payloads MUST report locked
- **AND** the device MUST NOT emit `command.lock_ack`

### Requirement: Video list filters and upload lifecycle

`command.video_list_request` MUST honor `page` (default 1), `page_size` (default 10, max 100), optional filters (`process_type`, `material_type`, `start_date`, `end_date`, `order`, `upload_status`), and when `upload_status` is omitted MUST exclude `uploadStatus == 0`. `command.upload_video` MUST ack acceptance when upload starts (`videoId`), then run the shared cover-then-media coordinator (see below / `process-video-cloud-upload`), emit `video.uploading` progress, and emit `video.metadata` after cover and after successful catalog registration. `command.delete_video` MUST read `video_id` (prefer snake) and use stable error messages (`missing_video_id`, `video_not_found`, …).

#### Scenario: Upload ack before completion

- **WHEN** `command.upload_video` names an existing local video and upload is started
- **THEN** the device MUST send `command.upload_video_ack` with success before upload finishes
- **AND** MUST later emit `video.uploading` and, on success, `video.metadata`

### Requirement: Process-video WebSocket upload uses cover-then-media coordinator

When `command.upload_video` requests cloud upload, the system SHALL acknowledge acceptance promptly, then run the shared process-video cloud upload coordinator: cover when still `uploadStatus == 0` (emit `video.metadata` on cover success), then media PutObject with throttled `video.uploading` progress (0→100), finishing at `uploadStatus == 3` with a forced final `video.uploading`. Device-local `POST /v1/videos` multipart ingest remains a separate LAN API that writes the process-video index only and does not by itself perform Worker/R2 upload.

#### Scenario: Upload command early ack

- **WHEN** `command.upload_video` names a known local `videoId` and upload can start
- **THEN** the device MUST ack acceptance/start before PutObject completes

#### Scenario: Cover then video

- **WHEN** the named row is still at `uploadStatus == 0`
- **THEN** cover upload MUST complete (or fail the run) before video PutObject begins

#### Scenario: Mid-upload progress to remote

- **WHEN** media PutObject is in progress after early ack
- **THEN** the device MUST emit one or more `video.uploading` frames with increasing `uploadProgress` before the terminal 100% frame

### Requirement: OTA WebSocket protocol without apply

`command.check_update` and `command.update_system` MUST NOT download or apply packages in this change. Acknowledgements MUST use lws-ui-shaped `payload.data` (`ok`, optional `has_update`/`manifest`/`started`, `error_code`, `error_message`). When unsupported, `ok` MUST be false and `error_code` MUST be `ota_not_supported`. The system MUST NOT emit `device.update_progress` unless a real upgrade pipeline is running.

#### Scenario: check_update unsupported

- **WHEN** `command.check_update` is received and OTA apply is unavailable
- **THEN** the device MUST reply `command.check_update_ack` with `data.ok` false and `data.error_code` `ota_not_supported`
- **AND** MUST NOT start a package download

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
