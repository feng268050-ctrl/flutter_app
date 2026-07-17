## ADDED Requirements

### Requirement: Abstract date/time controller with live system fields

The system SHALL provide a reusable Dart `DateTimeController` abstraction for reading/writing local date-time, timezone preference, and time-sync mode (manual vs network) used by Demo and later Settings. Wall-clock **display ticking** MAY use a UI timer reading the system clock; that MUST NOT be confused with OS discovery polling.

#### Scenario: Timezone preference readable after set

- **WHEN** the controller applies a timezone preference successfully
- **THEN** a subsequent get returns that timezone token

### Requirement: System timezone changes are observable without CLI poll loops

When `org.freedesktop.timedate1` (or equivalent) is available on the image, Linux SHALL observe Timezone (and NTP-related properties when used) via **D-Bus PropertiesChanged** (or equivalent subscription). Periodic `timedatectl` Process status on a fixed Timer MUST NOT be the primary way the HMI discovers timezone changes made outside the app. Project prefs under `/var/lib/hmi/` for sync-mode MAY use file watches when helpers rewrite them.

#### Scenario: External timezone change visible to listeners

- **WHEN** timezone is changed via `timedatectl set-timezone` (or timedate1) while a listener is subscribed
- **THEN** the controller notifies listeners of the new timezone without a Demo re-open
