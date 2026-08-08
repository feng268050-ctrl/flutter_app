## MODIFIED Requirements

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

## ADDED Requirements

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
