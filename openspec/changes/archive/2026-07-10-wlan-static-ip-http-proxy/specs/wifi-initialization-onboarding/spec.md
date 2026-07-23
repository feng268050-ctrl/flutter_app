## MODIFIED Requirements

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
