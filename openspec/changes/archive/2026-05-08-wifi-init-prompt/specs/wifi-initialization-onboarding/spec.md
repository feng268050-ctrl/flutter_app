## ADDED Requirements

### Requirement: WiFi initialization completion flag

The system SHALL maintain a persistent boolean flag `wifi_initialization_completed` (or equivalent storage key) that defaults to false when absent. When true, the system SHALL treat WiFi onboarding as finished for the lifetime of that app data (survive reboot; not reset when the user disconnects or forgets WiFi networks).

#### Scenario: Default on fresh install

- **WHEN** the application is installed and the flag has never been written
- **THEN** the system SHALL behave as if `wifi_initialization_completed` is false

#### Scenario: Survives WiFi disconnect

- **WHEN** `wifi_initialization_completed` is true and the device has no WiFi connection
- **THEN** the system SHALL NOT show the WiFi initialization reminder dialog solely because WiFi is disconnected

### Requirement: Reminder dialog before initialization

The system SHALL show a user-visible dialog prompting the user to connect to WiFi **only when** `wifi_initialization_completed` is false **and** the device is not connected to WiFi per the implementation-chosen connectivity check (documented in code). The system SHALL NOT show this dialog when the device is already connected to WiFi. The dialog SHALL include a confirm action that opens WiFi settings (system WiFi settings intent or product-approved equivalent).

#### Scenario: Show when uninitialized and not on WiFi

- **WHEN** `wifi_initialization_completed` is false and the device is not connected to WiFi
- **THEN** the system SHALL show the reminder dialog at the defined entry point in the app flow

#### Scenario: Confirm opens WiFi settings

- **WHEN** the user activates the confirm action on the reminder dialog
- **THEN** the system SHALL navigate to WiFi settings (or equivalent) so the user can connect to a network

#### Scenario: No dialog when already on WiFi

- **WHEN** `wifi_initialization_completed` is false but the device is already connected to WiFi at the onboarding evaluation
- **THEN** the system SHALL NOT show the reminder dialog

### Requirement: Mark initialization complete on first WiFi connection

The system SHALL set `wifi_initialization_completed` to true the first time it detects that the device has successfully connected to WiFi (using the same connectivity semantics as for suppressing the dialog). This includes **immediately** when the device is already connected at the onboarding check, not only after a transition from disconnected to connected. After this write, the system SHALL NOT show the WiFi initialization reminder dialog again.

#### Scenario: Already connected at check sets flag immediately

- **WHEN** `wifi_initialization_completed` is false and the device is already connected to WiFi at the onboarding entry point
- **THEN** the system SHALL immediately persist `wifi_initialization_completed` as true before any reminder dialog could be shown

#### Scenario: First connection persists

- **WHEN** the device transitions to a connected WiFi state and `wifi_initialization_completed` was false
- **THEN** the system SHALL persist `wifi_initialization_completed` as true

#### Scenario: No reminder after completion

- **WHEN** `wifi_initialization_completed` is true
- **THEN** the system SHALL NOT show the WiFi initialization reminder dialog

#### Scenario: Forgotten network does not reset flag

- **WHEN** `wifi_initialization_completed` is true and the user removes or forgets all WiFi networks
- **THEN** the system SHALL keep `wifi_initialization_completed` true and SHALL NOT show the reminder dialog
