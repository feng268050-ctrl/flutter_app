## ADDED Requirements

### Requirement: Simple HW prefs written by shell apply helpers

For backlight brightness, media volume, display orientation, and mouse settings, the preference files under `/var/lib/hmi/` SHALL be written by the corresponding verb-noun shell helpers (`change-backlight`, `change-volume`, `change-orientation`, `apply-mouse-settings`). Boot restore and `hmi-launch.sh` MUST continue to consume the same file paths. The HMI app MAY invoke those helpers but MUST NOT rely on Dart-only writes as the persistence path for these four prefs.

#### Scenario: Preference file updated only via helper contract

- **WHEN** brightness, volume, orientation, or mouse settings are changed from Demo or SSH
- **THEN** the matching shell helper performs the preference file update used by restore / launch
