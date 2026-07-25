## ADDED Requirements

### Requirement: Camera settings Status merges connection and relay into one row

The Camera settings page SHALL show a first read-only **Status** row whose trailing value reflects the combined product camera connection / MediaMTX relay readiness (e.g. connected, establishing, failed, or an equivalent localized status string). Separate operator-visible MediaMTX / MediaMTX detail rows MUST NOT appear. The page MUST NOT expose a manual Retry action for bring-up; background session retry policy MAY continue without UI.

#### Scenario: Status is the first settings row

- **WHEN** the operator opens Camera settings and the session is connected with relay ready
- **THEN** the first value row is labeled Status (localized)
- **AND** the trailing value indicates a connected/ready state
- **AND** no MediaMTX-labeled row is shown

#### Scenario: Establishing maps into Status

- **WHEN** the product UI phase is connecting or the relay is not yet ready
- **THEN** Status shows an establishing (or equivalent) value
- **AND** no Retry button is shown

### Requirement: Camera settings shows Camera Type and Camera Version

The Camera settings page SHALL show **Camera Type** as the second row and **Camera Version** as the third row (after Status). Camera Type SHALL use `product.ini` `camera_type` via HAL (`1` → `Blue Light`, `2` → `Red Light`; empty/invalid → `-`). Camera Version SHALL display the camera software version from a bounded device-info read (HTTP `GET …/System/deviceinfo` `appVersion` or equivalent product helper), or `-` when unavailable. The page MUST NOT show Camera IP or Preview URL rows.

#### Scenario: Camera type blue light

- **WHEN** `product.ini` contains `camera_type=1`
- **AND** the operator opens Camera settings
- **THEN** Camera Type SHALL display `Blue Light`

#### Scenario: Camera type red light

- **WHEN** `product.ini` contains `camera_type=2`
- **AND** the operator opens Camera settings
- **THEN** Camera Type SHALL display `Red Light`

#### Scenario: Camera version unavailable

- **WHEN** camera device-info cannot be read
- **THEN** Camera Version SHALL display `-`

#### Scenario: No IP or URL

- **WHEN** the operator opens Camera settings
- **THEN** Camera IP and Preview URL are not shown as settings rows

## MODIFIED Requirements

### Requirement: Product session owns topology, MediaMTX, and UI phases

The LWS product App SHALL compose a product session (name MAY vary) that uses `IpCameraController` plus product-specific path bring-up (dedicated eth0 via **Ethernet HAL** `setInterfaceEnabled` / `setIpv4Config` and a product address planner) and optional MediaMTX relay. UI phases `connecting` / `connected` / `failed`, attempt budget, Home status icon, and Settings preview localhost URLs SHALL be defined by that product session, not by portable `IpCameraController`. Future products MAY replace the path/relay strategy while reusing the same `ip_camera` HAL. The product MUST NOT introduce a separate eth0 configure shell that bypasses Ethernet HAL L3 apply. Settings Camera page SHALL present combined Status (not separate MediaMTX rows) and MUST NOT require a manual Retry control for operators.

#### Scenario: Home status uses product session

- **WHEN** product Home shows the camera status icon
- **THEN** the icon SHALL follow the product session UI phase Stream
- **AND** MAY combine HAL health with path/relay readiness

#### Scenario: Settings preview uses product relay URL on this product

- **WHEN** this product’s MediaMTX relay is running
- **AND** the operator opens Common Settings → Camera
- **THEN** preview SHALL bind a localhost MediaMTX URL published by the product session
- **AND** MUST NOT treat direct multi-client sessions to native `streams.pr0` as the required primary path on this product

#### Scenario: Settings Status does not expose MediaMTX internals

- **WHEN** the operator opens Common Settings → Camera
- **THEN** Status reflects combined connection/relay readiness
- **AND** MediaMTX is not shown as a separate labeled row
