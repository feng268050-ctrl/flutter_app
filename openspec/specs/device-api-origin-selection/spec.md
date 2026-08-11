# device-api-origin-selection Specification

## Purpose

Probe and pin the Worker (and optional hyurl) HTTP API base for the active environment tier; derive the device WebSocket URL from the pin. Product cloud traffic MUST NOT invent a static host when no pin exists. Candidate lists, concurrent probe, and in-memory pin live in **`cyber_hal`** (`CloudApiOriginConfig` / `CloudApiOriginProber`) so any App can resolve a suitable origin.

## Requirements

### Requirement: HAL owns multi-origin catalog and probe

The platform HAL SHALL expose an ordered candidate list of Worker (and optional legacy) HTTP API base URLs per `CloudEnvironmentTier`, a concurrent first-wins probe that pins the first successful base, and URI helpers to join paths and build the device WebSocket URL from the pin. A successful pin SHALL be written to `/run/network/cloud-origin.pin` (boot-scoped tmpfs) so other Apps in the same boot MAY skip re-probe when the stored `environment_tier` matches. Reboot MUST clear that pin. Apps MUST NOT hard-code a Worker host for product cloud traffic when no pin exists. Probe and subsequent product cloud HTTP MUST honor the system HTTP proxy configuration. Device Bearer HTTP, Ed25519 activate/token mint, and device WebSocket connection lifecycle SHALL also live in HAL; product command dispatch remains App-owned.

#### Scenario: Boot pin reused across Apps

- **WHEN** a probe has pinned an origin and written `/run/network/cloud-origin.pin` for the active tier
- **AND** another App in the same boot requests a probe for the same tier
- **THEN** the HAL prober MUST return the stored origin without a new HTTP probe round

#### Scenario: Reboot clears pin

- **WHEN** the device reboots
- **THEN** `/run/network/cloud-origin.pin` MUST be absent
- **AND** the next probe MUST contact candidates again

#### Scenario: Concurrent race prefers first success

- **WHEN** the test-tier candidates `https://api-test.lasercyber.workers.dev` and `https://lasercyber.hyurl.com/test` are both reachable
- **AND** hyurl answers the probe before workers.dev
- **THEN** the system MUST pin `https://lasercyber.hyurl.com/test`

#### Scenario: No pin means no WebSocket connect

- **WHEN** no candidate has been successfully pinned in this process
- **THEN** the device MUST NOT open `/ws/device` solely from a compile-time default host

### Requirement: Environment tier selects candidate set

The system SHALL support distinct candidate sets for at least test and production Worker origins. Test and production candidate lists MUST include the primary `*.lasercyber.workers.dev` base and the `lasercyber.hyurl.com/{test|prod}` fallback. The active tier SHALL be persisted at `/var/lib/network/cloud.conf` (`environment_tier=`) and edited from **OS Settings → Network → Cloud Environment**. Product HMI MUST consume this tier when probing and MUST NOT expose a permanent env-tier picker (product cloud/LAN opt-in toggles remain HMI-owned under `/var/lib/hmi/cloud-settings.json`).

#### Scenario: Tier change updates candidates on next probe

- **WHEN** the operator changes the environment tier in OS Settings and a new probe round runs
- **THEN** the candidate list MUST match the selected tier
- **AND** a successful probe MUST replace the previous in-memory pin

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

### Requirement: Device WebSocket URL path remains /ws/device under token auth

Building the device WebSocket URL from the pinned HTTP base SHALL continue to append **`/ws/device?sn=<url-encoded-device-sn>`**. Device **`access_token`** authentication SHALL be supplied via the upgrade **`Authorization`** header per **`device-cloud-access-token-api`**, not by changing the path to a v2 endpoint.

#### Scenario: URL unchanged when token auth is used

- **WHEN** the App derives the device WebSocket URL after token mint is available
- **THEN** the path SHALL still end with **`/ws/device`** and query **`sn`**
