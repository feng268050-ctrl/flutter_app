## ADDED Requirements

### Requirement: ADB enable HTTP endpoint (API surface)

The system SHALL expose **`POST /v1/adb`** on the same embedded local HTTP server and port as other `/v1/*` device routes. The endpoint SHALL use the standard **`ApiResult`** JSON envelope. On logical success, **`data`** MUST be **`null`**. Enablement semantics are defined in capability **`device-local-http-adb`**.

#### Scenario: ADB route on device LAN

- **WHEN** a client sends `POST http://<device-lan-ip>:5580/v1/adb`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/videos` and MUST NOT require the cloud Worker base URL
- **AND** on success the response MUST be `ApiResult` with `success: true` and `data: null`

#### Scenario: Documented in network API reference

- **WHEN** a developer reads `docs/network-api-reference.md` for device-local HTTP
- **THEN** the document MUST describe `POST /v1/adb`, the `ApiResult` success shape (`data: null`), failure message (for example `adb_enable_failed`), and a curl example against port **5580**
