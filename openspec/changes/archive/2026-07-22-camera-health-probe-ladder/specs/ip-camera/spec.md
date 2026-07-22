## MODIFIED Requirements

### Requirement: IpCamera exposes upstream streams and HAL-owned health

`IpCameraController` SHALL expose at least: `cameraHost`, `streams` (native `pr0`/`pr1` URIs on the camera host), `Stream<IpCameraHealth> health` plus `currentHealth` (broadcast Streams do not replay), `startMonitoring()`, `probeOnce()`, and `dispose()`. Health sampling SHALL be owned by HAL with reconnect-safe policy (configure/path quiet windows MAY be signaled via explicit suspend/resume probe APIs without naming eth0). Both recovery and loss SHALL be debounced with consecutive probe thresholds; one lost probe sample MUST NOT immediately mark a healthy camera unhealthy. Product Apps MUST NOT implement the primary IP-camera health Timer outside HAL.

The default Linux probe MAY be ICMP, TCP reachability of the RTSP port, RTSP OPTIONS (non-SETUP), and/or composition with product relay/path readiness — selected after device validation. Health probes MUST NOT perform RTSP `SETUP`/`PLAY` (or otherwise occupy) native `/PR0` or `/PR1` stream clients while those streams are reserved for the product MediaMTX upstream (or equivalent exclusive consumer).

#### Scenario: App observes health via Stream

- **WHEN** a product UI needs camera reachability
- **THEN** it SHALL read `currentHealth` and listen to `health`
- **AND** MUST NOT run an App-owned Timer as the primary status source for that camera

#### Scenario: One lost probe does not tear down a healthy camera

- **WHEN** an already healthy camera misses one periodic health probe
- **THEN** HAL SHALL keep the camera healthy until the configured consecutive-failure threshold is reached

#### Scenario: Upstream URIs point at the camera host

- **WHEN** `cameraHost` is `192.168.1.100` with default PR paths
- **THEN** `streams.pr0` / `streams.pr1` SHALL target that host’s native RTSP paths (not `127.0.0.1` MediaMTX fan-out)

#### Scenario: Health probe does not steal PR0 or PR1

- **WHEN** MediaMTX (or the product exclusive upstream) is consuming native `/PR0` and/or `/PR1`
- **AND** HAL runs its periodic health probe
- **THEN** the probe MUST NOT open a competing SETUP/PLAY session on those paths
- **AND** the exclusive upstream MUST remain able to consume the stream

## ADDED Requirements

### Requirement: Health probe selection is validated before production default

Before changing the production-default `IpCameraProbe` on Linux, the product SHALL validate candidate probes on target hardware in this order until one is stable (no spurious unhealthy / C002 under normal preview, correct unhealthy when camera unreachable, no PR0/PR1 steal): (1) relay/path-informed composition, (2) short TCP connect to the RTSP port, (3) RTSP OPTIONS without media SETUP, (4) ICMP baseline. Unvalidated candidates MUST remain injectable/test-only until locked.

#### Scenario: Ladder stops at first stable rung

- **WHEN** a higher-priority probe candidate fails device validation
- **THEN** the next candidate SHALL be tried
- **AND** the production default MUST NOT switch to a failed candidate

#### Scenario: ICMP remains available as fallback

- **WHEN** TCP and OPTIONS candidates fail validation on the target camera
- **THEN** ICMP probing SHALL remain a valid production or fallback probe
- **AND** health Stream semantics (phases + debounce) SHALL be unchanged
