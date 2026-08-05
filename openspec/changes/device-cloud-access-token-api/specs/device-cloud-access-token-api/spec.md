## ADDED Requirements

### Requirement: Device cloud clients SHALL send Bearer after token mint

When 云服务 is enabled and the device has (or can mint) a valid device **`access_token`** via **`device-cloud-ed25519-activate`**, the HMI SHALL include **`Authorization: Bearer <access_token>`** on gated Worker device calls that remain on **v1** paths: at least **`GET /ws/device`**, **`GET /v1/devices/:sn/users`**, **`POST /v1/devices/:sn/ai-report`**, and device-mode **`POST /v1/storage/r2/sts`** (and device presign if used). The client SHALL NOT introduce `/v2` device URLs for this capability.

#### Scenario: Users probe carries Bearer

- **WHEN** a token is available and the App probes binding users
- **THEN** **`GET /v1/devices/:sn/users`** SHALL include the device Bearer header

#### Scenario: WebSocket upgrade carries Bearer

- **WHEN** a token is available and the App opens the device WebSocket
- **THEN** the upgrade request to **`/ws/device`** SHALL include the device Bearer header

### Requirement: Activate and token mint SHALL omit Bearer

**`POST /v1/devices/:sn/activate`** and **`POST /v1/devices/:sn/token`** SHALL be called without a device Bearer header.

#### Scenario: Token mint has no Authorization Bearer

- **WHEN** the HMI mints an access token
- **THEN** the HTTP request SHALL not depend on a prior access token

### Requirement: Auth failure SHALL trigger one re-mint and retry

When a gated cloud call fails with HTTP **401** (or WebSocket auth rejection equivalent) and a sealed cloud key exists, the HMI SHALL attempt one **`POST /v1/devices/:sn/token`** re-mint and retry the operation once. Persistent failure SHALL be surfaced as a structured auth error without crashing the process.

#### Scenario: Single retry after 401

- **WHEN** a gated HTTP call returns **401** and re-mint succeeds
- **THEN** the client SHALL retry the call once with the new token

### Requirement: Prerequisite ordering

This capability SHALL be implemented only after **`device-cloud-ed25519-activate`** token mint works and against api-server **`device-access-token-auth`** (plus **`device-ed25519-activate`**) contracts.

#### Scenario: No Bearer wiring without mint

- **WHEN** token mint is unavailable
- **THEN** this capability SHALL NOT be considered complete
