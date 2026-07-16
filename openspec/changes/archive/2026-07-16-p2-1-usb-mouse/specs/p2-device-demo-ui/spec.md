## ADDED Requirements

### Requirement: Demo home includes USB mouse smoke and settings section

The P2/P2.1 demo home SHALL include a USB mouse section that: shows best-effort mouse presence/status; allows operators to verify that a **visible** pointer tracks the mouse; and exposes OS-common mouse setting controls (natural scroll, scroll speed, pointer speed, primary button) wired to `MouseSettingsController`. Mouse I/O and settings init MUST NOT block first-frame paint. On the demo home scroll order, the USB mouse section SHALL appear **immediately after** the USB keyboard section and **before** the Date & Time section.

#### Scenario: Section visible after first frame

- **WHEN** the user views the P2 demo home after first frame
- **THEN** the USB mouse section is visible with presence status and setting controls

#### Scenario: Pointer smoke

- **WHEN** a USB HID mouse is connected and the operator moves it
- **THEN** a visible pointer tracks on screen over the Demo UI

#### Scenario: Settings controls call controller

- **WHEN** the user toggles natural scroll or adjusts a speed slider in the mouse Demo section
- **THEN** the mouse settings controller is asked to persist and apply the new value

#### Scenario: Init failure non-fatal

- **WHEN** mouse presence detection or settings load fails
- **THEN** the Demo still paints and the section shows an unavailable / degraded status without crashing the app
