## ADDED Requirements

### Requirement: os-settings.service is static and conflicts with hmi.service

The rootfs SHALL ship `os-settings.service` that launches the OS Settings Flutter bundle via `/usr/libexec/hmi/os-settings-launch.sh` (or equivalent under the HMI libexec tree) with `BUNDLE=/opt/os_settings`. The unit MUST NOT be enabled in `multi-user.target.wants` (static / on-demand only). `os-settings.service` and `hmi.service` SHALL declare bidirectional `Conflicts=` so starting one stops the other. Boot MUST continue to enable only `hmi.service` as the default Flutter seat.

#### Scenario: Boot does not auto-start OS Settings

- **WHEN** the appliance reaches multi-user after flash/upgrade with OS Settings present
- **THEN** `hmi.service` is enabled/wanted and OS Settings is not in `multi-user.target.wants`

#### Scenario: Start os-settings stops HMI

- **WHEN** `hmi.service` is active and the operator runs `systemctl start os-settings`
- **THEN** `hmi.service` stops and OS Settings becomes the foreground Flutter client

### Requirement: Switch helpers and os-settings CLI

The image SHALL provide `/usr/bin/switch-to-os-settings` (`systemctl start os-settings`) and `/usr/bin/switch-to-hmi` (`systemctl start hmi`). `/usr/bin/os-settings` SHALL refuse to take the display while `hmi.service` is active unless invoked with `--stop-hmi` (which stops HMI then runs OS Settings in the foreground). Interrupting a foreground `os-settings --stop-hmi` session (Ctrl+C) MUST NOT automatically start `hmi.service`; only Exit / `switch-to-hmi` restores HMI.

#### Scenario: CLI refuses grab

- **WHEN** `hmi.service` is active and the operator runs `os-settings` without `--stop-hmi`
- **THEN** the command exits non-zero without stopping HMI

#### Scenario: Ctrl+C does not restore HMI

- **WHEN** the operator runs `os-settings --stop-hmi` and then interrupts the process
- **THEN** `hmi.service` is not automatically started

### Requirement: HMI explicit entry to OS Settings

The product HMI SHALL expose an explicit OS Settings (or equivalent) control that invokes `switch-to-os-settings`. On missing `/opt/os_settings` bundle or `systemctl start os-settings` failure, the HMI SHALL show a Toast (or equivalent) and MUST remain on the HMI seat. Hidden multi-tap on Kernel Version MUST NOT be the primary entry path.

#### Scenario: Entry failure stays on HMI

- **WHEN** the operator activates OS Settings and OS Settings fails to start
- **THEN** a failure Toast is shown and `hmi.service` remains the active UI
