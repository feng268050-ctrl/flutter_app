## MODIFIED Requirements

### Requirement: Channels cover system OTA, control-board, and camera program

`cyber_upgrade_ui` SHALL identify at least three update channels: whole-device system OTA, control-board firmware, and camera program. System OTA presentation SHALL support multiple phases. Control-board presentation SHALL support a single transfer phase. Camera program presentation SHALL support App-defined phases that MAY include more than one phase (for example transfer, reboot, and wait-online) using the same multi-phase progress API as OTA. The package API MUST NOT assume only OTA and control-board exist. Product Apps are responsible for wiring a real camera flash/reboot/wait adapter; the package MUST NOT perform camera HTTP itself.

#### Scenario: Channel enum includes camera program

- **WHEN** a product App selects the camera program channel for a checker or upgrade session
- **THEN** `cyber_upgrade_ui` accepts that channel in its channel model without requiring `cyber_ota`

#### Scenario: System OTA uses multiple phases

- **WHEN** the App maps a whole-device session onto `cyber_upgrade_ui` progress
- **THEN** more than one phase MAY be active over the session lifetime (sequentially)

#### Scenario: Camera program may use multiple App-defined phases

- **WHEN** the App maps a camera program session onto transfer then reboot/wait-online phases
- **THEN** the progress UI SHALL accept that ordered phase list
- **AND** MAY show indeterminate progress for reboot/wait phases

### Requirement: Configurable upgrade completion tip

`cyber_upgrade_ui` SHALL support App-configured completion tip content for terminal success and failure (title/body and optional success notice) **and** an explicit post-apply action (`none` | `autoReboot`). Channels MUST NOT assume reboot of the **HMI board**: whole-device OTA configures **auto-reboot** completion (show notice, then device reboots automatically — not a manual reboot prompt); control-board and camera program configure no-board-reboot completion (camera may reboot its own IPC as part of App apply, outside this package). Success tips MUST NOT claim success when the progress snapshot is terminal failure. Failure tips MUST NOT claim partitions or firmware were updated successfully.

#### Scenario: Success tip then auto-reboot (OTA)

- **WHEN** progress is terminal success and the App configures post-apply `autoReboot` with a reboot notice
- **THEN** the completion tip presents that notice
- **AND** `willAutoReboot` is true
- **AND** the product SHALL reboot automatically after the configured delay (apply engine or `UpgradePostApplyListener`) without requiring the operator to confirm reboot

#### Scenario: Success tip without board reboot (control-board or camera)

- **WHEN** progress is terminal success and the App configures post-apply `none` with a success body for control-board or camera program
- **THEN** the completion tip presents that success body
- **AND** MUST NOT imply the HMI board will reboot

#### Scenario: Failure tip does not claim success

- **WHEN** progress is terminal failure
- **THEN** the completion tip presents failure content
- **AND** MUST NOT claim the upgrade completed successfully
