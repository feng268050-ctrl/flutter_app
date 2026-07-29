# device-cloud-websocket Specification

## Purpose
TBD - created by archiving change align-cloud-local-server. Update Purpose after archive.
## Requirements
### Requirement: Network-driven WebSocket lifecycle

After first frame, when a suitable network is available and an API origin is pinned, the system SHALL connect to `/ws/device` using a proxy-aware WebSocket client. Connectivity loss MUST close or reset the session; recovery MUST reconnect unless forced-disconnect suppression is active. The system MUST NOT start the device WebSocket from `main()` before the first frame.

#### Scenario: Connect after pin and network available

- **WHEN** a pinned API origin exists and a suitable network is available after first frame
- **THEN** the system MUST attempt a WebSocket connection to the derived `/ws/device` URL

#### Scenario: Forced disconnect suppresses auto-reconnect

- **WHEN** the server sends `command.disconnect` (or equivalent forced-evict)
- **THEN** the system MUST close the socket and MUST NOT auto-reconnect until an explicit user or network-policy retry clears suppression

### Requirement: Unified message envelope

Inbound and outbound device WebSocket messages SHALL use JSON envelope fields `v`, `type`, `id`, `ts`, and `payload` (version `1` unless a later negotiated version is specified). Unknown non‑OTA `type` values MUST be logged and MUST NOT crash the process.

#### Scenario: Malformed envelope is ignored safely

- **WHEN** an inbound frame is not valid envelope JSON
- **THEN** the system MUST discard it without terminating the Flutter process

### Requirement: Online snapshot and stat responses

On successful WebSocket connect, the system SHALL send `device.online` with a remote snapshot payload aligned with lws-ui field groups available on Linux (device info, common settings, status/data, process parameters, warns, lock, Wi‑Fi info). The system SHALL answer `command.stat_request` with `command.stat_response` carrying a fresh snapshot.

#### Scenario: Online sent after connect

- **WHEN** the WebSocket connection becomes ready
- **THEN** the system MUST send a `device.online` envelope whose payload includes a remote snapshot object

### Requirement: Non-OTA command dispatch

The system SHALL handle at least: `command.send_process_param`, `command.send_process_lib`, process-library CRUD request/response types used by lws-ui, `command.video_list_request`, `command.upload_video`, `command.delete_video`, `command.lock`, `command.unlock`, `command.clear_alerts`, and `command.disconnect`. Process-library writes MUST go through the shared local importer/rules (no Android delete-defaults dual-copy semantics). Acknowledgements MUST follow lws-ui ack naming for implemented commands.

#### Scenario: Remote lock command persists

- **WHEN** `command.lock` is received on an active connection
- **THEN** the device MUST enter the locked state
- **AND** subsequent snapshot payloads MUST report locked

### Requirement: OTA WebSocket commands are no-ops

The system MUST NOT download or apply product/firmware updates in response to `command.check_update` or `command.update_system`. The system MUST NOT emit `device.update_progress` as part of an OTA flow in this change. If such commands arrive, the system SHALL respond with a safe acknowledgement or explicit unsupported outcome and MUST leave local storage unchanged for OTA packages.

#### Scenario: check_update does not start download

- **WHEN** `command.check_update` is received
- **THEN** the system MUST NOT start an OTA package download
- **AND** the HMI MUST remain on the current screen without an update progress UI

### Requirement: Auth failure classification

When the WebSocket handshake fails with HTTP `401` or the connection closes with auth-invalid classification, the system MUST enter an auth-error offline state, MUST NOT schedule exponential-backoff reconnect for that failure, and MUST surface the registration UI defined by `device-registration-ui`.

#### Scenario: Handshake 401 suppresses backoff reconnect

- **WHEN** the WebSocket upgrade fails with HTTP `401`
- **THEN** the system MUST NOT schedule automatic backoff reconnect for that failure
- **AND** the registration UI MAY be shown when a foreground route is available

