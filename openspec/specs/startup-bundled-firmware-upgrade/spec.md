# startup-bundled-firmware-upgrade Specification

## Purpose

Home-only bundled control-board firmware upgrade: discover typed App assets under `assets/firmware/control-board/`, gate on live control HW/SW, confirm on Product Home, transfer via contiguous Modbus FC16 frames, plus host helper `make upgrade-control-board` for forced reflash without version gate.

## Requirements

### Requirement: Bundled firmware is checked only on Product Home

The system SHALL NOT check for bundled control-board firmware updates during process-library import, Application cold-start hooks that block first paint, or on screens other than Product Home.

The system SHALL run bundled firmware version evaluation only when Product Home is visible (e.g. after Home becomes the active route / resumes) and Modbus plus live control HW/SW attributes are available.

When the operator navigates away from Product Home, the system SHALL NOT present bundled-firmware upgrade prompts on other routes.

When the operator returns to Product Home and Modbus plus control versions are available, the system MAY run the check again.

Cold start and first paint of Product Home SHALL NOT block waiting for Modbus firmware transfer to finish.

#### Scenario: Home screen triggers check

- **WHEN** Product Home is visible and Modbus is available with valid `device.control_hw_version` and `device.control_card_version`
- **THEN** the system SHALL evaluate whether bundled firmware is newer than the control card

#### Scenario: Non-home screen does not prompt

- **WHEN** the operator is on Engineer Mode, Settings, Monitor, process modes, or any route other than Product Home
- **THEN** the system SHALL NOT show a bundled-firmware upgrade dialog solely due to bundled assets

#### Scenario: Cold start does not block on firmware

- **WHEN** the application process launches
- **THEN** routing to Product Home and first paint SHALL NOT wait for control-board Modbus firmware transfer to finish

#### Scenario: Modbus unavailable on home visit skips quietly

- **WHEN** the operator is on Product Home but Modbus is unavailable or control HW/SW attributes are not yet populated
- **THEN** the system SHALL NOT show a bundled-firmware upgrade dialog

### Requirement: Bundled firmware version comparison uses filename integer rules

The system SHALL discover bundled control-board firmware under Flutter assets `assets/firmware/control-board/` (`.bin` matching `LSW01H####S####.bin`, case-insensitive) and extract hardware and software version integers from the filename.

When multiple valid bundled bins are present, the system SHALL select the bin with the **highest software version** among those whose hardware version matches the live control-card hardware version.

The system SHALL compare bundled hardware version to live `device.control_hw_version`; if they differ, the system SHALL NOT offer upgrade and SHALL log the mismatch.

The system SHALL compare bundled software version to live `device.control_card_version`; upgrade SHALL be offered only when bundled software version is strictly greater than the device software version.

The system SHALL NOT use SemVer helpers for control-board firmware version ordering.

If zero valid bundled firmware filenames match the device hardware version, the system SHALL NOT offer upgrade.

#### Scenario: Newer bundled software triggers upgrade candidate

- **WHEN** bundled assets include `LSW01H1000S1013.bin` and device reports HW=1000, SW=1012
- **THEN** the system SHALL treat firmware as an upgrade candidate on Product Home

#### Scenario: Same software version skips upgrade

- **WHEN** the newest matching bundled software version equals device software version and hardware versions match
- **THEN** the system SHALL NOT invoke Modbus control-board firmware upgrade

#### Scenario: Hardware mismatch skips upgrade

- **WHEN** no bundled bin matches the device hardware version
- **THEN** the system SHALL NOT invoke Modbus control-board firmware upgrade

#### Scenario: Multiple bins select newest matching HW

- **WHEN** assets include `LSW01H1000S1013.bin`, `LSW01H1000S1017.bin`, and `LSW01H1001S1099.bin`, and device reports HW=1000
- **THEN** the system SHALL evaluate `LSW01H1000S1017.bin` as the bundled candidate

