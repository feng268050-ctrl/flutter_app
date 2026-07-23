## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Date and time row labels are concise in Chinese
When the app UI language is Chinese, the Date & Time group row labels for manual Date, Time, and Time Zone SHALL use concise nouns (`日期`, `时间`, `时区`) rather than prefixed forms such as `设置日期`.

#### Scenario: Chinese Date & Time labels omit setup prefix
- **WHEN** the user opens Common Settings with Chinese UI language
- **THEN** the Date row label reads `日期`
- **AND** the Time row label reads `时间`
- **AND** the Time Zone row label reads `时区`
