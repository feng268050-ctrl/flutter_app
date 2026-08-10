# camera-program-upgrade Specification

## Purpose

Offline bundled and cloud camera firmware upgrade: ship newest ZIP per model, gate on live `appVersion`, flash via Boa CGI multipart, reboot + wait-online success, Settings/Home UX (newest-wins), and host `make upgrade-camera` (signed HTTP + `download`).

## Requirements

### Requirement: Bundled camera firmware discovery and version gate

The system SHALL discover bundled camera firmware ZIP assets under the Flutter ship prefix `assets/.generated/firmware/camera/` matching `{MODEL}-v{SEMVER} build{YYYYMMDD}.zip` (case-insensitive model; SemVer `X.Y.Z`; eight-digit build).

When multiple valid ZIPs for the same model are present at runtime, the system SHALL select the newest by SemVer then build integer.

The system SHALL read the live camera software version from `GET /System/deviceinfo` (`appVersion` / `app_version`) on the product camera HTTP port (9000) with the same Basic Auth used for camera deviceinfo/OSD.

The system SHALL offer a camera program upgrade only when the bundled (SemVer, build) pair is strictly greater than the device (SemVer, build) pair. Host force policy MAY skip this gate.

If the camera is unreachable or `appVersion` cannot be parsed, the checker SHALL report unavailable (or failed) and MUST NOT claim the camera is up to date.

#### Scenario: Newer bundled ZIP is an upgrade candidate

- **WHEN** the ship tree contains `LTC609-v1.0.7 build20260513.zip` and deviceinfo reports `v1.0.5 build20251127`
- **THEN** the camera program checker SHALL report an update available for that ZIP

#### Scenario: Same or older bundled version skips offer

- **WHEN** the newest bundled ZIP is not strictly newer than the live camera SemVer+build
- **THEN** the checker SHALL report up to date (operator policy)
- **AND** SHALL NOT start CGI flash solely from that check

#### Scenario: Unreachable camera is unavailable

- **WHEN** Product Home or Settings runs a camera program check and deviceinfo cannot be fetched
- **THEN** the checker SHALL report unavailable or failed
- **AND** MUST NOT present “up to date”

### Requirement: Camera CGI multipart flash uses OSD-style HTTP client

The App SHALL upload the selected firmware package with `POST /cgi-bin/cgic_upgrade` as `multipart/form-data` with form field `name="file"`, a filename, and `Content-Type: application/octet-stream` for the file part.

The upload MUST be issued through the camera raw-socket HTTP client used for OSD overlay (single TCP write of request headers and body framing compatible with that firmware), not through Dart `HttpClient` body writes that split headers and body across segments.

HTTP response status **200** SHALL be required to treat the transfer phase as successful. Any other status SHALL fail the upgrade session.

Default payload SHALL be the staged `.zip` bytes with the ZIP basename as `filename` (no mandatory unpack of inner members in v1).

#### Scenario: Successful CGI upgrade returns 200

- **WHEN** the App posts a valid multipart firmware body to `/cgi-bin/cgic_upgrade` and the camera responds 200
- **THEN** the transfer phase SHALL be marked successful
- **AND** the session SHALL proceed to reboot

#### Scenario: Non-200 CGI response fails transfer

- **WHEN** the camera responds with a status other than 200 to `/cgi-bin/cgic_upgrade`
- **THEN** the App SHALL fail the upgrade session
- **AND** MUST NOT claim success

#### Scenario: Flash uses raw-socket client

- **WHEN** camera program upgrade performs the CGI POST
- **THEN** the request SHALL go through the OSD-style raw-socket HTTP client API
- **AND** SHALL include Basic Auth compatible with camera deviceinfo/OSD

### Requirement: Post-flash camera reboot and re-online success gate

After a successful CGI upgrade response, the App SHALL call `PUT /System/reboot` with an empty body on the same camera HTTP base (port 9000, Basic Auth). Success of that call SHALL require HTTP **200**.

The App MUST NOT treat CGI 200 alone as upgrade success. The session SHALL enter a wait-online phase that polls until the camera is reachable again (at least successful `GET /System/deviceinfo` after cache invalidate, or equivalent health reachability).

If the camera does not become reachable within the configured timeout, the session SHALL fail even if CGI and reboot returned 200.

Progress UI SHALL expose App-defined phases covering at least transfer, reboot, and wait-online (reboot/wait MAY be indeterminate). Completion tip SHALL NOT reboot the HMI board.

#### Scenario: Reboot called after successful flash

- **WHEN** CGI upgrade returns 200
- **THEN** the App SHALL issue `PUT /System/reboot` with no body
- **AND** SHALL require HTTP 200 for the reboot phase to succeed

