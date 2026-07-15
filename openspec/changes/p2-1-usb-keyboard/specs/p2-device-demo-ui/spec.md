## ADDED Requirements

### Requirement: Demo home includes USB keyboard smoke section

The P2/P2.1 demo home SHALL include a USB keyboard smoke section that: shows best-effort keyboard presence/status; provides a focusable text field for typing verification; and notes that this is hardware HID bring-up via the **1 mm USB host expansion** (not product soft IME; not the on-board Micro-USB OTG plug-ssh jack). Keyboard I/O MUST NOT block first-frame paint.

#### Scenario: Section visible after first frame

- **WHEN** the user views the P2 demo home after first frame
- **THEN** the USB keyboard smoke section is visible with a text field that can receive focus

#### Scenario: Typing smoke

- **WHEN** a USB HID keyboard is connected via the 1 mm host expansion and the Demo text field has focus
- **THEN** characters typed on the keyboard appear in the field

#### Scenario: Init failure non-fatal

- **WHEN** keyboard presence detection fails or no keyboard is attached
- **THEN** the Demo still paints and the section shows an unavailable / not-detected status without crashing the app
