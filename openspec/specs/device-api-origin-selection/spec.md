## Purpose

Define release-channel Worker API **candidate bases**, concurrent **root** reachability probing on `ConnectivityManager.NetworkCallback.onAvailable`, first-wins cancellation semantics, the **in-memory pinned** API base URL, and rules for joining HTTPS paths and building `ws`/`wss` `/ws/device` URLs (including path-prefixed LAN gateways).

## Requirements

### Requirement: Release-channel ordered API base candidates

The device SHALL expose an ordered list of **API base URLs** for the active build channel, each a valid absolute HTTP or HTTPS URL **without** a trailing slash before path joining. A base URL includes scheme, host, optional port, and optional path prefix used by that gateway.

#### Scenario: Non-production channel candidate list

- **WHEN** the app runs outside the production release channel (`RELEASE_CHANNEL != 1`, i.e. `BuildConfig.RELEASE_CHANNEL` is false)
- **THEN** the ordered candidate list MUST be exactly `(1) https://api-test.lasercyber.workers.dev`, `(2) http://47.86.53.176:8080/test`

#### Scenario: Production channel candidate list

- **WHEN** the app runs in the production release channel (`RELEASE_CHANNEL = 1`, i.e. `BuildConfig.RELEASE_CHANNEL` is true)
- **THEN** the ordered candidate list MUST be exactly `(1) https://api-prod.lasercyber.workers.dev`, `(2) http://47.86.53.176:8080/prod`

### Requirement: Concurrent root probe on network available

When the application `ConnectivityManager.NetworkCallback` reports `onAvailable` for a suitable network, the device SHALL start an HTTP probe **for every** candidate in parallel. Each probe SHALL use an `OkHttpClient` from `NetworkHttpClientProvider` with purpose `PROBE` and route policy `INTERNET_PROXY_AWARE` (respecting enabled HTTP proxy settings). Each probe SHALL perform a single short HTTP exchange (for example GET or HEAD) against that candidate’s **root URL**: take the candidate base URL (no trailing slash), append exactly one `/` if the base has no trailing slash, and use the result as the probe URL (examples: `https://api-test.lasercyber.workers.dev` → `https://api-test.lasercyber.workers.dev/`; `http://47.86.53.176:8080/test` → `http://47.86.53.176:8080/test/`). This matches “probe the `/` route” **on that candidate’s mounted origin**, without navigating above the candidate’s path prefix.

#### Scenario: Probe URL keeps a non-empty path prefix

- **WHEN** a candidate base URL is `http://47.86.53.176:8080/test`
- **THEN** that candidate’s probe URL MUST be `http://47.86.53.176:8080/test/` (and MUST NOT be `http://47.86.53.176:8080/`)

#### Scenario: Parallel start for all candidates

- **WHEN** `onAvailable` triggers a probe round with N candidates
- **THEN** the device MUST initiate all N probes without waiting for one to finish before starting the others

#### Scenario: Probe uses proxy when configured

- **WHEN** HTTP proxy is enabled and a probe round starts
- **THEN** probe HTTP clients MUST route through the configured proxy

### Requirement: First successful probe wins; others are cancelled

The device SHALL treat the **first** candidate probe in a round that **succeeds** per the success rule as the **winner**. Immediately upon choosing the winner, the device SHALL **cancel** every other in-flight probe from that round and MUST ignore their outcomes if they complete afterward.

#### Scenario: Cancel slower probes after a winner

- **WHEN** candidate A’s probe succeeds before candidate B’s probe completes
- **THEN** the device MUST cancel candidate B’s in-flight probe (and any additional candidates) and MUST NOT replace the winner with B if B later completes

### Requirement: Probe success definition

A probe **succeeds** when the HTTP client receives a completed response for that probe call without a transport-level failure that prevents reading a response (for example no thrown I/O error indicating unreachable host). **Any** HTTP status code returned by the server still counts as success for this reachability probe unless a project-wide stricter rule is added later.

#### Scenario: Non-2xx HTTP still counts as reachable

- **WHEN** the server responds with HTTP `404` for `/` but the exchange completes without transport failure
- **THEN** the probe MUST be treated as successful for candidate selection purposes

