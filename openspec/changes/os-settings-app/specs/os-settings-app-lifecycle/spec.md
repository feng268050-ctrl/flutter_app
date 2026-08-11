## ADDED Requirements

### Requirement: settings.service is static and conflicts with hmi.service

The rootfs SHALL ship `settings.service` that launches the Settings Flutter bundle via `/usr/libexec/hmi/settings-launch.sh` (or equivalent under the HMI libexec tree) with `BUNDLE=/opt/settings`. The unit MUST NOT be enabled in `multi-user.target.wants` (static / on-demand only). `settings.service` and `hmi.service` SHALL declare bidirectional `Conflicts=` so starting one stops the other. Boot MUST continue to enable only `hmi.service` as the default Flutter seat.

#### Scenario: Boot does not auto-start Settings

- **WHEN** the appliance reaches multi-user after flash/upgrade with Settings present
- **THEN** `hmi.service` is enabled/wanted and Settings is not in `multi-user.target.wants`

#### Scenario: Start settings stops HMI

- **WHEN** `hmi.service` is active and the operator runs `systemctl start settings`
- **THEN** `hmi.service` stops and Settings becomes the foreground Flutter client

### Requirement: Switch helpers and settings CLI

The image SHALL provide `/usr/bin/switch-to-settings` (`systemctl start settings`) and `/usr/bin/switch-to-hmi` (`systemctl start hmi`). `/usr/bin/settings` SHALL refuse to take the display while `hmi.service` is active unless invoked with `--stop-hmi` (which stops HMI then runs Settings in the foreground). Interrupting a foreground `settings --stop-hmi` session (Ctrl+C) MUST NOT automatically start `hmi.service`; only Exit / `switch-to-hmi` restores HMI.

#### Scenario: CLI refuses grab

- **WHEN** `hmi.service` is active and the operator runs `settings` without `--stop-hmi`
- **THEN** the command exits non-zero without stopping HMI

#### Scenario: Ctrl+C does not restore HMI

- **WHEN** the operator runs `settings --stop-hmi` and then interrupts the process
- **THEN** `hmi.service` is not automatically started

### Requirement: HMI explicit entry to Settings

The product HMI SHALL expose an explicit System Settings (or equivalent) control that invokes `switch-to-settings`. On missing `/opt/settings` bundle or `systemctl start settings` failure, the HMI SHALL show a Toast (or equivalent) and MUST remain on the HMI seat. Hidden multi-tap on Kernel Version MUST NOT be the primary entry path.

#### Scenario: Entry failure stays on HMI

- **WHEN** the operator activates System Settings and Settings fails to start
- **THEN** a failure Toast is shown and `hmi.service` remains the active UI