### Requirement: Bundled firmware upgrade always requires user confirmation via dialog

When an upgrade candidate is detected on Product Home, the system SHALL present a CyberUI dialog **composed with `cyber_upgrade_ui` check/confirm dialog primitives** that explains a control-board firmware update is available and warns to keep power connected and avoid operation during upgrade, using the existing `bundledFirmware*` localization keys.

The system SHALL start Modbus firmware transfer only after the operator explicitly confirms that dialog.

The Product Home bundled-firmware flow SHALL NOT provide automatic or silent in-app upgrade paths, including engineer-mode bypasses or build-time flags that skip the dialog. A separate explicit host operator helper MAY invoke the same control-board transfer without dialog, provided it is clearly named as a control-board-only upgrade path and does not reuse Product Home auto-prompt semantics.

If the operator dismisses the dialog (Later) or opens Settings from it, the system SHALL NOT start Modbus firmware upgrade for that dismissal. Home auto-detect SHALL run **at most once per HMI process** (typically once per boot): after a check completes (no candidate, or tip shown), returning to Product Home MUST NOT show the tip again until the next process start.

#### Scenario: User confirms starts Modbus transfer

- **WHEN** the operator confirms the bundled firmware dialog on Product Home
- **THEN** the system SHALL load the bundled `.bin` and start the Modbus control-board upgrade entrypoint

#### Scenario: User dismisses does not upgrade and does not re-prompt this boot

- **WHEN** the operator dismisses the bundled firmware dialog (Later)
- **THEN** the system SHALL NOT start Modbus firmware transfer as a result of that dismissal
- **AND** the system SHALL NOT show the same Home auto-detect tip again until the next HMI process start

#### Scenario: No silent upgrade path exists

- **WHEN** bundled firmware is newer than the control card and the Product Home check runs
- **THEN** the system SHALL NOT start Modbus firmware transfer without showing the confirmation dialog first

#### Scenario: Confirm dialog uses cyber_upgrade_ui primitives

- **WHEN** the Product Home bundled-firmware confirm dialog is shown after migration
- **THEN** its confirm/cancel content is built from `cyber_upgrade_ui` dialog primitives (mounted via the App tip/dialog host)
- **AND** copy remains App `bundledFirmware*` l10n

### Requirement: Host helper can trigger control-board-only upgrade without version gate

The repository SHALL provide a host helper named `make upgrade-control-board` that selects the newest (or explicitly overridden) control-board `.bin` under `assets/firmware/control-board/`, uploads it to the running device over SSH, and triggers the in-app control-board Modbus transfer without Home confirmation or same-version gate.

The helper SHALL communicate via a device tmpfs command file under `/run/hmi/` (watched by the HMI). It SHALL remain a strict subset of the broader host `make upgrade` naming family: it MUST target only control-board firmware and MUST NOT stream or modify rootfs, boot, OEM, GPT, or factory images.

The App SHALL map this host entry to **`cyber_upgrade_ui` update policy with version check skipped** (and confirmation skipped) while still showing progress UI during Modbus transfer.

#### Scenario: Host helper upgrades control board directly

- **WHEN** the operator runs `make upgrade-control-board`
- **THEN** the host SHALL upload one selected `LSW01H####S####.bin` to the running device
- **AND** the App SHALL start the control-board Modbus firmware transfer without waiting for a Product Home confirm dialog
- **AND** the helper SHALL ignore same-version gate
- **AND** the App SHALL treat the session as skip-version policy for `cyber_upgrade_ui`

### Requirement: Bundled firmware reuses Modbus upgrade register protocol

The bundled firmware path SHALL transfer the `.bin` over Modbus using contiguous holding-register FC16 writes aligned with lws-ui `ControllerUpgradeHandler` semantics: write firmware info, send sequential ≤128-byte data packets, then write end. Success SHALL be declared when all data packets succeed and FIRMWARE_END is accepted **or** END yields no ACK after retries following a complete data transfer (MCU may reset on END without Modbus ACK). Do **not** poll `device.ota_request_command` / `0x1212` / `0x0202` after end. Info or mid-transfer data write failures SHALL fail the session.

