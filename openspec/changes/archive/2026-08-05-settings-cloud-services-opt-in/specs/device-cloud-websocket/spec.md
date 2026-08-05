## MODIFIED Requirements

### Requirement: Network-driven WebSocket lifecycle

After first frame, **when cloud services (云服务) is enabled**, and when a suitable network is available and an API origin is pinned, the system SHALL connect to `/ws/device` using a proxy-aware WebSocket client. Connectivity loss MUST close or reset the session; recovery MUST reconnect unless forced-disconnect suppression is active **or cloud services is disabled**. The system MUST NOT start the device WebSocket from `main()` before the first frame. The system MUST NOT connect or auto-reconnect the device WebSocket while cloud services is disabled. While connected, the client SHALL enable WebSocket protocol ping/pong (default interval 30s, matching lws-ui) so idle proxies and NAT timeouts do not leave a half-open session without reconnect.

#### Scenario: Connect after pin and network available when enabled

- **WHEN** cloud services is enabled, a pinned API origin exists, and a suitable network is available after first frame
- **THEN** the system MUST attempt a WebSocket connection to the derived `/ws/device` URL

#### Scenario: No connect when cloud services off

- **WHEN** cloud services is disabled
- **THEN** the system MUST NOT open a device WebSocket session

#### Scenario: Transport keepalive detects dead sockets

- **WHEN** the device WebSocket is connected
- **THEN** the client MUST send protocol-level ping frames on a bounded interval
- **AND** a missed pong MUST close the socket so backoff reconnect can run (unless forced-disconnect, auth latch, or cloud-services-off is active)

#### Scenario: Forced disconnect suppresses auto-reconnect

- **WHEN** the server sends `command.disconnect` (or equivalent forced-evict)
- **THEN** the system MUST close the socket and MUST NOT auto-reconnect until an explicit user or network-policy retry clears suppression
