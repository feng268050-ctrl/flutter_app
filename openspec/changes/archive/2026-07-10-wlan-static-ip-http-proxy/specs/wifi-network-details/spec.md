## MODIFIED Requirements

### Requirement: WiFi details information display
The WiFi details page SHALL display the connected network information in a simplified troubleshooting-oriented layout, including IP Address, Subnet Mask, and Router. The page SHALL also display IP mode (DHCP or STATIC), DNS1, and DNS2 when available. Displayed link values MUST reflect current system `LinkProperties` (actual runtime state), not merely the saved profile.

#### Scenario: Required fields are shown
- **WHEN** the WiFi details page is displayed for a connected network
- **THEN** the page shows labels and values for IP Address, Subnet Mask, and Router

#### Scenario: Additional useful fields are shown when available
- **WHEN** additional connection metadata is available for the connected network
- **THEN** the page shows a simplified set of additional fields including IP mode, DNS, DNS2, signal strength, link speed, security type, frequency/band, or MAC address

#### Scenario: Unavailable fields degrade gracefully
- **WHEN** any requested network detail value is unavailable
- **THEN** the page still renders successfully
- **AND** unavailable values are shown using a consistent fallback placeholder

### Requirement: Forget network behavior
The WiFi details page SHALL provide a `Forget` action that disconnects the current WiFi
connection and removes the saved network configuration in one confirmed flow using
`WifiManager` APIs, without relying on suggestion approval UI. Forgetting the network SHALL also remove the stored `WifiNetworkProfile` for that SSID and security type.

#### Scenario: Forget connected network succeeds
- **WHEN** the user confirms `Forget` and privileged WiFi control is available
- **THEN** the app disconnects from the current WiFi network
- **AND** removes the saved configuration for that network using manager APIs
- **AND** removes the associated IP profile from storage
- **AND** keeps the user in the app flow without opening suggestion/system approval pages

#### Scenario: Forget action failure is visible
- **WHEN** disconnect or removal fails during `Forget`
- **THEN** the app informs the user that the operation did not fully complete
- **AND** preserves a consistent UI state without crashing

## ADDED Requirements

### Requirement: Edit IP Configuration primary action on WiFi details

The WiFi details page SHALL provide an **Edit IP Configuration** action implemented as a `FrostButtonView` with `frostedGlassButtonVariant="primary"`, matching the visual size and styling of the existing **Forget This Network** button (`btn_forget` in `activity_wifi_details.xml`).

#### Scenario: Edit button uses primary Frost button styling

- **WHEN** the WiFi details page is displayed
- **THEN** the Edit IP Configuration control MUST use `FrostButtonView` primary variant
- **AND** MUST match the Forget button dimensions and centered placement pattern

#### Scenario: Edit opens profile editor

- **WHEN** the user taps Edit IP Configuration
- **THEN** the app MUST open an editor bound to `WifiNetworkProfile` for the current SSID and security type
- **AND** saving MUST persist the profile and reconnect or re-apply settings as needed
