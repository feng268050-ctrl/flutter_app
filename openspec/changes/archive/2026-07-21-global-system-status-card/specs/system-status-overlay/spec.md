## ADDED Requirements

### Requirement: Global system status card overlay

When the Show System Status Overlay preference is enabled, the Flutter HMI app SHALL present a global system status card overlay on product routes (at least Home, Settings, and Monitor). The card SHALL be positioned on the left side of the screen and vertically centered. The overlay MUST NOT capture pointer events (taps SHALL pass through to underlying UI). Missing metric values SHALL display a placeholder such as `--` rather than crashing or omitting the row structure inconsistently. When the preference is disabled (the default), the overlay MUST NOT be shown.

#### Scenario: Card hidden by default

- **WHEN** the app starts with no prior Show System Status Overlay preference (or preference is false)
- **THEN** the system status card is not visible on Home, Settings, or Monitor

#### Scenario: Card visible when enabled

- **WHEN** the operator has enabled Show System Status Overlay
- **AND** the user views the product Home route
- **THEN** a system status card is visible on the left side of the screen, vertically centered

#### Scenario: Card remains after navigation when enabled

- **WHEN** Show System Status Overlay is enabled
- **AND** the user navigates from Home to Settings or Monitor
- **THEN** the same style of system status card remains visible on the left side (not limited to the Home route)

#### Scenario: Overlay does not block taps

- **WHEN** Show System Status Overlay is enabled
- **AND** the user taps a control that lies under or beside the status card region
- **THEN** the underlying control still receives the tap (the status card does not absorb pointer events)

#### Scenario: Disabling hides the card immediately

- **WHEN** the operator turns Show System Status Overlay off
- **THEN** the system status card is no longer visible without requiring an app restart

### Requirement: Status card shows one metric per row

When the overlay is shown, the system status card SHALL list host metrics with one metric per row (label and value). The card SHALL include at least: UI FPS, raster FPS, panel refresh rate, SoC temperature, GPU temperature, memory, CPU load, and system uptime. Values SHALL be sourced from the existing `SysInfo` / `SysInfoSnapshot` path (or equivalent AppServices sysInfo), not from Modbus. Temperature I/O and sysInfo sampling MUST NOT block the app’s first-frame paint. While the overlay is disabled, the App SHOULD NOT keep a dedicated status-card `SysInfo.watch` subscription running solely for this UI.

#### Scenario: Former Home HUD metrics appear as rows

- **WHEN** Show System Status Overlay is enabled
- **AND** sysInfo has populated FPS and SoC/GPU thermal samples
- **THEN** the card shows separate rows for UI FPS, raster FPS, panel refresh, SoC temperature, and GPU temperature (not a single pipe-separated line)

#### Scenario: Extended host metrics appear as rows

- **WHEN** Show System Status Overlay is enabled
- **AND** sysInfo has populated memory, load average, and uptime
- **THEN** the card shows separate rows for memory, CPU load, and system uptime

#### Scenario: Unavailable metrics show placeholders

- **WHEN** Show System Status Overlay is enabled
- **AND** a metric field is null or unavailable
- **THEN** that row still appears with a `--` (or equivalent) placeholder value

### Requirement: Overlay visibility preference defaults off and is persisted

The Show System Status Overlay preference SHALL default to disabled when `/var/lib/hmi/misc-settings.json` is absent or the overlay key is missing. Enabling or disabling the preference SHALL persist in `/var/lib/hmi/misc-settings.json` (unified Common Settings → Misc JSON store) so a subsequent process start restores the same visibility. The App MUST NOT use a separate dedicated overlay preference file under `/var/lib/hmi/`.

#### Scenario: Fresh install stays hidden

- **WHEN** `misc-settings.json` is absent or the overlay key is missing
- **THEN** the overlay remains hidden until the operator enables it

#### Scenario: Preference survives restart

- **WHEN** the operator enables Show System Status Overlay and the app process restarts
- **THEN** the overlay is shown again without re-toggling the switch
- **AND** the value is present in `/var/lib/hmi/misc-settings.json`