During transfer the system SHALL write contiguous Modbus holding FC16 frames matching lws-ui lengths (info ≈10 words, data = header+CRC+reserved+payload words only, end ≈14 words), not a full catalog-group rewrite of unused registers. The platform/App SHALL expose a contiguous holding-register write entrypoint for these frames. The system SHALL isolate competing continuous Modbus poll/watch sufficiently that chunk writes remain reliable, and SHALL resume normal live Modbus afterward.

On success, the system SHALL refresh the operator-visible Firmware Version (control-card software) to reflect the upgraded software version when live attributes are available.

On emulator / virt or environments without a real control card, the system SHALL skip or degrade without a blocking error that prevents normal Product Home use.

Progress and result dialogs SHALL use **`cyber_upgrade_ui` single-phase progress and completion tip primitives** (App mounts via tip/dialog host; `bundledFirmware*` strings).

#### Scenario: Offline device upgrades from App assets on Home

- **WHEN** the device has no network, the operator is on Product Home, the App bundle contains `assets/firmware/control-board/*.bin`, Modbus is available, and the operator confirms the dialog
- **THEN** the system SHALL upgrade control-board firmware without downloading an OTA zip

#### Scenario: Progress dialog during transfer

- **WHEN** bundled firmware upgrade is in progress after operator confirmation
- **THEN** the system SHALL show a blocking CyberUI progress dialog with determinate percent using `bundledFirmware*` strings and `cyber_upgrade_ui` progress primitives
- **AND** progress updates SHALL remain functional until success or failure
- **AND** the dialog content SHALL be width-bounded (not full-bleed stretch across the panel)

#### Scenario: Success result dialog

- **WHEN** Modbus control-board upgrade reports success
- **THEN** the system SHALL show the bundled firmware success title/message via `cyber_upgrade_ui` completion presentation and refresh Firmware Version display data when available

#### Scenario: Failure result dialog

- **WHEN** Modbus control-board upgrade fails or times out (other than same-version skip)
- **THEN** the system SHALL show the bundled firmware failed title/message via `cyber_upgrade_ui` completion presentation and SHALL NOT claim success

#### Scenario: Successful end write counts as success

- **WHEN** all firmware data packets succeed and FIRMWARE_END is ACKed (or END has no Modbus ACK after retries following a complete data transfer)
- **THEN** the system SHALL treat the upgrade as success without waiting for an `otaUpgradeCmd` latch

### Requirement: Bundled firmware does not use product OTA download flow

The bundled firmware feature SHALL NOT require HTTP download, zip extraction, Settings “Check for Updates”, or cloud `command.check_update` / `command.update_system` solely to apply firmware from App assets.

Device Information OTA footer controls MAY remain unavailable/deferred and MUST NOT be required for bundled firmware upgrade.

#### Scenario: Settings check-update is not required

- **WHEN** a bundled firmware candidate is applied from Home
- **THEN** the flow SHALL complete without invoking the Settings OTA check-update client

### Requirement: Bundled firmware mutex with future in-app OTA flash

The system SHALL maintain an in-app coordinator that prevents concurrent control-board Modbus firmware transfers between the bundled-home path and a future in-app product OTA firmware path.

While a bundled upgrade session is active, the system SHALL NOT start a second control-board Modbus firmware transfer.

#### Scenario: Second bundled session refused while busy

- **WHEN** a bundled firmware upgrade session is already in progress
- **THEN** a subsequent Product Home check SHALL NOT start another Modbus firmware transfer

### Requirement: Bundled firmware asset packaging

The repository SHALL keep control-board `.bin` files checked in under the Flutter App source path `assets/firmware/control-board/` (`LSW01H####S####.bin`). Git MAY retain multiple software versions and multiple hardware versions.

