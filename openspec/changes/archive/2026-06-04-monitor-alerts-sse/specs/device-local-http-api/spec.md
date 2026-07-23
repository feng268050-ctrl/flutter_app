## ADDED Requirements

### Requirement: Monitor alerts SSE HTTP endpoint (API surface)

The system SHALL expose **`GET /v1/monitor/alerts`** on the same embedded local HTTP server and port as other `/v1/*` device routes. This endpoint SHALL return **`text/event-stream`** (SSE) of monitor alert JSON events without `ApiResult` wrapping. SSE events SHALL be **`list`**, **`new`**, **`clear`**, and **`heartbeat`**.

Semantics are defined in capability **`device-local-http-monitor-alerts-sse`**.

#### Scenario: Monitor alerts route on device LAN

- **WHEN** a client requests `http://<device-lan-ip>:5580/v1/monitor/alerts`
- **THEN** the request MUST be handled by the local HTTP server component that serves `/v1/monitor/stat` and MUST NOT require the cloud Worker base URL
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the first SSE event on the connection MUST be `event: list`

#### Scenario: Payload matches command.stat_response warns

- **WHEN** the device emits a `list` event
- **THEN** the `data` line MUST be a JSON array whose elements match `command.stat_response` `payload.data.warns` for the same app version at that instant
