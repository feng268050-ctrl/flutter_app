## ADDED Requirements

### Requirement: Device-wide HTTP proxy settings storage

The system SHALL persist `HttpProxySettings` with fields: enabled, host, port, auth type (`NONE` or `BASIC`), optional username, and optional password. Passwords MUST NOT be included in remote snapshot or telemetry payloads.

#### Scenario: Proxy disabled by default

- **WHEN** no proxy settings have been saved
- **THEN** the system SHALL behave as if HTTP proxy is disabled

#### Scenario: Save persists settings

- **WHEN** the user saves valid proxy settings from the HTTP Proxy page
- **THEN** the system MUST persist settings for subsequent process launches

### Requirement: NetworkHttpClientProvider routes internet vs LAN traffic

All outbound HTTP clients for API, WebSocket, origin probe, OTA manifest, OTA download, AI report, R2 upload, and Users API MUST be obtained from `NetworkHttpClientProvider` with `NetworkRoutePolicy.INTERNET_PROXY_AWARE`. Camera HTTP, `CameraLanHttpProxy`, localhost, and local MediaMTX APIs MUST use `NetworkRoutePolicy.DIRECT_LAN` and MUST NOT use the configured HTTP proxy.

#### Scenario: API client uses proxy when enabled

- **WHEN** HTTP proxy is enabled with valid host and port
- **THEN** Retrofit and other INTERNET_PROXY_AWARE clients MUST route through the configured HTTP proxy

#### Scenario: Camera HTTP stays direct

- **WHEN** HTTP proxy is enabled
- **THEN** camera LAN HTTP requests MUST NOT use the HTTP proxy

### Requirement: Proxy settings change invalidates clients and reconnects WebSocket

Saving new proxy settings MUST increment an internal client generation, invalidate cached `OkHttpClient` instances in the provider, invalidate `RetrofitClient`, and trigger `DeviceWebSocketConnectionManager.connectOrReconnect` with reason `proxy_settings_changed`.

#### Scenario: WebSocket reconnects after proxy save

- **WHEN** the user saves changed proxy settings while the device had an active WebSocket
- **THEN** the system MUST close the old WebSocket and attempt reconnect using the new client generation

### Requirement: HTTP Proxy settings page in Common Settings

Common Settings Network group SHALL include an **HTTP Proxy** row that opens a dedicated settings screen. The screen MUST provide: enable switch, host, port, authentication type (None/Basic), username, password (masked), **Test Connection** primary action, and **Save** primary action using `FrostButtonView` primary variant consistent with other settings actions.

#### Scenario: Open HTTP Proxy from Common Settings

- **WHEN** the user taps HTTP Proxy in Common Settings → Network
- **THEN** the app MUST open the HTTP Proxy settings page

#### Scenario: Test connection probes pinned API origin

- **WHEN** the user taps Test Connection with proxy enabled
- **THEN** the system MUST perform a short HTTP reachability check against the current pinned or candidate API origin through the configured proxy and show success or failure feedback

### Requirement: HTTP proxy v1 scope

v1 SHALL support HTTP proxy, HTTPS over HTTP proxy, Basic authentication, and WebSocket / WSS through the proxy. v1 SHALL NOT claim support for SOCKS5, PAC, NTLM, or Kerberos.

#### Scenario: Basic auth header on proxied request

- **WHEN** proxy is enabled with Basic authentication credentials
- **THEN** INTERNET_PROXY_AWARE clients MUST attach proxy authorization on challenged proxied requests
