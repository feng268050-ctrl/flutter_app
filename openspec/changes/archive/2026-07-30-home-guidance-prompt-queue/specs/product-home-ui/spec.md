## ADDED Requirements

### Requirement: Home bootstrap uses global prompt queue after self-check

After Product Home has painted and boot self-check has completed or been skipped, Product Home bootstrap SHALL start Modbus live and warn presentation flush onto the **global prompt queue** without waiting for Wi‑Fi or cloud guidance enrollment. Guidance prompts SHALL enroll into the same queue asynchronously when eligible. First paint MUST remain free of waiting on prompt dialogs.

#### Scenario: Warn flush does not wait for cloud

- **WHEN** Home bootstrap finishes boot self-check (or skips it)
- **AND** cloud bind/registration eligibility is not yet known
- **THEN** the App SHALL still allow warn prompts to enqueue and present via the global prompt queue
- **AND** MUST NOT block that path on network readiness

#### Scenario: Guidance joins same FIFO later

- **WHEN** a guidance prompt becomes eligible after warn prompts are already queued or showing
- **THEN** the guidance prompt SHALL enqueue behind them on the global prompt queue

## MODIFIED Requirements

### Requirement: Home may offer bundled control-board firmware upgrade after Modbus is ready

Product Home SHALL remain the launcher and first-paint target. After Product Home is visible and Modbus live plus control HW/SW attributes are available (and after boot self-check completes when that overlay runs), Product Home SHALL enroll the bundled control-board firmware check into the **global prompt queue** when an upgrade candidate exists. Confirm/progress dialogs SHALL follow `startup-bundled-firmware-upgrade` and MUST NOT use an independent modal host that stacks over other prompts.

When the operator navigates away and later returns to Product Home with Modbus and control versions still available, Product Home MAY re-run the bundled-firmware check (e.g. via route awareness). Re-checks MUST still avoid stacking over an active prompt dialog (enqueue on the global queue).

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

#### Scenario: Bundled firmware uses global prompt queue

- **WHEN** an upgrade candidate exists while Product Home is hosting prompts
- **THEN** the bundled firmware confirm flow SHALL be enqueued on the global prompt queue
- **AND** MUST NOT open in parallel with another prompt dialog
