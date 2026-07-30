# device-api-origin-selection Specification

## Purpose

Probe and pin the Worker (and optional hyurl) HTTP API base for the active environment tier; derive the device WebSocket URL from the pin. Product cloud traffic MUST NOT invent a static host when no pin exists.

## Requirements

### Requirement: Probe and pin Worker API origin

The system SHALL maintain an ordered candidate list of Worker (and optional legacy) HTTP API base URLs derived from the active app environment tier. When a suitable network is available, the system SHALL **concurrently** probe candidates and pin the **first successful** origin in memory for the process (lws-ui `invokeAny` / first-wins; a faster fallback MAY outrank a slower primary). Until a pin exists, the system MUST NOT open product cloud WebSocket connections using a fabricated static host. Probe and subsequent product cloud HTTP MUST honor the system HTTP proxy configuration.

#### Scenario: First reachable origin is pinned

- **WHEN** a suitable network is available and at least one candidate base responds successfully to the probe
- **THEN** the system MUST pin that base URL for the process
- **AND** subsequent Worker HTTP and WebSocket URL construction MUST use the pinned base

#### Scenario: Concurrent race prefers first success

- **WHEN** the test-tier candidates `https://api-test.lasercyber.workers.dev` and `https://lasercyber.hyurl.com/test` are both reachable
- **AND** hyurl answers the probe before workers.dev
- **THEN** the system MUST pin `https://lasercyber.hyurl.com/test`

#### Scenario: No pin means no WebSocket connect

- **WHEN** no candidate has been successfully pinned in this process
- **THEN** the device MUST NOT open `/ws/device` solely from a compile-time default host

### Requirement: App environment tier selects candidate set

The system SHALL support distinct candidate sets for at least test and production Worker origins. Test and production candidate lists MUST include the primary `*.lasercyber.workers.dev` base and the `lasercyber.hyurl.com/{test|prod}` fallback. The active tier SHALL be readable from persisted App settings and/or `product.ini` / host `set-prop`. Operators SHALL change the tier from Device Information by tapping Device SN five times within five seconds (lws-ui parity), not via a permanent Settings row.

#### Scenario: Tier change updates candidates on next probe

- **WHEN** the operator or host tooling changes the app environment tier and a new probe round runs
- **THEN** the candidate list MUST match the selected tier
- **AND** a successful probe MUST replace the previous in-memory pin

#### Scenario: SN five-tap opens tier picker

- **WHEN** the operator taps Device SN five times within five seconds on Device Information
- **THEN** the environment tier picker is presented
- **AND** selecting a tier persists it for subsequent probes

#### Scenario: Test tier includes hyurl fallback

- **WHEN** the active tier is test
- **THEN** the ordered candidate list MUST include `https://api-test.lasercyber.workers.dev`
- **AND** MUST include `https://lasercyber.hyurl.com/test`

### Requirement: WebSocket URL derives from pinned HTTP base

The system SHALL build the device WebSocket URL from the pinned HTTP base, mapping `https`→`wss` and `http`→`ws`, preserving any path prefix, and appending `/ws/device?sn=<url-encoded-device-sn>` where SN comes from HAL product identity resolution.

#### Scenario: HTTPS pin yields WSS device endpoint

- **WHEN** the pinned base is `https://api-test.lasercyber.workers.dev`
- **AND** the device SN is `ABC123`
- **THEN** the WebSocket URL MUST be `wss://api-test.lasercyber.workers.dev/ws/device?sn=ABC123`
