## ADDED Requirements

### Requirement: cyber_upgrade_ui package provides shared upgrade UX and check contracts

The repository SHALL provide a Flutter path package `packages/cyber_upgrade_ui` that exposes (1) domain types for upgrade channels, offers, check results, ordered phases, progress, and upgrade policy, (2) a pluggable version-check strategy interface, and (3) reusable widgets for version-check card, version-check / confirm dialog content, multi-phase progress with progress bar, and upgrade completion tips. Product Apps SHALL depend on this package via pubspec `path`. The package MUST NOT depend on `cyber_ota` or `cyber_hal`. The package MUST NOT perform whole-device partition writes or Modbus firmware transfer.

#### Scenario: Package is importable by the HMI app

- **WHEN** a developer adds `cyber_upgrade_ui` as a path dependency of `app/lws_hmi`
- **THEN** the app can import check/progress widgets and domain types without pulling `cyber_ota` or `cyber_hal` into `cyber_upgrade_ui`

#### Scenario: Package does not own apply engines

- **WHEN** an update session runs for system OTA or control-board firmware
- **THEN** verify/extract/apply or Modbus transfer remain outside `cyber_upgrade_ui`
- **AND** `cyber_upgrade_ui` only presents state supplied by the App

### Requirement: Pluggable version check with card and dialog presentations

`cyber_upgrade_ui` SHALL accept a caller-supplied version-check strategy that returns a structured check result (at least: checking in progress is App-driven; outcomes include up-to-date, update available with offer metadata, check unavailable, and check failed). The package SHALL provide an **in-panel check card** suitable for Settings-style pages and a **dialog-oriented confirm presentation** suitable for Home / modal flows. User-visible copy SHALL be supplied by the App (l10n), not hardcoded product strings inside the package. When an update is available, the card SHALL support an Update Now (and later/dismiss) action surface; the dialog SHALL support confirm / cancel.

#### Scenario: Custom checker drives card outcome

- **WHEN** the App supplies a checker that reports an available update with a newer version label
- **THEN** the check card presents the available state with App-provided version/notes strings and Update Now / later actions

#### Scenario: Dialog confirm for offline channel

- **WHEN** the App presents the check/confirm dialog for an offline channel offer
- **THEN** confirm and cancel actions are available
- **AND** starting apply MUST NOT occur solely because the dialog was shown

#### Scenario: Unavailable is distinct from up to date

- **WHEN** the checker reports that a check could not run
- **THEN** the check card MUST present unavailable (or equivalent)
- **AND** MUST NOT claim the device is up to date

### Requirement: Multi-phase progress UI with caller-defined phases

`cyber_upgrade_ui` SHALL render upgrade progress from an ordered list of phases supplied by the App plus a live progress snapshot (active phase id, optional 0–100 percent, optional indeterminate flag, optional message, terminal success/failure). The progress UI SHALL show a progress bar and SHALL highlight or list phases so multi-phase sessions (e.g. download → verify → extract → write → arm) and single-phase sessions (e.g. transferring) share the same widget API. The package MUST NOT hard-require the whole-device `OtaPhase` enum.

#### Scenario: Multi-phase OTA-shaped progress

- **WHEN** the App supplies multiple phases and advances the active phase with percent during download
- **THEN** the progress UI shows the active phase and a determinate progress bar reflecting that percent

#### Scenario: Single-phase channel progress

- **WHEN** the App supplies exactly one phase and updates percent from 0 to 100
- **THEN** the progress UI shows that phase and advancing progress without requiring additional phases

#### Scenario: Indeterminate phase

- **WHEN** progress marks indeterminate for the active phase
- **THEN** the progress UI shows an indeterminate indicator rather than a false determinate percent

### Requirement: Configurable upgrade completion tip

`cyber_upgrade_ui` SHALL support App-configured completion tip content for terminal success and failure (title/body and optional success notice) **and** an explicit post-apply action (`none` | `autoReboot`). Channels MUST NOT assume reboot: whole-device OTA configures **auto-reboot** completion (show notice, then device reboots automatically — not a manual reboot prompt); control-board (and similar flash) configures no-reboot completion. Success tips MUST NOT claim success when the progress snapshot is terminal failure. Failure tips MUST NOT claim partitions or firmware were updated successfully.

#### Scenario: Success tip then auto-reboot (OTA)

- **WHEN** progress is terminal success and the App configures post-apply `autoReboot` with a reboot notice
- **THEN** the completion tip presents that notice
- **AND** `willAutoReboot` is true
- **AND** the product SHALL reboot automatically after the configured delay (apply engine or `UpgradePostApplyListener`) without requiring the operator to confirm reboot

#### Scenario: Success tip without reboot (control-board)

- **WHEN** progress is terminal success and the App configures post-apply `none` with a success body
- **THEN** the completion tip presents that success body
- **AND** MUST NOT imply the device will reboot

#### Scenario: Failure tip does not claim success

- **WHEN** progress is terminal failure
- **THEN** the completion tip presents failure content
- **AND** MUST NOT claim the upgrade completed successfully

### Requirement: Update policy supports host make-push skip version check

`cyber_upgrade_ui` SHALL define an update policy that includes whether version checking is required and whether operator confirmation is required. Host make-push flows (whole-device OTA, control-board, and camera program when implemented) SHALL be expressible as policy with version check skipped (and typically confirmation skipped) while still allowing the App to show progress UI and run the channel apply path. Operator Settings / Home flows SHALL use policy with version check enabled and confirmation as required by the channel.

#### Scenario: Force policy skips version gate

- **WHEN** the App starts an update with policy that disables version checking
- **THEN** the flow MUST NOT block apply solely because the payload version is not newer than the running version
- **AND** progress UI MAY still be shown

#### Scenario: Operator policy keeps version gate

- **WHEN** the App starts a check-and-confirm flow with version checking enabled
- **THEN** an up-to-date check result MUST NOT proceed to apply without a separate force policy

### Requirement: Channels cover system OTA, control-board, and camera program

`cyber_upgrade_ui` SHALL identify at least three update channels: whole-device system OTA, control-board firmware, and camera program. System OTA presentation SHALL support multiple phases. Control-board and camera program presentation SHALL support a single transfer phase. Camera program MAY ship as a channel contract and checker/progress wiring without a complete flash implementation in the same change, but the package API MUST NOT assume only OTA and control-board exist.

#### Scenario: Channel enum includes camera program

- **WHEN** a product App selects the camera program channel for a future or stub checker
- **THEN** `cyber_upgrade_ui` accepts that channel in its channel model without requiring `cyber_ota`

#### Scenario: System OTA uses multiple phases

- **WHEN** the App maps a whole-device session onto `cyber_upgrade_ui` progress
- **THEN** more than one phase MAY be active over the session lifetime (sequentially)
