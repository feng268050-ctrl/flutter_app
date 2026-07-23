# startup-device-user-binding-check Specification

## Purpose
TBD - created by syncing change startup-check-device-user-binding. Update Purpose after archive.

## Requirements
### Requirement: Trigger startup device-user binding check after network readiness
The system SHALL trigger a device-user binding check exactly once per app startup after the startup flow reaches network-ready state, which is defined as either (a) the WiFi reminder dialog flow has completed when that dialog is shown, or (b) network connectivity is already available and no WiFi reminder dialog is shown.

#### Scenario: Trigger after WiFi reminder flow
- **WHEN** startup shows the WiFi reminder dialog and the dialog flow reaches completion
- **THEN** the system SHALL schedule exactly one binding check attempt for the current startup session

#### Scenario: Trigger when network already available
- **WHEN** startup determines network connectivity is available and no WiFi reminder dialog is shown
- **THEN** the system SHALL schedule exactly one binding check attempt for the current startup session

### Requirement: Use device users API response for binding status
The system SHALL call `GET /v1/devices/:sn/users` and parse the response as `ApiResult`, using only `data` as the list of binding users for startup decision-making. Each user item consumed by the startup flow SHALL include only `id`, `nickname`, `avatar`, and masked `email`.

#### Scenario: Parse simplified user items
- **WHEN** the API call returns success with a non-empty `data` list
- **THEN** the system SHALL treat the device as already bound and SHALL NOT show the scan-to-bind reminder dialog in that startup session

#### Scenario: Empty users means unbound
- **WHEN** the API call returns success and `data` is an empty list
- **THEN** the system SHALL treat the device as unbound and continue to unbound reminder behavior

### Requirement: Show scan-to-bind reminder for unbound device
When startup binding check determines the device is unbound, the system SHALL show a scan-to-bind reminder dialog that follows the same visual style pattern as the WiFi reminder dialog. The dialog primary title and secondary title SHALL be loaded from Android string resources `bind_device_dialog_title` and `bind_device_dialog_subtitle` so copy is localized per app locale (default English in `values` / `values-en`; Simplified Chinese in `values-zh`). The main body area SHALL display the device binding QR code rendered from the same source/content as `Settings -> Device Information -> Machine Model`.

#### Scenario: Show reminder with reused QR source
- **WHEN** startup determines the device is unbound
- **THEN** the system SHALL show the scan-to-bind reminder dialog and SHALL display the QR content from the Machine Model QR source in the dialog body

#### Scenario: Dialog titles use localized string resources
- **WHEN** the scan-to-bind reminder dialog is visible
- **THEN** the primary title SHALL be `R.string.bind_device_dialog_title`, the secondary title SHALL be `R.string.bind_device_dialog_subtitle`, and the main content area SHALL prominently show the device QR code

### Requirement: Bind and registration device prompts use FrostedGlassDialog

Device binding and registration prompts shown via `GlobalDialogUtil.showBindDeviceDialog` and `GlobalDialogUtil.showDeviceRegistrationDialog` SHALL use `FrostedGlassDialog` with their existing prompt content (including QR or instructional body where applicable) in the custom body slot.

#### Scenario: Bind device prompt on FrostedGlass

- **WHEN** the startup binding check shows the bind-device prompt
- **THEN** the overlay MUST use `FrostedGlassDialog`
- **AND** confirm/cancel and QR display behavior MUST match pre-migration semantics

#### Scenario: Device registration prompt on FrostedGlass

- **WHEN** the app shows the device registration prompt
- **THEN** the overlay MUST use `FrostedGlassDialog`
- **AND** dismissal and registration callbacks MUST remain unchanged
