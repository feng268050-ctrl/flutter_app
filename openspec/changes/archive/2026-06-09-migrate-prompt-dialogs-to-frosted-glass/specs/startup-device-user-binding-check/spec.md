## ADDED Requirements

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
