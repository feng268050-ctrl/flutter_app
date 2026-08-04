# camera-osd-overlay Specification

## Purpose
TBD - created by archiving change camera-settings-overlay. Update Purpose after archive.
## Requirements
### Requirement: Camera OSD apply uses showtime, NameOverlay, and saveConf

The App SHALL provide a single camera OSD apply path that, given `enable` ∈ {0,1}, `positionx`, and `positiony`, talks to the camera module HTTP API (host from trimmed `product.ini` `camera_ip` else `192.168.1.100`, port 9000, Basic Auth `admin:admin`) in this order:

1. `PUT /System/showtime` with enable and position; when enable=1 fill **local** wall-clock fields (device timezone), when enable=0 fill zeros.
2. `GET /Media/Video/overlays?channel=1`, mutate `VideoOverlay.NameOverlay` (enable=1 → `enable=1`, `x=positionx`, `y=positiony+50`, `name` = trimmed product `model`; enable=0 → `enable=0`), then `PUT` the updated overlay document.
3. `PUT /System/saveConf` (empty body).

Coordinate validation SHALL match lws-ui / `show-camera-overlay`: X ∈ [0, 384]; Y ∈ [0, 288]; when enable=1, Y MUST be ≤ 238. Defaults when omitted: X=10, Y=10. Concurrent applies MUST be serialized (one in flight). The NameOverlay `name` SHALL be the Device Information Device Model display string (`brand` + `model`); the Settings Overlay dialog MUST NOT offer a name editor.

#### Scenario: Enable clock and name overlay

- **WHEN** apply is invoked with `enable=1`, `positionx=20`, `positiony=30`
- **AND** the camera HTTP API accepts showtime, overlays, and saveConf
- **THEN** showtime is written at (20, 30) with local wall-clock now
- **AND** NameOverlay is written with enable=1, x=20, y=80, name equal to the Device Information Device Model string
- **AND** saveConf succeeds
- **AND** the apply result reports success

#### Scenario: Disable overlays

- **WHEN** apply is invoked with `enable=0`
- **AND** the camera HTTP API accepts the writes
- **THEN** showtime enable is 0
- **AND** NameOverlay enable is 0
- **AND** saveConf succeeds

#### Scenario: Name comes from Device Model without a dialog field

- **WHEN** Settings Apply or LAN show-overlay runs with enable=1
- **THEN** NameOverlay `name` MUST equal the Device Information Device Model display (`brand` + `model`)
- **AND** the Overlay dialog MUST NOT present a name editor

#### Scenario: Reject out-of-range Y when enabled

- **WHEN** apply is invoked with `enable=1` and `positiony=250`
- **THEN** the apply MUST fail validation without calling saveConf as success
- **AND** MUST NOT leave the caller hanging without a result

#### Scenario: Camera unreachable

- **WHEN** camera HTTP is unreachable during apply
- **THEN** the apply MUST return a structured failure promptly
- **AND** MUST NOT hang beyond a documented bounded timeout

### Requirement: Settings and LAN HTTP share the OSD apply path

Camera Overlay dialog **Apply** and `POST /v1/camera/show-overlay` MUST invoke the same App OSD apply path (same validation and camera HTTP sequence). They MUST share the apply serialization lock so one submit completes before another starts.

#### Scenario: LAN and Settings do not overlap camera writes

- **WHEN** a Settings Overlay dialog Apply is in flight
- **AND** a LAN client posts `/v1/camera/show-overlay`
- **THEN** the LAN request MUST wait for or be sequenced after the in-flight apply
- **AND** MUST NOT interleave showtime/overlays/saveConf with the Settings apply

