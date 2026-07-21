## MODIFIED Requirements

### Requirement: Boot self-check triggers once per process on first Home entry

When the operator first reaches product Home after a **system boot** (power-on or reboot), and the boot-self-check preference is enabled, and self-check has not yet been consumed for that boot, the App SHALL start a boot self-check sequence. Within the same system boot, subsequent HMI process starts (including `hmi.service` restart, crash recovery, or app hot-push) MUST NOT re-run the self-check. Within a single process, subsequent Home entries MUST NOT re-run the self-check. The initial route MUST remain Home; self-check MUST be presented as an overlay after Home has painted (MUST NOT replace Home as `initialRoute`).

Boot consumption SHALL be recorded in a runtime marker under `/run/hmi/` (tmpfs) so it clears automatically on reboot. The App MUST NOT use a durable `/var/lib/hmi/` preference file as the sole once-per-boot gate.

#### Scenario: First Home entry after boot starts self-check when enabled

- **WHEN** the system has just booted (no boot self-check marker under `/run/hmi/` yet)
- **AND** product Home becomes visible for the first time in the HMI process
- **AND** the boot-self-check preference is enabled
- **THEN** the coordinator SHALL begin the check pipeline
- **AND** a self-check progress dialog SHALL be shown as an overlay on Home

#### Scenario: Second Home entry in the same process skips self-check

- **WHEN** the operator leaves Home and returns within the same process
- **AND** boot self-check has already completed in this process
- **THEN** the self-check dialog MUST NOT be shown again

#### Scenario: HMI restart within the same boot skips self-check

- **WHEN** boot self-check has already completed (or been marked consumed) earlier in this system boot
- **AND** the HMI process exits and starts again without a system reboot
- **AND** the operator reaches Home
- **THEN** the self-check dialog MUST NOT be shown

#### Scenario: Preference disabled skips self-check

- **WHEN** the boot-self-check preference is disabled
- **AND** the operator reaches Home
- **THEN** the self-check dialog MUST NOT be shown
- **AND** the coordinator SHALL treat the sequence as complete for gate/resume purposes
- **AND** the boot SHALL be marked consumed so a later HMI restart in the same boot still skips self-check

#### Scenario: Next system boot can show self-check again

- **WHEN** the system reboots or power-cycles
- **AND** the boot-self-check preference is enabled
- **AND** product Home becomes visible for the first time after that boot
- **THEN** the self-check dialog SHALL be shown (unless the preference is disabled)
