# ip-camera Specification

## Purpose
Portable IP-network camera HAL (`cyber_hal` `ip_camera`) for host, upstream RTSP streams, health observation, and recording control; plus this product’s session contract for dedicated-link bring-up, MediaMTX relay, Home status, and Settings preview—without encoding product L3 topology in the portable HAL API.

## Requirements
### Requirement: IpCamera is constructed with an injected host and supports multiple instances

`IpCameraController` SHALL take the camera host (IP address or hostname) at construction time. Reachability of that host MAY be via any IP path (dedicated link, Wi‑Fi LAN, routed/internet, etc.); the HAL MUST NOT require a particular interface in its public contract. The package SHALL allow **multiple** `IpCameraController` instances with different hosts to coexist in one process. This product App SHALL instantiate **exactly one** controller whose host comes from `product.ini` `camera_ip` via `ProductInfo` (else a documented fixed default).

#### Scenario: Host is constructor-injected

- **WHEN** an App constructs `IpCameraController` with host `203.0.113.10`
- **THEN** `cameraHost` SHALL be `203.0.113.10`
- **AND** upstream stream URIs SHALL be derived from that host

#### Scenario: Multiple controllers coexist

- **WHEN** the process holds two controllers for hosts `192.168.1.100` and `192.168.1.101`
- **THEN** each SHALL expose its own health Stream and streams
- **AND** disposing one MUST NOT tear down the other

#### Scenario: This product uses a single product.ini host

- **WHEN** the LWS HMI App starts its IP-camera integration
- **THEN** it SHALL construct one `IpCameraController`
- **AND** the host SHALL be `ProductInfo.cameraIp()` when set, otherwise the product default camera IP

### Requirement: IpCamera is a network-dependent input domain, not folded into input

IP cameras are an input source that **requires the network stack**; `ip_camera` SHALL remain a top-level HAL domain and MUST NOT be folded into `input`. Cameras attached via serial/USB (no IP network path), if added later, SHALL belong under `input` with other locally attached input devices. The public `IpCameraController` API MUST NOT encode product-specific L3 topologies (dedicated eth0 camera links, address planners, or MediaMTX lifecycle).

#### Scenario: Module is independent of input

- **WHEN** a product imports IP camera HAL APIs
- **THEN** it SHALL import `package:cyber_hal/ip_camera.dart` (or equivalent `ip_camera` barrel)
- **AND** MUST NOT be required to import `input` solely to use IP camera health/streams

#### Scenario: Serial or USB cameras are not ip_camera

- **WHEN** a future product adds a camera connected only via serial or USB
- **THEN** that device SHALL be modeled under `input` (or an input sub-API)
- **AND** MUST NOT be required to live in the `ip_camera` module

#### Scenario: Public API has no eth0 dedicated-link operations

- **WHEN** an integrator reviews `IpCameraController` public members
- **THEN** there SHALL be no API whose contract requires configuring a dedicated eth0 camera segment or starting MediaMTX

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

### Requirement: Product session owns topology, MediaMTX, and UI phases

The LWS product App SHALL compose a product session (name MAY vary) that uses `IpCameraController` plus product-specific path bring-up (dedicated eth0 via **Ethernet HAL** `setInterfaceEnabled` / `setIpv4Config` and a product address planner) and optional MediaMTX relay. UI phases `connecting` / `connected` / `failed`, attempt budget, Home status icon, and Settings preview localhost URLs SHALL be defined by that product session, not by portable `IpCameraController`. Future products MAY replace the path/relay strategy while reusing the same `ip_camera` HAL. The product MUST NOT introduce a separate eth0 configure shell that bypasses Ethernet HAL L3 apply.

#### Scenario: Home status uses product session

- **WHEN** product Home shows the camera status icon
- **THEN** the icon SHALL follow the product session UI phase Stream
- **AND** MAY combine HAL health with path/relay readiness

#### Scenario: Settings preview uses product relay URL on this product

- **WHEN** this product’s MediaMTX relay is running
- **AND** the operator opens Input → IP Camera
- **THEN** preview SHALL bind a localhost MediaMTX URL published by the product session
- **AND** MUST NOT treat direct multi-client sessions to native `streams.pr0` as the required primary path on this product

### Requirement: IpCamera HAL records RTSP streams with readiness and finalize closure

`IpCameraController` SHALL expose a recording controller with current status plus a
change-oriented status Stream. A recording request SHALL identify one or more RTSP
source candidates, an output file, codec/container information, and a bounded
ready timeout. Starting SHALL remain `preparing` until the media pipeline has
actually received writable stream data; merely spawning a process MUST NOT be
reported as `recording`. Stopping SHALL finalize the container and return the
saved file path only when a non-empty finalized file exists. Each camera instance
SHALL permit at most one active recording, while separate camera instances remain
independent.

#### Scenario: Start waits for RTSP media readiness

- **WHEN** `start` creates a recording pipeline but no RTSP media has reached the muxer
- **THEN** status SHALL remain `preparing`
- **AND** the start Future SHALL remain pending
- **WHEN** the pipeline reports preroll/first writable media
- **THEN** status SHALL become `recording`
- **AND** the start Future SHALL complete successfully

#### Scenario: Unready candidate retries inside HAL

- **WHEN** a source candidate exits before media readiness
- **AND** the request ready timeout has not expired
- **THEN** HAL SHALL clean its partial output and retry the next candidate
- **AND** product UI MUST NOT own that retry loop

#### Scenario: Stop finalizes and reports the output file

- **WHEN** an active recording is stopped
- **THEN** HAL SHALL request EOS and wait a bounded time for container finalization
- **AND** a successful result SHALL contain the final output path and non-zero size

#### Scenario: Preparing recording can be cancelled

- **WHEN** stop or dispose occurs while status is `preparing`
- **THEN** HAL SHALL terminate the in-flight pipeline
- **AND** MUST NOT emit a false `completed` result or retain a partial file