`make build-app` (via the shared prepare / ship-prune step) SHALL stage into the Flutter ship-asset tree **only the newest software version per hardware version** from that source directory. Historical bins that are not selected MUST NOT be copied into the shipped App bundle.

At runtime the App SHALL discover bundled bins from the ship asset prefix for control-board firmware and auto-select the newest matching-HW bin among those shipped (typically one per HW after prune).

The host helper `make upgrade-control-board` SHALL continue to select bins from the **git source** tree `assets/firmware/control-board/` (newest or `FIRMWARE_BIN` override), not from the generated ship tree.

#### Scenario: Built App contains bundled firmware asset

- **WHEN** `make build-app` (or equivalent App bundle) completes with one or more configured firmware source bins
- **THEN** the shipped App assets SHALL include a discoverable `LSW01H####S####.bin` for each hardware version that had at least one valid source bin
- **AND** for each such hardware version the shipped software version SHALL be the maximum among sources for that hardware

#### Scenario: Older firmware versions are not shipped

- **WHEN** the source tree contains `LSW01H1000S1013.bin` and `LSW01H1000S1017.bin`
- **THEN** after prepare / `build-app` the App bundle SHALL include `LSW01H1000S1017.bin` for HW 1000
- **AND** SHALL NOT include `LSW01H1000S1013.bin`

#### Scenario: Host helper still sees full source tree

- **WHEN** the operator runs `make upgrade-control-board` without `FIRMWARE_BIN`
- **THEN** the helper SHALL consider all valid bins under the git source `assets/firmware/control-board/` when picking the newest software version

### Requirement: Control-board offline check adapts into cyber_upgrade_ui

The App SHALL implement the control-board offline version gate (filename HW match + SW newer) as a `cyber_upgrade_ui` check strategy / adapter for the control-board channel. Modbus transfer and asset discovery remain App-owned. After migration, Product Home MUST NOT keep a parallel confirm/progress/result dialog implementation that bypasses `cyber_upgrade_ui` primitives.

#### Scenario: Offline checker feeds confirm dialog

- **WHEN** Product Home evaluates bundled firmware and finds a newer matching-HW candidate
- **THEN** the offer presented in the confirm dialog is produced through the control-board `cyber_upgrade_ui` check path
- **AND** Modbus transfer still runs only after confirm (operator policy)

### Requirement: Product Home may offer bundled camera firmware updates

In addition to control-board bundled firmware, the system SHALL evaluate bundled camera program firmware when Product Home is visible, the camera HTTP path is reachable, and ship assets include a valid camera ZIP.

Camera Home tips SHALL use `cyber_upgrade_ui` dialog primitives and App camera-upgrade l10n. Confirm SHALL start the camera CGI flash + reboot + wait-online path (not Modbus).

Home auto-detect for camera SHALL share the once-per-HMI-process tip budget family with control-board: after a camera tip is shown or a no-candidate check completes for camera in that process, returning to Home MUST NOT re-prompt camera until the next process start (unless implemented as a separate once flag that still prevents spam).

When both control-board and camera candidates are present, the system SHALL present the control-board tip first and SHALL NOT show the camera tip until the control-board tip flow has settled (confirmed, dismissed, or no CB candidate).

#### Scenario: Home offers camera when newer ZIP bundled

- **WHEN** Product Home is visible, camera deviceinfo is available, bundled camera ZIP is newer than live `appVersion`, and no control-board tip is pending
- **THEN** the system SHALL show a camera firmware update confirm tip

#### Scenario: Control-board tip takes priority

- **WHEN** both control-board and camera upgrade candidates exist on Product Home
- **THEN** the system SHALL present the control-board bundled-firmware tip before any camera tip

#### Scenario: Camera dismiss does not flash

- **WHEN** the operator dismisses the camera Home tip
- **THEN** the system SHALL NOT start CGI camera upgrade from that dismissal
