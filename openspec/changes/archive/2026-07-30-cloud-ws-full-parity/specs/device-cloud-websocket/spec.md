## ADDED Requirements

### Requirement: Full device WebSocket command matrix

The device WebSocket SHALL implement the lws-ui command set for envelope `v=1` frames: unsolicited `device.online`; request/response pairs for stat, process push, process library/parameters CRUD, video list/upload/delete; lock/unlock/disconnect without typed ack; and OTA check/update with protocol-shaped acknowledgements. Unknown types MUST be logged without crashing. Legacy `connected` and inbound `ack` MUST be ignored.

#### Scenario: Envelope version mismatch discarded

- **WHEN** an inbound frame has `v` not equal to `1`
- **THEN** the system MUST discard the frame without applying side effects

### Requirement: Remote lock safety stop and mode eject

On `command.lock`, the system MUST persist the lock flag, MUST write Modbus control bits to clear laser enable, manual gas, and wire-feed job bits (best-effort), MUST eject or block Quick/Engineer/Monitor sessions when active, and MUST NOT send a lock ack. On `command.unlock`, the system MUST clear the lock flag and dismiss lock UI, with no ack.

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

### Requirement: Video list filters and upload lifecycle

`command.video_list_request` MUST honor `page` (default 1), `page_size` (default 10, max 100), optional filters (`process_type`, `material_type`, `start_date`, `end_date`, `order`, `upload_status`), and when `upload_status` is omitted MUST exclude `uploadStatus == 0`. `command.upload_video` MUST ack acceptance when upload starts (`videoId`), emit `video.uploading` progress, and emit `video.metadata` after successful catalog registration. `command.delete_video` MUST read `video_id` (prefer snake) and use stable error messages (`missing_video_id`, `video_not_found`, …).

#### Scenario: Upload ack before completion

- **WHEN** `command.upload_video` names an existing local video and upload is started
- **THEN** the device MUST send `command.upload_video_ack` with success before upload finishes
- **AND** MUST later emit `video.uploading` and, on success, `video.metadata`

### Requirement: OTA WebSocket protocol without apply

`command.check_update` and `command.update_system` MUST NOT download or apply packages in this change. Acknowledgements MUST use lws-ui-shaped `payload.data` (`ok`, optional `has_update`/`manifest`/`started`, `error_code`, `error_message`). When unsupported, `ok` MUST be false and `error_code` MUST be `ota_not_supported`. The system MUST NOT emit `device.update_progress` unless a real upgrade pipeline is running.

#### Scenario: check_update unsupported

- **WHEN** `command.check_update` is received and OTA apply is unavailable
- **THEN** the device MUST reply `command.check_update_ack` with `data.ok` false and `data.error_code` `ota_not_supported`
- **AND** MUST NOT start a package download

## MODIFIED Requirements

### Requirement: Ack and lock semantics (lws-ui parity)

`command.lock` / `command.unlock` MUST persist remote lock state, apply lock safety side effects defined under remote lock safety stop, and MUST NOT send a typed ack. `command.clear_alerts` MUST clear local alarm history and reply with `command.clear_alerts_ack` using `payload.request_id` and `payload.data.{success,message}`. Process push acks MUST use `payload.request_id`, `payload.code` (200|500), and `payload.message`. Video and process-parameters mutation acks MUST use the `request_id` + `data.{success,message}` shape.

#### Scenario: Lock without ack

- **WHEN** the server sends `command.lock`
- **THEN** the device MUST set the persisted lock flag and MUST NOT emit `command.lock_ack`

## REMOVED Requirements

### Requirement: OTA WebSocket commands are no-ops

**Reason:** Replaced by protocol-shaped unsupported outcomes; silent/`ota_deferred` data-ack is insufficient for cloud clients.
