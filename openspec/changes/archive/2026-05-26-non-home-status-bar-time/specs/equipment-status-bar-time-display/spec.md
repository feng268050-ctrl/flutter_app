## ADDED Requirements

### Requirement: Compact time beside WiFi on EquipmentStatusBar
The system SHALL display the current local system time in `EquipmentStatusBar`, positioned immediately to the right of the WiFi status icon group (`wifi_content`), on every screen that uses `EquipmentStatusBar`.

#### Scenario: Time visible on non-home screen with status bar
- **WHEN** the user opens any activity that embeds `EquipmentStatusBar` (e.g. Monitor, Settings, Engineer Mode, Quick Mode, WiFi settings)
- **THEN** a time label is shown to the right of the WiFi connected/disconnected icon
- **AND** the label does not overlap or replace the WiFi or remote-lock icons

#### Scenario: Time not shown on home dashboard
- **WHEN** the user is on `MainActivity` (home dashboard)
- **THEN** the compact status-bar time is not shown
- **AND** only the existing home dashboard clock (`home_real_time`) presents time on that screen

### Requirement: Time format and locale
The status-bar time label SHALL use device local time formatted as hours and minutes (`HH:mm` pattern) according to `Locale.getDefault()`, consistent with the home dashboard minute display.

#### Scenario: Locale-appropriate formatting
- **WHEN** the status bar time label is rendered
- **THEN** it reflects the device's current locale for hour/minute presentation
- **AND** it updates when the formatted minute changes

### Requirement: Live refresh while status bar is visible
The status-bar time label SHALL refresh at least once per second while `EquipmentStatusBar` is attached to the window, using device system time as the source of truth.

#### Scenario: Clock ticks on screen
- **WHEN** the user remains on a screen with `EquipmentStatusBar` across a minute boundary
- **THEN** the displayed time updates to the new minute without leaving the screen

#### Scenario: No updates after detach
- **WHEN** `EquipmentStatusBar` is detached from the window (activity finished or view removed)
- **THEN** the component stops scheduling time UI updates
- **AND** no memory leaks or stale callbacks remain registered

### Requirement: Display-only time next to WiFi
The status-bar time label SHALL be read-only and SHALL NOT alter existing WiFi or remote-lock click targets or connectivity indicators.

#### Scenario: WiFi row interaction unchanged
- **WHEN** the user taps the WiFi status area
- **THEN** existing WiFi row behavior is unchanged from pre-change behavior
- **AND** tapping the time label does not open date/time settings

### Requirement: Visual consistency with status bar
The status-bar time label SHALL use typography and colors consistent with existing `EquipmentStatusBar` status text (light foreground on dark bar, size appropriate for ~70dp bar height).

#### Scenario: Readable on dark status bar
- **WHEN** the status bar is shown on standard app backgrounds
- **THEN** the time text is legible beside 30dp WiFi icons without dominating the title or status icon row
