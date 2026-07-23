## MODIFIED Requirements

### Requirement: Soft keyboard primary action shows Connect

The WiFi password field SHALL configure the custom in-app IME Enter key to display the same user-facing Connect label used for that flow today (including localized strings). The system soft keyboard and `EditText.setImeActionLabel` MUST NOT be required for this behavior once the custom IME is active.

#### Scenario: Custom Enter key label matches Connect string

- **WHEN** the password field is focused and the custom IME keyboard is shown
- **THEN** the Enter key MUST be labeled with the same string resource used for the former Connect control in the active locale
- **AND** MUST use primary orange Enter styling

#### Scenario: Enter submits password

- **WHEN** the user taps Enter on the custom keyboard while entering the password
- **THEN** the app MUST validate non-empty password, initiate the existing privileged connect flow on success, and dismiss the dialog
- **AND** on empty password MUST show the existing required-password feedback without connecting
