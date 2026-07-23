## ADDED Requirements

### Requirement: Connected WiFi details entry
The system SHALL allow users to open a dedicated details page for the currently connected WiFi network from the Network Settings Wireless Network flow.

#### Scenario: Open details for connected network
- **WHEN** a WiFi network is in connected state and the user taps the connected network details entry
- **THEN** the app opens a dedicated WiFi details page for that network
- **AND** the page includes a top back button to return to the previous screen

### Requirement: WiFi details information display
The WiFi details page SHALL display the connected network information in a simplified troubleshooting-oriented layout, including IP Address, Subnet Mask, and Router.

#### Scenario: Required fields are shown
- **WHEN** the WiFi details page is displayed for a connected network
- **THEN** the page shows labels and values for IP Address, Subnet Mask, and Router

#### Scenario: Additional useful fields are shown when available
- **WHEN** additional connection metadata is available for the connected network
- **THEN** the page shows a simplified set of additional fields including DNS, signal strength, link speed, security type, frequency/band, or MAC address

#### Scenario: Unavailable fields degrade gracefully
- **WHEN** any requested network detail value is unavailable
- **THEN** the page still renders successfully
- **AND** unavailable values are shown using a consistent fallback placeholder

### Requirement: Forget network behavior
The WiFi details page SHALL provide a `Forget This Network` action that disconnects the current WiFi connection and removes the saved network configuration in one confirmed flow.

#### Scenario: Forget connected network succeeds
- **WHEN** the user confirms `Forget This Network`
- **THEN** the app disconnects from the current WiFi network
- **AND** removes the saved configuration for that network

#### Scenario: Forget action failure is visible
- **WHEN** disconnect or removal fails during `Forget This Network`
- **THEN** the app informs the user that the operation did not fully complete
- **AND** preserves a consistent UI state without crashing
