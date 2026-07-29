## ADDED Requirements

### Requirement: Home may offer bundled control-board firmware upgrade after Modbus is ready

Product Home SHALL remain the launcher and first-paint target. After Product Home is visible and Modbus live plus control HW/SW attributes are available (and after boot self-check completes when that overlay runs), Product Home SHALL host the bundled control-board firmware check and optional confirm/progress dialogs per `startup-bundled-firmware-upgrade`.

When the operator navigates away and later returns to Product Home with Modbus and control versions still available, Product Home MAY re-run the bundled-firmware check (e.g. via route awareness).

Product Home first paint SHALL NOT wait on bundled firmware Modbus transfer. Non-home routes SHALL NOT host the bundled-firmware prompt.

#### Scenario: First paint does not wait on bundled firmware transfer

- **WHEN** the App navigates to Product Home as the initial route
- **THEN** Home chrome SHALL paint without waiting for control-board firmware Modbus transfer to finish

#### Scenario: Bundled firmware prompt only on Home

- **WHEN** an upgrade candidate exists and Modbus versions are available while Product Home is visible
- **THEN** the system MAY present the bundled firmware confirmation dialog on Product Home
- **AND** the same candidate SHALL NOT cause prompts solely because Settings or Engineer Mode is open

#### Scenario: Return to Home may re-check

- **WHEN** the operator returns to Product Home and Modbus plus control HW/SW are available
- **THEN** the system MAY evaluate the bundled-firmware candidate again
