## MODIFIED Requirements

### Requirement: Host helper can trigger control-board-only upgrade without version gate

The repository SHALL provide a host helper named `make upgrade-control-board` that selects the newest (or explicitly overridden) control-board `.bin` under `assets/firmware/control-board/`, **signs it with the system OTA Ed25519 tooling**, **serves the `.bin` and sibling `.sig` over ephemeral host HTTP**, and triggers the in-app control-board Modbus transfer without Home confirmation or same-version gate via `/run/hmi/upgrade-control-board.cmd` using **`download <url>`**.

The helper SHALL communicate via a device tmpfs command file under `/run/hmi/` (watched by the HMI). It SHALL remain a strict subset of the broader host `make upgrade` naming family: it MUST target only control-board firmware and MUST NOT stream or modify rootfs, boot, OEM, GPT, or factory images. SSH SHALL NOT be used as the bulk transfer path for the `.bin`.

The App SHALL map this host entry to **`cyber_upgrade_ui` update policy with version check skipped** (and confirmation skipped) while still showing progress UI during Modbus transfer. Before Modbus transfer, the App MUST Ed25519-verify the downloaded `.bin`.

#### Scenario: Host helper upgrades control board directly

- **WHEN** the operator runs `make upgrade-control-board`
- **THEN** the host SHALL serve one selected `LSW01H####S####.bin` (and `.sig`) over HTTP and write `download <url>` for the running device
- **AND** the App SHALL download, verify, and start the control-board Modbus firmware transfer without waiting for a Product Home confirm dialog
- **AND** the helper SHALL ignore same-version gate
- **AND** the App SHALL treat the session as skip-version policy for `cyber_upgrade_ui`

### Requirement: Bundled firmware does not use product OTA download flow

The bundled-from-assets apply path SHALL NOT require HTTP download, Settings “Check for Updates”, or cloud `command.check_update` / `command.update_system` solely to apply firmware that is already present in App assets.

Cloud check/download for control-board firmware (when offered) is a separate path documented by `peripheral-firmware-cloud-ota` and MUST NOT be required for offline bundled apply. Device Information system OTA controls MUST NOT be required for bundled firmware upgrade.

#### Scenario: Settings check-update is not required

- **WHEN** a bundled firmware candidate is applied from Home
- **THEN** the flow SHALL complete without invoking the Settings system OTA check-update client

## ADDED Requirements

### Requirement: Home and Settings select newest of bundled and cloud control-board candidates

When evaluating whether to offer a control-board firmware update (Product Home tip or Settings control-board upgrade page), the system SHALL consider both the bundled matching-HW candidate and, when cloud check is possible, the cloud `control-board/release.json` candidate, and SHALL offer the newer of the two (prefer bundled on equal version). Apply of a cloud-selected candidate MUST verify Ed25519 before Modbus transfer.

#### Scenario: Home tip may use newer cloud control-board firmware

- **WHEN** Product Home is visible, Modbus versions are available, cloud release offers a HW-matching SW newer than both device and bundled, and cloud origin is reachable
- **THEN** the system SHALL treat the cloud payload as the upgrade candidate for the Home tip
- **AND** SHALL start Modbus transfer only after operator confirmation and successful verify
