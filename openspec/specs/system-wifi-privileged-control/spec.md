## Purpose

Define privileged WiFi management behavior when the app runs as a system app with
`NETWORK_SETTINGS` and related deployment prerequisites satisfied.
## Requirements
### Requirement: Privileged WiFi management execution
The system SHALL execute WiFi management actions (connect, disconnect, forget, and saved
network update) through `WifiManager` control APIs without invoking suggestion-based approval
flows when the app is running as a properly privileged system app. Connect and update operations SHALL apply saved DHCP or STATIC IPv4 settings from `WifiNetworkProfile` via `WifiConnectionCoordinator` and `WifiIpConfigApplier` when the user supplies or has stored a profile.

#### Scenario: Connect action runs silently with privileged runtime
- **WHEN** the app has required privileged capability and the user initiates connect
- **THEN** the app performs connection using `WifiManager` APIs without suggestion prompts
- **AND** applies DHCP or STATIC configuration from the connect request or stored profile
- **AND** the user remains in-app through the operation flow

#### Scenario: Forget action runs silently with privileged runtime
- **WHEN** the app has required privileged capability and the user confirms forget
- **THEN** the app disconnects and removes the target network through `WifiManager` APIs
- **AND** no suggestion approval UI is required

### Requirement: Privileged permission prerequisites are explicit
The system SHALL require `NETWORK_SETTINGS` permission wiring for this capability, including
manifest declaration and privileged deployment/signing conditions needed by Android for the
permission to be granted in runtime. When required privileged conditions are not available
(including emulator-like environments), the system SHALL surface a deterministic unavailable
state and SHALL NOT terminate app startup due to privileged WiFi capability initialization.

#### Scenario: Privileged prerequisites satisfied
- **WHEN** the app is installed as a privileged system app with proper signing and allowlisting
- **THEN** WiFi privileged actions are executable through manager APIs

#### Scenario: Privileged prerequisites not satisfied
- **WHEN** required privileged conditions are missing
- **THEN** the app does not claim successful silent management
- **AND** it surfaces an actionable failure state for the attempted operation

#### Scenario: Startup continues when privileged runtime is unavailable
- **WHEN** privileged WiFi capability checks fail during startup initialization
- **THEN** the app startup flow continues without process crash
- **AND** the system records capability-unavailable diagnostics for operator debugging

### Requirement: Open WiFi join uses dialog when IP configuration is required

The system SHALL NOT silently connect open WiFi networks without passing through the join dialog when the user may need to configure STATIC IP or review Advanced IP settings. Direct silent connect for open networks is only permitted when product logic explicitly skips the dialog for already-saved profiles with confirmed DHCP and no user interaction required.

#### Scenario: Open network shows join dialog

- **WHEN** the user taps an unconnected open WiFi network from the list
- **THEN** the app MUST open the WiFi join dialog (password hidden, IP settings available)
- **AND** MUST NOT call connect until the user submits via IME Connect or equivalent primary submit path

