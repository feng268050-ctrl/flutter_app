## Purpose

Define expected behavior for viewing and managing details of the currently connected WiFi network in Network Settings.
## Requirements
### Requirement: Connected WiFi details entry

The system SHALL allow users to open a dedicated details page for the currently connected WiFi network from the Network Settings Wireless Network flow.

#### Scenario: Open details for connected network
- **WHEN** a WiFi network is in connected state and the user taps the connected network details entry
- **THEN** the app opens a dedicated WiFi details page for that network
- **AND** the page includes a top back button to return to the previous screen

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

### Requirement: Operation button label casing
Operation button labels in this flow SHALL use Title Case in English, where each word starts with a capital letter.

#### Scenario: Forget confirmation dialog labels
- **WHEN** the forget confirmation dialog is displayed in English
- **THEN** the primary and secondary action labels are `Confirm` and `Cancel`

#### Scenario: Open system settings fallback label
- **WHEN** the fallback dialog asks the user to open system WiFi settings in English
- **THEN** the confirm action label is `Settings`

### Requirement: Forget-network actions match Safety Operation Tips primary button styling

The system SHALL present the forget-network confirmation dialog using `FrostedGlassDialog` (雾化玻璃设计 shell with live backdrop blur), with title, message, and Confirm/Cancel actions in the standard frosted-glass action slot or equivalent custom action bar consistent with other migrated settings prompts.

#### Scenario: Forget confirmation dialog uses FrostedGlass shell

- **WHEN** the user triggers `Forget` from the WiFi details page
- **THEN** the confirmation dialog MUST be shown via `FrostedGlassDialog.prompt(...)`
- **AND** MUST NOT use a standalone legacy `Dialog` window as the primary visual container

#### Scenario: Confirm and cancel actions follow app-standard button pattern

- **WHEN** the forget-network confirmation dialog is displayed
- **THEN** both `Confirm` and `Cancel` actions use frosted-glass action button styling
- **AND** enabled/disabled states keep consistent contrast and visual affordance with other migrated settings dialogs

### Requirement: Settings menu keeps stable order with Date & Time insertion
The Settings navigation in this capability's host flow SHALL preserve existing item order semantics while inserting `Date & Time` immediately after `Screen Settings`.

#### Scenario: Existing entries remain stable around insertion point
- **WHEN** the Settings menu is rendered after this change
- **THEN** items before `Screen Settings` keep their previous relative order
- **AND** `Date & Time` appears directly after `Screen Settings`
- **AND** items previously after `Screen Settings` remain in their relative order after the inserted entry

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

### Requirement: Connected network signal metadata uses SSID representative scan

When resolving scan-backed metadata (signal strength, Wi-Fi standard, lock icon) for the currently connected network on the Wi-Fi list or when navigating to Wi-Fi details, the system SHALL use the SSID aggregation rules from `wifi-scan-ssid-roaming`: prefer the representative scan result for the connected SSID when BSSID-specific scan match is unavailable.

#### Scenario: Connected row uses representative RSSI when BSSID not in scan cache

- **WHEN** the device is connected to SSID `Office-Net`
- **AND** the latest scan contains `Office-Net` on a different BSSID than the active association
- **THEN** the connected row signal indicator MAY use the representative (strongest RSSI) scan result for `Office-Net`
- **AND** the UI MUST still show SSID `Office-Net` exactly once in the list header area

