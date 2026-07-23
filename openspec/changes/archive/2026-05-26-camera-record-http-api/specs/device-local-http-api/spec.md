## ADDED Requirements

### Requirement: Camera record control HTTP endpoint (API surface)

The system SHALL expose **`POST /v1/camera/record`** on the same embedded local HTTP server and port as other `/v1/*` device routes. The endpoint SHALL accept JSON **`{ "switch": "on" | "off" }`** and SHALL return **`ApiResult`** with **`data`** shaped as **`{ "switch": "on" | "off" }`** on success. Recording semantics, preconditions, UI sync, and coexistence with live streaming are defined in capability **`device-local-http-camera-record`**.

#### Scenario: Record route on device LAN

- **WHEN** a client sends `POST http://<device-lan-ip>:8080/v1/camera/record` with `Content-Type: application/json` and body `{ "switch": "on" }`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL

#### Scenario: Successful response shape

- **WHEN** a record start or stop succeeds
- **THEN** the response body MUST be `ApiResult` with `success: true` and `data.switch` equal to the effective `"on"` or `"off"` state