#### Scenario: Success only after camera returns

- **WHEN** CGI and reboot both return 200 and deviceinfo becomes reachable again within timeout
- **THEN** the App SHALL mark the camera program upgrade successful
- **AND** SHALL refresh the operator-visible Camera Version when possible

#### Scenario: Timeout after reboot is failure

- **WHEN** CGI and reboot return 200 but the camera does not become reachable within the wait timeout
- **THEN** the App SHALL mark the upgrade failed
- **AND** MUST NOT present a success completion tip

### Requirement: Camera program Settings and Home UX

The App SHALL provide a Settings camera program upgrade page using `cyber_upgrade_ui` check card / progress / completion primitives for `UpgradeChannel.cameraProgram`, analogous to the control-board upgrade page.

The Device Information (and IP Camera settings when showing Camera Version) Camera Version affordance SHALL navigate to that page.

On Product Home, when a bundled camera upgrade candidate exists and the camera is reachable, the system SHALL present a confirm tip via `cyber_upgrade_ui` dialog primitives (operator policy). Home auto-detect for camera SHALL run at most once per HMI process (same once-per-boot budget family as control-board). When both control-board and camera candidates exist, the system SHALL prefer presenting the control-board tip first and defer camera until after that tip is settled or no control-board candidate remains.

#### Scenario: Settings page can check and update

- **WHEN** the operator opens the camera program upgrade page and runs check with a newer bundled ZIP
- **THEN** the check card SHALL show update available
- **AND** Update Now SHALL start flash only after operator confirmation (operator policy)

#### Scenario: Home tip for camera candidate

- **WHEN** Product Home is visible, camera is reachable, bundled ZIP is newer, and no higher-priority control-board tip is pending
- **THEN** the system SHALL show a camera firmware update confirm tip
- **AND** SHALL start CGI flash only after confirm

### Requirement: Host helper make upgrade-camera

The repository SHALL provide `make upgrade-camera` that selects the newest (or `FIRMWARE_ZIP=` overridden) camera firmware ZIP under git source `assets/firmware/camera/`, **signs it with the system OTA Ed25519 tooling**, **serves the ZIP and sibling `.sig` over ephemeral host HTTP**, and triggers in-app camera program upgrade without Home confirmation or same-version gate (`UpgradePolicy.hostForce`) via `/run/hmi/upgrade-camera.cmd` using **`download <url>`**.

The helper SHALL use a `/run/hmi/` command file watched by the HMI and MUST NOT modify rootfs/boot/OEM/GPT/factory images. SSH SHALL NOT be used as the bulk transfer path for the ZIP.

While a camera program session is active, the App SHALL refuse starting a concurrent camera session and SHALL coordinate with the existing firmware/OTA mutex so camera flash does not run concurrently with control-board Modbus transfer or whole-device OTA apply. Before CGI flash, the App MUST Ed25519-verify the downloaded ZIP.

#### Scenario: Host force upgrades camera

- **WHEN** the operator runs `make upgrade-camera`
- **THEN** the host SHALL serve one selected camera ZIP (and `.sig`) over HTTP and write `download <url>`
- **AND** the App SHALL download, verify, and start camera CGI flash + reboot + wait-online without Home confirm
- **AND** SHALL skip the newer-version gate

#### Scenario: Busy mutex refuses second session

- **WHEN** a camera program or other firmware/OTA upgrade session is already active
- **THEN** a new camera program start SHALL be refused
- **AND** SHALL NOT start a second CGI flash

### Requirement: Camera Settings and Home select newest of bundled and cloud candidates

When evaluating camera program updates (Settings page or Product Home tip), the system SHALL consider both the bundled model-matching ZIP and, when cloud check is possible, the cloud `camera/release.json` candidate, and SHALL offer the newer of the two by SemVer then build (prefer bundled on equal version). Product Home tips and auto-check-on-open SHALL honor Device Information Auto-Check for Updates. A cloud-selected apply MUST Ed25519-verify before CGI flash. During CGI flash / reboot / wait-online, the App SHALL quiet C002 per `camera-communication-alarm` (suspend probes + suppress alarm edges).

#### Scenario: Settings may offer newer cloud camera firmware

- **WHEN** the operator opens the camera program upgrade page, cloud `camera/release.json` offers a model-compatible ZIP newer than both device and bundled, and cloud origin is reachable
- **THEN** the check card SHALL show update available for that cloud ZIP
- **AND** Update Now SHALL download, verify, and start flash only after operator confirmation

#### Scenario: Camera apply quiets C002

- **WHEN** Update Now (or host force) runs camera CGI flash / reboot / wait-online
- **THEN** C002 health probes SHALL be suspended for that window
- **AND** SHALL resume when the session ends
