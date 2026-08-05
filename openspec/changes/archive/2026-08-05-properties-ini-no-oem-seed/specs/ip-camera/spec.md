## MODIFIED Requirements

### Requirement: IpCamera is constructed with an injected host and supports multiple instances

`IpCameraController` SHALL take the camera host (IP address or hostname) at construction time. Reachability of that host MAY be via any IP path (dedicated link, Wi‑Fi LAN, routed/internet, etc.); the HAL MUST NOT require a particular interface in its public contract. The package SHALL allow **multiple** `IpCameraController` instances with different hosts to coexist in one process. This product App SHALL instantiate **at most one** live controller whose host comes from App `effectiveCameraIp` (properties.ini `camera_ip`, else product default `192.168.1.100`).

#### Scenario: Host is constructor-injected

- **WHEN** an App constructs `IpCameraController` with host `203.0.113.10`
- **THEN** `cameraHost` SHALL be `203.0.113.10`
- **AND** upstream stream URIs SHALL be derived from that host

#### Scenario: Multiple controllers coexist

- **WHEN** the process holds two controllers for hosts `192.168.1.100` and `192.168.1.101`
- **THEN** each SHALL expose its own health Stream and streams
- **AND** disposing one MUST NOT tear down the other

#### Scenario: This product uses properties.ini host when set

- **WHEN** the LWS HMI App starts its IP-camera integration and `properties.ini` has `camera_ip=10.0.0.5`
- **THEN** it SHALL construct one `IpCameraController` with host `10.0.0.5`

#### Scenario: Missing camera_ip uses App product default

- **WHEN** `camera_ip` is absent and the LWS HMI App starts IP-camera integration
- **THEN** it SHALL construct the controller with `192.168.1.100`

### Requirement: Camera settings shows Camera Type and Camera Version

The Camera settings page SHALL show **Camera Type** as the second row and **Camera Version** as the third row (after Status). Camera Type SHALL use App-resolved `camera_type` from `ProductInfo.get` + product defaults (`1` → `Blue Light`, `2` → `Red Light`; invalid → `-`; absent → default `1` / Blue Light). Camera Version SHALL display the camera software version from a bounded device-info read (HTTP `GET …/System/deviceinfo` with Basic Auth `admin:admin`, then normalize `appVersion`: strip leading `v`/`V`, cut at first ` build`/` BUILD`), or `-` when unavailable. The same authenticated, normalized value SHALL feed cloud WS `deviceInfo.cameraVersion` via a shared per-host cache. Host resolution SHALL use App `effectiveCameraIp` (properties.ini or product default `192.168.1.100`). The page MUST NOT show Camera IP or Preview URL rows.

#### Scenario: Camera type blue light

- **WHEN** `properties.ini` contains `camera_type=1`
- **AND** the operator opens Camera settings
- **THEN** Camera Type SHALL display `Blue Light`

#### Scenario: Camera type red light

- **WHEN** `properties.ini` contains `camera_type=2`
- **AND** the operator opens Camera settings
- **THEN** Camera Type SHALL display `Red Light`

#### Scenario: Camera version unavailable

- **WHEN** camera device-info cannot be read
- **THEN** Camera Version SHALL display `-`

#### Scenario: Missing camera_ip uses default host for version probe

- **WHEN** `camera_ip` is blank and the operator opens Camera settings
- **THEN** version probe SHALL use the App product default host `192.168.1.100`

#### Scenario: No IP or URL

- **WHEN** the operator opens Camera settings
- **THEN** Camera IP and Preview URL MUST NOT be shown as settings rows
