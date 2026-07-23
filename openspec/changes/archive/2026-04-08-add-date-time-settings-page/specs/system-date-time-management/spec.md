## ADDED Requirements

### Requirement: Date & Time entry placement in Settings
The system SHALL show a `Date & Time` settings entry in the Settings menu immediately after `Screen Settings`, while preserving existing navigation behavior for other entries.

#### Scenario: Entry appears after Screen Settings
- **WHEN** the user opens the Settings menu
- **THEN** `Date & Time` is displayed after `Screen Settings`
- **AND** selecting it navigates to the Date & Time management page

### Requirement: Automatic date and time synchronization control
The Date & Time page SHALL provide an `Automatic date & time` toggle backed by system auto-time configuration, and SHALL use network-based platform time synchronization when enabled and network connectivity is available.

#### Scenario: Enable automatic date and time
- **WHEN** the user turns on `Automatic date & time` and the device is online
- **THEN** the system enables auto-time mode using platform configuration
- **AND** manual date/time controls are disabled
- **AND** displayed date/time updates to system values

#### Scenario: Auto date and time enabled while offline
- **WHEN** `Automatic date & time` is enabled but network synchronization source is currently unavailable
- **THEN** the page keeps auto mode enabled
- **AND** the UI shows a non-blocking status indicating time sync is currently unavailable

### Requirement: Automatic timezone synchronization control
The Date & Time page SHALL provide an `Automatic time zone` toggle backed by system auto-timezone configuration, and SHALL use network/platform timezone detection when enabled.

#### Scenario: Enable automatic timezone
- **WHEN** the user turns on `Automatic time zone`
- **THEN** the system enables auto-timezone mode using platform configuration
- **AND** manual timezone selection control is disabled

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
