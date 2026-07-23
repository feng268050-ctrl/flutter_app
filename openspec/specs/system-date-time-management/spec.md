## Purpose

Define expected behavior for the Settings Date & Time management experience, including entry placement, automatic/manual control semantics, and home clock consistency with system time changes.
## Requirements
### Requirement: Date & Time entry placement in Settings
The system SHALL show Date & Time controls inside Common Settings under the titled `Date & Time` group, while preserving existing date, time, timezone picker behavior for those rows.

#### Scenario: Entry appears in Common Settings
- **WHEN** the user opens Common Settings
- **THEN** Date & Time controls are displayed in the Date & Time group
- **AND** the Date & Time group contains Automatic, Date, Time, and Time Zone

### Requirement: Automatic date and time synchronization control
The Date & Time group SHALL provide a single `Automatic` toggle backed by both system auto-time and system auto-timezone configuration. When enabled, the app SHALL enable platform automatic date/time and automatic timezone behavior; when disabled, the app SHALL disable both automatic controls so manual Date, Time, and Time Zone rows are available.

#### Scenario: Enable automatic date and time
- **WHEN** the user turns on `Automatic` and the device is online
- **THEN** the system enables auto-time mode using platform configuration
- **AND** the system enables auto-timezone mode using platform configuration
- **AND** manual date, time, and timezone controls are disabled
- **AND** displayed date, time, and timezone update to system values

#### Scenario: Automatic enabled while offline
- **WHEN** `Automatic` is enabled but network synchronization source is currently unavailable
- **THEN** the page keeps automatic mode enabled
- **AND** the UI shows a non-blocking status indicating time sync is currently unavailable

#### Scenario: Disable automatic date and time
- **WHEN** the user turns off `Automatic`
- **THEN** the system disables auto-time mode using platform configuration
- **AND** the system disables auto-timezone mode using platform configuration
- **AND** manual Date, Time, and Time Zone rows become available

### Requirement: Automatic timezone synchronization control
The Date & Time group SHALL NOT expose a separate `Automatic time zone` toggle. Timezone automatic behavior MUST be controlled by the combined `Automatic` row.

#### Scenario: Combined automatic controls timezone
- **WHEN** the user turns on `Automatic`
- **THEN** the system enables automatic timezone mode using platform configuration
- **AND** manual timezone selection control is disabled

#### Scenario: Combined automatic disabled controls timezone
- **WHEN** the user turns off `Automatic`
- **THEN** the system disables automatic timezone mode using platform configuration
- **AND** manual timezone selection control is enabled

### Requirement: Manual date and time setting
When automatic date & time is disabled, the system SHALL allow the user to set date and time manually using standard Android picker interactions and SHALL validate the selected values before applying.

#### Scenario: Manually set valid date and time
- **WHEN** `Automatic date & time` is off and the user confirms valid date/time values
- **THEN** the system applies the selected date/time to the device clock
- **AND** the page reflects the updated values

#### Scenario: Reject invalid manual date/time input
- **WHEN** manual date/time input is invalid or cannot be applied by platform constraints
- **THEN** the system does not change current device time
- **AND** the UI shows a clear validation or error message

### Requirement: Manual timezone setting
When automatic timezone is disabled, the system SHALL allow manual timezone selection and SHALL apply the selected timezone through system APIs with privilege-aware error handling.

#### Scenario: Manually set valid timezone
- **WHEN** `Automatic time zone` is off and the user selects a valid timezone
- **THEN** the system applies the timezone successfully
- **AND** the page displays the newly selected timezone

#### Scenario: Manual timezone apply fails
- **WHEN** the user selects a timezone but the platform rejects the operation
- **THEN** the system retains the previous timezone
- **AND** the UI informs the user that timezone update failed

### Requirement: Date & Time page style consistency
The Date & Time page SHALL follow the app's existing Settings visual and interaction style, including list row pattern, switch control style, spacing, typography hierarchy, and navigation affordances.

#### Scenario: Page follows current settings style tokens
- **WHEN** the Date & Time page is rendered
- **THEN** its components and interaction behavior are consistent with existing Settings pages in the app

### Requirement: Home clock follows system time changes
The home page real-time clock SHALL use device system time as its source of truth, and SHALL reflect manual or automatic date/time/timezone changes made in Date & Time settings without requiring app restart.

#### Scenario: Manual time change is reflected on home clock
- **WHEN** a user manually updates system date/time in Date & Time settings
- **THEN** returning to home shows the updated time
- **AND** the home clock refreshes from system time continuously

#### Scenario: Timezone change is reflected on home clock formatting
- **WHEN** a user changes system timezone in Date & Time settings
- **THEN** the home clock updates to the new timezone's local time on next refresh cycle

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

### Requirement: Date and time pickers use FrostedGlassDialog shell

Manual date, time, and timezone picker dialogs in the Date & Time settings page SHALL use `FrostedGlassDialog` with picker content in the custom body slot. Automatic/manual toggle behavior and system apply semantics MUST NOT change.

#### Scenario: Date picker overlay

- **WHEN** the user opens manual date selection with automatic date & time disabled
- **THEN** the picker MUST appear inside `FrostedGlassDialog`
- **AND** cancel dismisses without changing system date

#### Scenario: Time picker overlay

- **WHEN** the user opens manual time selection with automatic date & time disabled
- **THEN** hour and minute pickers MUST render in a frosted-glass custom body
- **AND** confirm applies time through existing `SystemSettingUtils` paths

#### Scenario: Timezone picker overlay

- **WHEN** the user opens manual timezone selection with automatic time zone disabled
- **THEN** search and list UI MUST render in a frosted-glass custom body
- **AND** soft-keyboard/window behavior MUST remain usable on device hardware

### Requirement: Date and time row labels are concise in Chinese
When the app UI language is Chinese, the Date & Time group row labels for manual Date, Time, and Time Zone SHALL use concise nouns (`日期`, `时间`, `时区`) rather than prefixed forms such as `设置日期`.

#### Scenario: Chinese Date & Time labels omit setup prefix
- **WHEN** the user opens Common Settings with Chinese UI language
- **THEN** the Date row label reads `日期`
- **AND** the Time row label reads `时间`
- **AND** the Time Zone row label reads `时区`

