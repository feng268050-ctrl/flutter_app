# host-peripheral-firmware-upgrade Specification

## Purpose

Host `make upgrade-control-board` / `upgrade-camera`: sign peripheral blobs, serve over ephemeral HTTP, device `download <url>` + Ed25519 verify, then host-force Modbus / CGI apply (SSH control plane only).

## Requirements

### Requirement: make upgrade-control-board uses signed host HTTP and device download

The repository SHALL provide **`make upgrade-control-board`** that selects the newest (or `FIRMWARE_BIN=` overridden) control-board `.bin` under git source `assets/firmware/control-board/`, produces a detached Ed25519 `.sig` beside that file (or a staged copy) using the same signing tooling and key as system OTA (`ota-sign.sh` / `OTA_SIGNING_KEY`), starts an ephemeral host HTTP server that serves the `.bin` and sibling `.sig`, and triggers the on-device HMI via `/run/hmi/upgrade-control-board.cmd` with a **`download <url>`** line (URL of the `.bin`; device discovers `.sig` as `url + ".sig"`).

SSH SHALL be used as a control plane only (write cmd + wait for transfer complete). The helper MUST NOT SSH-stream the firmware bytes as the bulk transfer path. The helper MUST NOT modify rootfs/boot/OEM/GPT/factory images.

Device selection SHALL match other USB-SSH / `SN=` / `IP=` helpers. HTTP bind/advertise SHALL honor `OTA_HTTP_HOST` / `OTA_HTTP_PORT` with the same defaults family as `make upgrade` where applicable.

On device, after HTTP download into a documented staging directory under `/userdata/ota/`, the App MUST Ed25519-verify the `.bin` against `/etc/ota/ed25519.pub` before starting Modbus transfer. Host-force policy SHALL skip version gates and Home confirmation while still showing progress UI.

#### Scenario: Host force downloads signed control-board firmware

- **WHEN** the operator runs `make upgrade-control-board` with signing configured and a reachable SSH board
- **THEN** the host SHALL serve the selected `.bin` and `.sig` over HTTP
- **AND** SHALL write `download <url>` to `/run/hmi/upgrade-control-board.cmd`
- **AND** the App SHALL download, verify, and start Modbus transfer without Home confirm or newer-version gate

#### Scenario: Missing signature refuses host control-board upgrade

- **WHEN** signing is not configured or the `.sig` cannot be produced
- **THEN** `make upgrade-control-board` SHALL exit non-zero before writing the cmd file
- **AND** MUST NOT fall back to unsigned SSH upload as the default path

#### Scenario: Verify failure refuses Modbus apply

- **WHEN** the device downloads a control-board `.bin` whose Ed25519 verification fails
- **THEN** the App SHALL refuse Modbus transfer
- **AND** MUST NOT claim upgrade success

### Requirement: make upgrade-camera uses signed host HTTP and device download

The repository SHALL provide **`make upgrade-camera`** that selects the newest (or `FIRMWARE_ZIP=` overridden) camera firmware ZIP under git source `assets/firmware/camera/`, signs it with the same OTA Ed25519 tooling, serves ZIP + `.sig` over ephemeral host HTTP, and triggers `/run/hmi/upgrade-camera.cmd` with **`download <url>`**.

SSH SHALL NOT be the bulk transfer path. After download and successful Ed25519 verify, the App SHALL run camera CGI flash + reboot + wait-online under host-force policy (no Home confirm / version gate). Mutex with control-board Modbus and whole-device OTA SHALL remain enforced.

#### Scenario: Host force downloads signed camera firmware

- **WHEN** the operator runs `make upgrade-camera` with signing configured and a reachable SSH board
- **THEN** the host SHALL serve the selected ZIP and `.sig` over HTTP
- **AND** SHALL write `download <url>` to `/run/hmi/upgrade-camera.cmd`
- **AND** the App SHALL download, verify, and start CGI flash without Home confirm

#### Scenario: Missing signature refuses host camera upgrade

- **WHEN** signing is not configured or the `.sig` cannot be produced
- **THEN** `make upgrade-camera` SHALL exit non-zero before writing the cmd file
