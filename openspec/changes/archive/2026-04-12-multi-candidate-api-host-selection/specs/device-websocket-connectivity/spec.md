## MODIFIED Requirements

### Requirement: Environment-aware device WebSocket endpoint selection

The device networking layer SHALL build the `/ws/device` connection URL from the **pinned API base URL** selected by `device-api-origin-selection` (in-memory, per process), including correct `ws` vs `wss` scheme selection and preservation of any path prefix on that base. Until a pinned base exists, the device MUST NOT open a `/ws/device` connection using a legacy static host as a silent substitute.

#### Scenario: Production channel uses pinned base when Workers HTTPS wins

- **WHEN** the app runs in the production release channel (`RELEASE_CHANNEL = 1`) and the pinned API base is `https://api-prod.lasercyber.workers.dev`
- **THEN** the device WebSocket connection MUST target `wss://api-prod.lasercyber.workers.dev/ws/device?sn=<device-sn>`

#### Scenario: Non-production channel uses pinned base when Workers HTTPS wins

- **WHEN** the app runs outside the production release channel (`RELEASE_CHANNEL != 1`) and the pinned API base is `https://api-test.lasercyber.workers.dev`
- **THEN** the device WebSocket connection MUST target `wss://api-test.lasercyber.workers.dev/ws/device?sn=<device-sn>`

#### Scenario: HTTP LAN base with path prefix uses cleartext WebSocket

- **WHEN** the pinned API base is `http://47.86.53.176:8080/prod`
- **THEN** the device WebSocket connection MUST target `ws://47.86.53.176:8080/prod/ws/device?sn=<device-sn>`

#### Scenario: No pin yet means no fabricated static fallback

- **WHEN** no pinned API base has been established yet in this process
- **THEN** the device MUST NOT connect to `wss://api-prod.lasercyber.workers.dev` or `wss://api-test.lasercyber.workers.dev` solely because of the release channel without a prior successful selection round
