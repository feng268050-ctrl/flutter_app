## MODIFIED Requirements

### Requirement: Forget network behavior
The WiFi details page SHALL provide a `Forget` action that disconnects the current WiFi
connection and removes the saved network configuration in one confirmed flow using
`WifiManager` APIs, without relying on suggestion approval UI.

#### Scenario: Forget connected network succeeds
- **WHEN** the user confirms `Forget` and privileged WiFi control is available
- **THEN** the app disconnects from the current WiFi network
- **AND** removes the saved configuration for that network using manager APIs
- **AND** keeps the user in the app flow without opening suggestion/system approval pages

#### Scenario: Forget action failure is visible
- **WHEN** disconnect or removal fails during `Forget`
- **THEN** the app informs the user that the operation did not fully complete
- **AND** preserves a consistent UI state without crashing

### Requirement: Operation button label casing
Operation button labels in this flow SHALL use Title Case in English, where each word
starts with a capital letter.

#### Scenario: Forget confirmation dialog labels
- **WHEN** the forget confirmation dialog is displayed in English
- **THEN** the primary and secondary action labels are `Confirm` and `Cancel`
