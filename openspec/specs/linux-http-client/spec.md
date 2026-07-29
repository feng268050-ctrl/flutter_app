# linux-http-client Specification

## Purpose

Reusable Dart HTTP(S) client with optional proxy for Demo probe and later product cloud traffic; wall-clock sync before HTTPS when RTC is stale.
## Requirements
### Requirement: Abstract HTTP client with proxy configuration

The system SHALL provide a reusable Dart `HttpClientController` (name may vary) that persists HTTP(S) proxy settings (enabled, host, port, optional credentials) and performs outbound HTTP(S) requests that honor the proxy when enabled. Callers (Demo and product cloud HTTP) MUST depend on the abstract API. The same persisted proxy configuration SHALL be available to the product cloud WebSocket factory so Worker `/ws/device` connections honor the proxy when enabled. Proxy passwords MUST NOT be written to info-level logs.

When the UTC year is before 2025, the Linux HTTP controller SHALL attempt wall-clock sync **via the shared `DateTimeController` TLS entry** (`ensureSaneForTls` or equivalent) before the HTTPS request—not via a private duplicate of the `rdate` / HTTP `Date` ladder as the primary path.

#### Scenario: Proxy settings persist

- **WHEN** the user enables a proxy with host and port and saves
- **THEN** a subsequent get of proxy configuration returns those values after process restart

#### Scenario: Request without proxy returns status

- **WHEN** proxy is disabled and a GET is issued to a reachable HTTPS URL over working wlan0
- **THEN** the result includes an HTTP status code and a truncated body or empty body without crashing the HMI

#### Scenario: HTTPS trust store present

- **WHEN** the P2.1 rootfs is deployed
- **THEN** `/etc/ssl/certs/ca-certificates.crt` (or equivalent CA bundle) is present on the filesystem so system TLS clients and Dart default roots have a CA source available

#### Scenario: Wall clock sync before HTTPS

- **WHEN** a GET is issued to a public HTTPS URL and the system year is before 2025
- **THEN** the Linux HTTP controller SHALL call the shared date/time TLS sync entry before the request so certificate validity windows are evaluated against a sane time

#### Scenario: Request with proxy uses configured proxy

- **WHEN** proxy is enabled with a reachable proxy and a GET is issued
- **THEN** the client attempts the request via that proxy and returns success or a structured error (not an uncaught exception)

#### Scenario: Request failure is structured

- **WHEN** DNS fails, TCP fails, or TLS fails
- **THEN** the result reports an error string and MUST NOT terminate the Flutter process

#### Scenario: Product cloud WebSocket reads same proxy config

- **WHEN** proxy is enabled with host and port
- **AND** the product cloud stack opens `/ws/device`
- **THEN** the WebSocket client MUST use the same persisted proxy configuration as `HttpClientController` (enabled path), not an unmanaged direct socket that ignores proxy

