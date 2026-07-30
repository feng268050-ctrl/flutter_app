## MODIFIED Requirements

### Requirement: Process library LAN API

When local process-library storage is available, the system SHALL expose list/CRUD routes compatible with lws-ui `/v1/process-library` and `/v1/process-parameters/*` (including create/update/delete and set-default), writing through the shared importer/repository rules when wired. Unwired write paths MUST return structured `ApiResult` failure rather than claiming success.

#### Scenario: Library list returns ApiResult

- **WHEN** a client calls `GET /v1/process-library` with a valid `processType` and the library backend is enabled
- **THEN** the response MUST be `ApiResult` success with library data

#### Scenario: Process parameters set-default

- **WHEN** a client calls the process-parameters set-default route for an existing parameter id and the backend is enabled
- **THEN** the response MUST be `ApiResult` success reflecting the new default
- **OR** a structured failure if the importer/repository rejects the write

### Requirement: Monitor and camera LAN routes as backends allow

The system SHALL expose monitor SSE and camera control routes (`/v1/monitor/stat`, `/v1/monitor/alerts`, `/v1/camera/ai`, `/v1/camera/record`, `/v1/camera/show-overlay`) when the corresponding App backends exist. Until wired, those routes MUST return HTTP `501` or `ApiResult` failure promptly and MUST NOT leave the connection open indefinitely without response.

#### Scenario: Unimplemented route fails structured

- **WHEN** a client calls a documented camera/monitor route that is not yet wired
- **THEN** the server MUST return an HTTP error or `ApiResult` failure
- **AND** MUST NOT leave the connection open indefinitely without response
