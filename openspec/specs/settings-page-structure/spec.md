# settings-page-structure Specification

## Purpose
TBD - created by archiving change refactor-welder-app-settings-page. Update Purpose after archive.
## Requirements
### Requirement: Settings exposes four top-level tabs
The Settings screen SHALL expose exactly these top-level tabs in this order: Device Information, Common Settings, Advanced Settings, and Custom Home Page. The status-bar title and selected page MUST follow the selected tab label.

#### Scenario: User opens Settings
- **WHEN** the user opens the Settings screen
- **THEN** the top tab bar lists Device Information first, Common Settings second, Advanced Settings third, and Custom Home Page fourth
- **AND** no legacy top-level Network Settings, Screen Settings, Date & Time, or Custom Layout tabs are shown

#### Scenario: User selects a tab
- **WHEN** the user selects any Settings tab
- **THEN** the visible page changes to the selected section
- **AND** the status-bar title displays the selected section name

### Requirement: Settings chrome uses FrostedGlass components
Settings cards and action buttons SHALL use reusable frost components. Card-like containers MUST use `FrostCardView`, and button-like actions MUST use `FrostButtonView` instead of image-resource-backed background assets.

#### Scenario: Settings card renders
- **WHEN** a Settings page displays a grouped card or row container
- **THEN** the container uses `FrostCardView` for its visual chrome
- **AND** it does not depend on legacy image backgrounds such as `net_work_border*`

#### Scenario: Settings action renders
- **WHEN** a Settings page displays an action button
- **THEN** the action uses `FrostButtonView`
- **AND** existing click behavior remains unchanged

#### Scenario: Zero Offset Auto button uses left-right gradient
- **WHEN** the user opens Advanced Settings
- **THEN** the Zero Offset `Auto` action uses `FrostButtonView` with `borderGradientCenter="left-right"`

### Requirement: Device Information is grouped without titles
Device Information SHALL preserve the current information items but display them in untitled visual groups. The first group MUST contain Machine Model, Device SN, and Gunhead SN. The second group MUST contain System Version, Process Library Version, and other version rows. The third group MUST contain Focus Scale Reference.

#### Scenario: Device Information groups identity rows
- **WHEN** the user opens Device Information
- **THEN** Machine Model, Device SN, and Gunhead SN appear together in the first untitled group

#### Scenario: Device Information groups version rows
- **WHEN** the user opens Device Information
- **THEN** System Version, Process Library Version, and other version rows appear together in the second untitled group

#### Scenario: Device Information groups focus reference
- **WHEN** the user opens Device Information
- **THEN** Focus Scale Reference appears in the third untitled group

### Requirement: Common Settings is grouped by operator concern
Common Settings SHALL display the requested operator/system controls in titled groups: Network, Display & Sound, Date & Time, and Misc.

#### Scenario: Common Settings groups rows
- **WHEN** the user opens Common Settings
- **THEN** Network contains Wireless Network and HTTP Proxy
- **AND** Display & Sound contains Language, Unit, Screen Brightness, Screen-off Time, and Sound Effect
- **AND** Date & Time contains Automatic, Date, Time, and Time Zone
- **AND** Misc contains Show Startup Self-Check

### Requirement: Advanced Settings is grouped by parameter concern

Advanced Settings SHALL display device parameters in titled groups: Offset & Correction, Power Thresholds, Temperature Thresholds, AI Assistance, and Dangerous Operations.

#### Scenario: Advanced Settings groups rows

- **WHEN** the user opens Advanced Settings
- **THEN** Offset & Correction contains Zero Offset and Scan Width Correction
- **AND** Power Thresholds contains Laser Starting Power, Laser Termination Power, and Minimum Gas Pressure Threshold
- **AND** Temperature Thresholds contains Motor Temperature Alarm Threshold, Driver Temperature Alarm Threshold, Protective Lens Temperature Alarm Threshold, Collimating Lens Temperature Alarm Threshold, and Temperature Alarm Recovery Interval
- **AND** AI Assistance contains Lens Contamination Detection and Zero Point Offset Detection toggle switches
- **AND** Dangerous Operations contains Keep Laser On while Alarmed first, then Allow Work after Camera Alarm, Allow Work after Gas Alarm, Allow Work after Lens Contamination, and Allow Work after Feeder Alarm toggle switches
- **AND** each Dangerous Operations switch displays a localized hint line below its title

### Requirement: Custom Layout is renamed Custom Home Page
The existing Custom Layout settings page SHALL be presented as Custom Home Page while preserving its current behavior and data model.

#### Scenario: User opens Custom Home Page
- **WHEN** the user selects Custom Home Page
- **THEN** the app shows the existing custom home layout configuration experience
- **AND** existing saved custom layout data remains available

