# wifi-initialization-onboarding Specification

## Purpose
TBD - created by archiving change wifi-init-prompt. Update Purpose after archive.
## Requirements
### Requirement: WiFi initialization completion flag

The system SHALL maintain a persistent boolean flag `wifi_initialization_completed` (or equivalent storage key) that defaults to false when absent. When true, the system SHALL treat WiFi onboarding as finished for the lifetime of that app data (survive reboot; not reset when the user disconnects or forgets WiFi networks).

#### Scenario: Default on fresh install

- **WHEN** the application is installed and the flag has never been written
- **THEN** the system SHALL behave as if `wifi_initialization_completed` is false

#### Scenario: Survives WiFi disconnect

- **WHEN** `wifi_initialization_completed` is true and the device has no WiFi connection
- **THEN** the system SHALL NOT show the WiFi initialization reminder dialog solely because WiFi is disconnected

### Requirement: Reminder dialog before initialization

The system SHALL show a user-visible dialog prompting the user to connect to WiFi **only when** `wifi_initialization_completed` is false **and** the device does not have a **usable WiFi L3 connection** (associated with a non-zero IPv4 address per `WifiLinkSnapshot` / `WifiStatusUtils` usable connection semantics). WiFi association without an IPv4 address MUST NOT count as connected for suppressing the reminder. The dialog SHALL include a confirm action that opens WiFi settings (system WiFi settings intent or product-approved equivalent).

#### Scenario: Show when uninitialized and not on WiFi

- **WHEN** `wifi_initialization_completed` is false and the device has no usable WiFi L3 connection
- **THEN** the system SHALL show the reminder dialog at the defined entry point in the app flow

#### Scenario: Confirm opens WiFi settings

- **WHEN** the user activates the confirm action on the reminder dialog
- **THEN** the system SHALL navigate to WiFi settings (or equivalent) so the user can connect to a network

#### Scenario: No dialog when L3-ready on WiFi

- **WHEN** `wifi_initialization_completed` is false but the device already has a usable WiFi L3 connection at onboarding evaluation
- **THEN** the system SHALL NOT show the reminder dialog

#### Scenario: Associated without IP still shows reminder

- **WHEN** `wifi_initialization_completed` is false and WiFi is associated but IPv4 is not assigned
- **THEN** the system SHALL treat the device as not network-ready for onboarding
- **AND** MAY show the reminder dialog or guide the user to configure STATIC IP in the join flow

### Requirement: Mark initialization complete on first WiFi connection

The system SHALL set `wifi_initialization_completed` to true the first time it detects that the device has a **usable WiFi L3 connection** (same semantics as suppressing the dialog). Association without IPv4 MUST NOT mark initialization complete. After this write, the system SHALL NOT show the WiFi initialization reminder dialog again.

#### Scenario: Already connected at check sets flag immediately

- **WHEN** `wifi_initialization_completed` is false and the device already has a usable WiFi L3 connection at the onboarding entry point
- **THEN** the system SHALL immediately persist `wifi_initialization_completed` as true before any reminder dialog could be shown

#### Scenario: First connection persists

- **WHEN** the device transitions to a usable WiFi L3 state and `wifi_initialization_completed` was false
- **THEN** the system SHALL persist `wifi_initialization_completed` as true

#### Scenario: No reminder after completion

- **WHEN** `wifi_initialization_completed` is true
- **THEN** the system SHALL NOT show the WiFi initialization reminder dialog

#### Scenario: Forgotten network does not reset flag

- **WHEN** `wifi_initialization_completed` is true and the user removes or forgets all WiFi networks
- **THEN** the system SHALL keep `wifi_initialization_completed` true and SHALL NOT show the reminder dialog

### Requirement: Startup post-onboarding hook for binding check

The WiFi initialization onboarding flow SHALL expose a deterministic post-onboarding hook that runs after the WiFi reminder dialog path completes (if shown) or immediately after confirming network-ready state (if reminder is skipped), so downstream startup steps can execute network-dependent checks.

#### Scenario: Hook runs after dialog-based onboarding

- **WHEN** WiFi onboarding presents a reminder dialog path during startup
- **THEN** the post-onboarding hook SHALL run only after that dialog path completes

#### Scenario: Hook runs for already-connected startup

- **WHEN** WiFi onboarding determines startup is already network-ready without showing the reminder dialog
- **THEN** the post-onboarding hook SHALL run in the same startup session

### Requirement: WiFi initialization prompt uses FrostedGlassDialog

The WiFi onboarding initialization prompt shown via `GlobalDialogUtil.showWifiInitializationDialog` SHALL use `FrostedGlassDialog` for its overlay shell; title, message, confirm, and cancel semantics MUST remain unchanged.

#### Scenario: WiFi init dialog on FrostedGlass

- **WHEN** the app shows the WiFi initialization prompt during onboarding
- **THEN** the dialog MUST render as a `FrostedGlassDialog` overlay
- **AND** confirm and cancel callbacks MUST behave identically to the pre-migration implementation