### Requirement: In-memory pinned API base for runtime traffic

After a winning candidate is chosen in a probe round, the device SHALL store its normalized base URL **in memory** as the **pinned API base**. All device Worker HTTPS traffic that today uses `DeviceApiOriginConfig.resolveHttpsApiOrigin()` (or equivalent) and all device `/ws/device` WebSocket connections SHALL use this pinned value for URL construction until a later successful probe round updates the pin.

#### Scenario: WebSocket uses pinned base

- **WHEN** the pinned base is `https://api-test.lasercyber.workers.dev` and the device opens `/ws/device`
- **THEN** the WebSocket URL MUST be derived from that pinned base using the scheme-switch and path-join rules in the requirement “Derive HTTPS and WebSocket URLs from the pinned API base”

#### Scenario: HTTPS client uses pinned base

- **WHEN** application code requests a Worker API HTTPS URL using the shared device API origin
- **THEN** the URL MUST use the pinned API base as its origin (no silent fallback to a non-pinned constant for that request)

### Requirement: Clear pinned base when the default network loses internet

When `ConnectivityManager.NetworkCallback` reports `onLost` for a tracked network, the device SHALL re-evaluate the **current default network** after a short settle delay (to allow Android to switch default routes, for example Wi‑Fi → cellular). If the default network is missing or does not advertise `NET_CAPABILITY_INTERNET`, the device SHALL **clear** the in-memory pinned API base so HTTPS and metadata paths do not assume the previous origin is still reachable. The device SHOULD **disconnect** the device WebSocket at the same time so connection state matches “no selected Worker origin until the next successful probe”. If a default network remains and is internet-capable, the device SHALL **retain** the existing pin until a later successful probe round replaces it.

#### Scenario: Last internet path lost

- **WHEN** `onLost` fires and, after the settle check, `getActiveNetwork()` is null or has no internet capability
- **THEN** the pinned API base MUST be cleared and the WebSocket SHOULD be disconnected with a documented reason

### Requirement: Derive HTTPS and WebSocket URLs from the pinned API base

Given a pinned API base URL, the device SHALL derive:

- **HTTPS traffic:** use the pinned scheme (`http` or `https`), host, port, and path prefix unchanged when joining application-relative paths (for example `/upload/device/presigned-put` MUST be joined so a single slash boundary is preserved).
- **WebSocket traffic:** use `wss` when the pinned scheme is `https`, and `ws` when the pinned scheme is `http`; preserve host, port, and path prefix; append `ws/device` as the next path segments with correct `/` joining, then append the `sn` query parameter per existing device WebSocket URL rules.

#### Scenario: HTTPS Worker host without path prefix

- **WHEN** the pinned base is `https://api-prod.lasercyber.workers.dev`
- **THEN** a relative API path `/upload/device/presigned-put` MUST resolve to `https://api-prod.lasercyber.workers.dev/upload/device/presigned-put`

#### Scenario: WebSocket from HTTPS pinned base without path prefix

- **WHEN** the pinned base is `https://api-test.lasercyber.workers.dev` and device serial is a valid `sn`
- **THEN** the WebSocket URL MUST be `wss://api-test.lasercyber.workers.dev/ws/device?sn=<encoded-sn>`

#### Scenario: WebSocket from HTTP pinned base with path prefix

- **WHEN** the pinned base is `http://47.86.53.176:8080/prod` and device serial is a valid `sn`
- **THEN** the WebSocket URL MUST be `ws://47.86.53.176:8080/prod/ws/device?sn=<encoded-sn>`

### Requirement: Total probe failure does not silently invent a new default

When a probe round completes with **no** successful candidate, the device MUST NOT silently select an arbitrary candidate that did not meet the success rule. If a previous pinned base exists from an earlier successful round in the same process, the device MAY keep serving traffic with that previous pin until a later successful round; if no pin exists yet, HTTPS and WebSocket layers MUST NOT assume a hardcoded replacement host that contradicts this capability.

#### Scenario: All probes fail on first boot

- **WHEN** no prior successful pin exists and all candidate probes in the first `onAvailable` round fail
- **THEN** the device MUST NOT open a WebSocket using a guessed host from the failed round solely because it was listed as a candidate
