## ADDED Requirements

### Requirement: Backlight controller API is percent-based

The HMI SHALL provide a reusable `BacklightController` that gets and sets display brightness as an integer **percent in 0–100** (clamped). Callers MUST NOT depend on Android `Settings.System` brightness integers.

#### Scenario: Brightness clamp

- **WHEN** the client sets brightness to 120 or −5
- **THEN** the applied value is clamped to 100 or 0 respectively

### Requirement: Linux backend writes sysfs backlight

On Linux, the backlight implementation SHALL read/write a `/sys/class/backlight/*/brightness` node (auto-discovered when multiple exist), mapping percent to the device’s `max_brightness` scale. Get SHALL reflect the current sysfs value as percent.

#### Scenario: Set brightness changes panel

- **WHEN** the user sets brightness from a mid value to a distinctly lower percent on ynh960
- **THEN** the panel backlight visibly dims and a subsequent get returns approximately the requested percent

#### Scenario: Missing backlight node does not crash app

- **WHEN** no backlight sysfs node is available or write fails
- **THEN** the app remains running and set/get fail gracefully without an unhandled UI isolate error

### Requirement: Backlight init stays off the critical first-frame path

The app SHALL NOT block `runApp` / first frame on a successful backlight open or read.

#### Scenario: First frame without backlight ready

- **WHEN** the app starts before backlight sysfs is readable
- **THEN** the first home frame still renders; the brightness control may show a default until a later successful read
