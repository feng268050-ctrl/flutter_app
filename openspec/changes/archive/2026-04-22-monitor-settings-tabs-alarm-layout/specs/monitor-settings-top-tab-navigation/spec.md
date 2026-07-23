## ADDED Requirements

### Requirement: English tab titles use adequate horizontal space

The system SHALL allocate sufficient horizontal space for each top tab item on Monitor (`DeviceMonitoringActivity`) and Settings (`DeviceSettingActivity`) so that typical English tab titles render without clipping on a single line under the target tablet layout.

#### Scenario: Shared top tab styling

- **WHEN** the user views the Monitor or Settings screen with the shared `TopTabView`
- **THEN** tab item chrome (padding and/or minimum width as implemented in shared tab layouts or `TabLayout` attributes) SHALL be widened relative to the prior layout so common English strings (for example work/machine/alarm/videos and settings/network/screen/date/device sections) fit on one line without ellipsized truncation in the default English resources layout.

### Requirement: Tab behavior remains scrollable where needed

The top tab bar SHALL remain horizontally scrollable when the number of tabs exceeds the viewport width so that widening tabs does not break access to off-screen tabs.

#### Scenario: Settings with six tabs

- **WHEN** the user opens Settings with all six tabs configured
- **THEN** the user SHALL be able to scroll the tab bar horizontally to reach every tab, and each tab’s label SHALL remain readable per the adequate horizontal space requirement.
