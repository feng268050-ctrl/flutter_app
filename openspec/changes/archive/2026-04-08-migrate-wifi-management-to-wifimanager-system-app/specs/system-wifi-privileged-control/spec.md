## ADDED Requirements

### Requirement: Privileged WiFi management execution
The system SHALL execute WiFi management actions (connect, disconnect, forget, and saved
network update) through `WifiManager` control APIs without invoking suggestion-based approval
flows when the app is running as a properly privileged system app.

#### Scenario: Connect action runs silently with privileged runtime
- **WHEN** the app has required privileged capability and the user initiates connect
- **THEN** the app performs connection using `WifiManager` APIs without suggestion prompts
- **AND** the user remains in-app through the operation flow

#### Scenario: Forget action runs silently with privileged runtime
- **WHEN** the app has required privileged capability and the user confirms forget
- **THEN** the app disconnects and removes the target network through `WifiManager` APIs
- **AND** no suggestion approval UI is required

### Requirement: Privileged permission prerequisites are explicit
The system SHALL require `NETWORK_SETTINGS` permission wiring for this capability, including
manifest declaration and privileged deployment/signing conditions needed by Android for the
permission to be granted in runtime.

#### Scenario: Privileged prerequisites satisfied
- **WHEN** the app is installed as a privileged system app with proper signing and allowlisting
- **THEN** WiFi privileged actions are executable through manager APIs

#### Scenario: Privileged prerequisites not satisfied
- **WHEN** required privileged conditions are missing
- **THEN** the app does not claim successful silent management
- **AND** it surfaces an actionable failure state for the attempted operation
