## MODIFIED Requirements

### Requirement: Network-driven WebSocket connection lifecycle

The device SHALL initiate or refresh the WebSocket `/ws/device` connect attempt from the application's registered `ConnectivityManager.NetworkCallback` when a suitable network becomes available (including when a suitable network is already available at the time the callback is registered). The WebSocket client MUST be obtained from `NetworkHttpClientProvider` with purpose `WEBSOCKET` and route policy `INTERNET_PROXY_AWARE`. The device SHALL NOT invoke a separate Application bootstrap method whose sole purpose is initiating the first WebSocket connection to `/ws/device`.

#### Scenario: Initial connect uses network callback when network already exists

- **WHEN** a suitable network is already available and the `NetworkCallback` is registered (including at cold start)
- **THEN** the connection manager MUST receive a connect attempt for `/ws/device` without any separate Application startup-only connect invocation

#### Scenario: Reconnect after network recovery

- **WHEN** network connectivity transitions from unavailable to available and forced-disconnect reconnect suppression is **not** active in this process
- **THEN** the connection manager MUST trigger a new WebSocket connect attempt

## ADDED Requirements

### Requirement: WebSocket reconnects after HTTP proxy settings change

When HTTP proxy settings are saved and client generation is invalidated, `DeviceWebSocketConnectionManager` MUST close any active WebSocket and call `connectOrReconnect` with reason `proxy_settings_changed`.

#### Scenario: Proxy save triggers reconnect

- **WHEN** the user saves new HTTP proxy settings
- **THEN** the WebSocket connection manager MUST attempt reconnect using the new proxy-aware client
