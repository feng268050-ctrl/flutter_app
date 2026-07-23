## ADDED Requirements

### Requirement: Status bar clock follows system time changes
The `EquipmentStatusBar` compact time label SHALL use device system time as its source of truth, and SHALL reflect manual or automatic date/time/timezone changes made in Date & Time settings without requiring app restart.

#### Scenario: Manual time change reflected on status bar
- **WHEN** a user manually updates system date/time in Date & Time settings
- **THEN** returning to any screen with `EquipmentStatusBar` shows the updated time
- **AND** the label continues to refresh from system time

#### Scenario: Timezone change reflected on status bar
- **WHEN** a user changes system timezone in Date & Time settings
- **THEN** the status-bar time updates to the new timezone's local time on the next refresh cycle

#### Scenario: Home and status bar stay aligned
- **WHEN** system time changes while the app is running
- **THEN** the home dashboard clock and the status-bar time label both reflect the same underlying system instant (subject to respective display formats)
