## ADDED Requirements

### Requirement: cyber_hal provides an independent ip_camera module

The HAL package SHALL expose `ip_camera` as a top-level domain alongside network/input/bluetooth-style modules. `IpCameraController` SHALL be constructible with an explicit camera host and MUST remain usable without assuming a dedicated ethernet camera cable topology. Multiple instances with different hosts SHALL be supported. Stub/fake backends SHALL support host tests.

#### Scenario: Explicit host construction

- **WHEN** the App constructs an `IpCameraController` with a given host string
- **THEN** that instance SHALL use the injected host for health probes and upstream stream URIs

#### Scenario: Stub backend is injectable

- **WHEN** tests supply a fake probe backend
- **THEN** health transitions SHALL be exercisable without real ICMP

### Requirement: cyber_hal ip_camera exposes testable recording control

The independent `ip_camera` domain SHALL expose recording request, status, result,
and controller APIs without introducing product modes or storage database concepts.
The Linux backend SHALL implement RTSP-to-file recording through the product
GStreamer runtime. A stub/fake recording controller SHALL permit host tests to
exercise preparing, recording, stopping, completed, failure, and cancellation.

#### Scenario: Recording API remains product-neutral

- **WHEN** an integrator inspects `IpCameraRecordingRequest`
- **THEN** it MAY contain source URIs, codec, destination, timeout, and retry policy
- **AND** it MUST NOT contain Quick Mode, Engineer Mode, process parameters, or product video-database fields
