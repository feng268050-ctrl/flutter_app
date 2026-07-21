## ADDED Requirements

### Requirement: Keyboard page offers four-layout Segment and preview

Common Settings → Keyboard SHALL present a product layout chooser using `CyberSegmentedControl` for the four profiles (ANSI US, ISO DE, ISO FR, JIS JP) and a typewriter-block preview of the selection. The page MAY retain HID presence / smoke-test affordances as secondary content but MUST NOT rely solely on the Demo `KeyboardDemoSection` as the primary layout UX.

#### Scenario: Keyboard page shows Segment

- **WHEN** the operator opens Settings → Keyboard
- **THEN** a segmented control with the four product profiles is visible
- **AND** a layout preview for the selected profile is visible

### Requirement: Separate Apply and Restart actions

The Keyboard settings page SHALL provide distinct **Apply** and **Restart** actions after the operator changes the Segment selection. Apply MUST persist the selected profile for CyberIME and XKB preference without restarting HMI by itself. Restart MUST restart HMI so physical XKB takes effect and SHALL restore navigation to the Keyboard settings page after relaunch.

#### Scenario: Apply without restart

- **WHEN** the operator selects a different profile and taps Apply
- **THEN** the layout preference is persisted and CyberIME Keyboard A follows the new profile
- **AND** HMI is not restarted solely by Apply

#### Scenario: Restart applies physical XKB

- **WHEN** the operator taps Restart after Apply (or with a pending applied preference)
- **THEN** HMI restarts and, after relaunch, the App opens the Keyboard settings page
- **AND** physical key events follow the persisted XKB layout
