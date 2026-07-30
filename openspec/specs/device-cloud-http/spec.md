# device-cloud-http Specification

## Purpose

Proxy-aware Worker REST clients for device binding probe, R2 STS/object upload, process-video metadata registration, and AI report upload. Used by registration UX and WebSocket-triggered cloud video upload. Local multipart ingest on `:5580` (`POST /v1/videos`) stores on-device only and MUST NOT be confused with Worker/R2 cloud upload.

## Requirements

### Requirement: Proxy-aware Worker HTTP clients

Product cloud REST calls to the pinned Worker origin SHALL use the shared proxy-aware HTTP stack. Requests SHALL include `App-Version` and a Linux device type header (not `Android`). Success for Worker `Result<T>` wrappers SHALL treat `code == 200` as success unless a route documents otherwise.

#### Scenario: Users probe uses pinned origin and proxy

- **WHEN** a pinned origin exists and system proxy is enabled
- **AND** the App probes `GET /v1/devices/:sn/users`
- **THEN** the request MUST target the pinned origin
- **AND** MUST attempt the transfer via the configured proxy

### Requirement: Device users binding probe

The system SHALL call `GET /v1/devices/:sn/users` with the resolved device SN to determine cloud binding state. An empty binding result on success SHALL be treatable as unbound for bind UX. Worker HTTP `401` with `errorCode: INVALID_SN` (or equivalent) SHALL be classified as needs-registration (not unbound). Network failures MUST be structured errors and MUST NOT crash the process.

#### Scenario: Empty users means unbound

- **WHEN** the users endpoint returns success with an empty user set
- **THEN** the App MAY treat the device as unbound for bind prompting

#### Scenario: INVALID_SN means needs registration

- **WHEN** the users endpoint returns HTTP 401 with `INVALID_SN`
- **THEN** the App MUST treat the device as needing registration
- **AND** MUST NOT treat the result as a successful unbound bind state

### Requirement: R2 STS and object upload

The system SHALL obtain temporary credentials via `POST /v1/storage/r2/sts` on the pinned origin and SHALL upload objects with S3-compatible PutObject semantics for process-video cover and media when an upload is requested (LAN or WebSocket triggered). Credentials and secret keys MUST NOT be written to info-level logs.

#### Scenario: STS failure is structured

- **WHEN** the STS endpoint is unreachable or returns non-success
- **THEN** the upload path MUST fail with a structured error
- **AND** MUST NOT terminate the Flutter process

### Requirement: Process video metadata registration

When uploading a process video to cloud, the system SHALL register metadata through the Worker/legacy video metadata route used by lws-ui (`uploadVideoAndProcessData` or the current Worker equivalent documented in `network-api-reference`) before or in coordination with object upload, matching field naming expected by the backend.

#### Scenario: Metadata success yields business video id

- **WHEN** metadata registration succeeds
- **THEN** the client MUST receive a business video identifier usable for subsequent object association

### Requirement: Video upload uses STS then metadata

When `command.upload_video` requests cloud upload, the system SHALL obtain R2 STS credentials, PutObject the media (and cover when required), and register metadata through the Worker video metadata route before acknowledging success to the requester. Device-local `POST /v1/videos` multipart ingest is a separate LAN API that writes the process-video index only (see `device-local-http-api`) and does not by itself perform Worker/R2 upload.

#### Scenario: Upload failure is structured

- **WHEN** STS, PutObject, or metadata registration fails
- **THEN** the upload path MUST fail with a structured error or non-success ack
- **AND** MUST NOT terminate the Flutter process

### Requirement: AI report upload hook

The system SHALL provide a client for `POST /v1/devices/:sn/ai-report` (multipart image + stat JSON). If the AI product surface is not yet live, the client MAY exist unused, but MUST be callable without crashing when invoked with valid inputs.

#### Scenario: Missing AI UI does not block client compile

- **WHEN** the AI Vision tab is still a stub
- **THEN** the AI report HTTP client MUST still build and remain invocable from tests or future UI
