## Purpose

Define the shared Monitor and Settings top tab bar (`TopTabView`): equal tab widths, centered strip when space allows, horizontal scrolling when needed, and English-first readability at the tablet target resolution.
## Requirements
### Requirement: Equal-width tab cells

Each top tab item on Monitor (`DeviceMonitoringActivity`) and Settings (`DeviceSettingActivity`) SHALL use the same fixed horizontal width (`@dimen/top_tab_item_width`), implemented via the shared `tab_item_layout` custom view and `TopTabView` minimum width alignment with `TabLayout`’s `tabMinWidth`.

#### Scenario: Consistent tab width

- **WHEN** the user views the Monitor or Settings screen with multiple top tabs visible
- **THEN** every tab cell SHALL measure to the same width dimension, independent of individual label length.

### Requirement: Centered tab strip and in-tab content

The `TabLayout` SHALL use `tabGravity` such that the tab strip is centered when the combined tab width fits the bar. Each tab’s icon and label cluster SHALL be centered within the tab cell (`FrameLayout` + inner `LinearLayout` with `layout_gravity="center"`).

#### Scenario: Visual alignment

- **WHEN** the tab bar is laid out on a target-width device
- **THEN** the tab group SHALL be centered when it fits the parent width, and icon plus title SHALL appear centered as a block inside each equal-width tab.

### Requirement: Scrollable access and overflow text
The top tab bar SHALL remain horizontally scrollable when tabs exceed the viewport. Labels longer than the text area within a tab MAY ellipsize at the end (`ellipsize="end"`) while remaining single-line.

#### Scenario: Four settings tabs
- **WHEN** the user opens Settings with the refactored four tabs configured
- **THEN** the user SHALL be able to access Device Information, Common Settings, Advanced Settings, and Custom Home Page
- **AND** the tab bar SHALL remain horizontally scrollable if the four labels exceed the viewport

#### Scenario: Monitor tabs remain accessible
- **WHEN** the user opens Monitor with its configured tabs
- **THEN** the user SHALL be able to scroll the tab bar horizontally when tabs exceed the viewport

### Requirement: Settings tab order follows Settings structure
The shared Settings top tab bar SHALL render the Settings tabs in the order required by the Settings page structure capability.

#### Scenario: Settings tab order
- **WHEN** the user opens Settings
- **THEN** the first tab is Device Information
- **AND** the second tab is Common Settings
- **AND** the third tab is Advanced Settings
- **AND** the fourth tab is Custom Home Page

