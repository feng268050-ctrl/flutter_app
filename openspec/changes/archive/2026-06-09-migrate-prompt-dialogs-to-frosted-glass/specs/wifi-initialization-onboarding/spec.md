## ADDED Requirements

### Requirement: WiFi initialization prompt uses FrostedGlassDialog

The WiFi onboarding initialization prompt shown via `GlobalDialogUtil.showWifiInitializationDialog` SHALL use `FrostedGlassDialog` for its overlay shell; title, message, confirm, and cancel semantics MUST remain unchanged.

#### Scenario: WiFi init dialog on FrostedGlass

- **WHEN** the app shows the WiFi initialization prompt during onboarding
- **THEN** the dialog MUST render as a `FrostedGlassDialog` overlay
- **AND** confirm and cancel callbacks MUST behave identically to the pre-migration implementation
