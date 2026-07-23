# quick-mode-more-monitor-glass-cards Specification

## Purpose

Frosted-glass chrome for machine-status gauges/tiles in the Quick Mode More Monitor / Engineer gun work-status overlay. The overlay body is the shared Live Monitor (PR1 + detection boxes + gauges); this capability covers dialog-variant glass styling and More Monitor entry chrome.

## Requirements

### Requirement: More Monitor opens shared Live Monitor overlay body

The quick-mode **More Monitor** entry MUST open the shared Live Monitor overlay body (PR1 preview + detection boxes + compact gauges) rather than a gauges-only machine-status fragment. Confirm-bar / FrostButton dismiss behavior MUST remain. Dialog-variant frosted gauge and status-tile chrome requirements in this capability MUST continue to apply to Live Monitor gauges/tiles.

#### Scenario: More Monitor shows Live Monitor body

- **WHEN** the operator taps **More Monitor** on the quick-mode laser dashboard
- **THEN** the work-status dialog MUST host the Live Monitor overlay body
- **AND** the confirm dismiss control MUST remain available when `showButton=true`
- **AND** gauges/tiles MUST still satisfy dialog-variant frosted glass chrome

#### Scenario: Engineer gun auto popup shares Live Monitor body

- **WHEN** engineer mode auto-opens the work-status dialog without the confirm button
- **THEN** the dialog MUST host the same Live Monitor overlay body as More Monitor
- **AND** gauges MUST use the same dialog-variant frosted glass chrome

### Requirement: More Monitor dialog gauge panels use frosted glass with backdrop blur

The quick-mode **More Monitor** flow and the engineer-mode auto-popup that share the Live Monitor overlay body SHALL render circular gauge containers as `MachineStatusGaugeCard` with `machineStatusVariant="dialog"` and **frosted glass fill** (`cardBackground="frosted"`). Frosted fill MUST mean live backdrop blur sampling the dialog wallpaper via `BlurTarget`, not a solid dark `FrostedGlassPanelDrawable` alone when blur is active. This MUST differ from Monitor → Machine Status gauge cards (`machineStatusVariant="monitor"`, `cardBackground="transparent"`). Gauge dimensions, padding, `CircleProgressView` children, and Modbus data bindings MUST remain functionally unchanged.

#### Scenario: Quick mode opens More Monitor with blurred gauge cards

- **WHEN** the operator taps **More Monitor** on the quick-mode laser dashboard and the work-status dialog opens
- **THEN** both gauge containers MUST be `MachineStatusGaugeCard` with visible frosted blur
- **AND** gauge containers MUST NOT use `XUILinearLayout` with solid white background or legacy `@mipmap` chrome

#### Scenario: Engineer-mode auto popup shares blurred gauge cards

- **WHEN** engineer mode auto-opens the work-status dialog without the confirm button
- **THEN** the embedded gauge containers MUST use the same dialog-variant `MachineStatusGaugeCard` chrome as the quick-mode More Monitor dialog

### Requirement: More Monitor dialog status tiles use frosted glass with backdrop blur

Each Live Monitor status tile SHALL be a `MachineStatusStatusTile` with `machineStatusVariant="dialog"` and frosted dialog chrome. Tile dimensions, labels, and on/off semantics MUST remain unchanged. Active (on) state MAY tint the card fill; tiles MUST remain readable on the preview. Status MUST still reflect `DeviceStatus` bindings via `app:machineStatusChecked` (mapped to Success when on, Idle when off).

#### Scenario: Status tiles render with frosted dialog chrome

- **WHEN** the work-status Live Monitor overlay displays machine status tiles
- **THEN** each of the six status tiles MUST be a `MachineStatusStatusTile` with dialog-variant frosted chrome
- **AND** tiles MUST NOT use solid white `XUILinearLayout` backgrounds
- **AND** checked state MUST still reflect `DeviceStatus` bindings via `app:machineStatusChecked`

### Requirement: Monitor machine status reuses shared gauge and tile components

`fragment_machine_status.xml` SHALL use the same `MachineStatusGaugeCard` and `MachineStatusStatusTile` components with `machineStatusVariant="monitor"` and transparent card backgrounds. Monitor gauge/tile IDs, bindings, and Modbus behavior MUST remain unchanged.

#### Scenario: Monitor page uses monitor variant chrome

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** gauge and status tiles MUST use `machineStatusVariant="monitor"`
- **AND** cards MUST use `cardBackground="transparent"` (no frosted panel or blur stack fill)

### Requirement: Work status dialog provides BlurTarget for card blur

The work-status overlay host SHALL provide a blur sampling target so frosted cards can sample and blur the dialog wallpaper. Card content MUST remain a sibling above the target, not a child inside it.

#### Scenario: Cards blur dialog wallpaper not Activity content

- **WHEN** frosted machine-status cards render inside the work-status overlay
- **THEN** blur MUST sample the local dialog wallpaper target
- **AND** blur MUST NOT rely on cross-window fallback to the hosting Activity `android.R.id.content`

### Requirement: More Monitor actions use FrostButtonView

The quick-mode **More Monitor** entry control and the work-status dialog confirm action SHALL use `FrostButtonView` instead of legacy `Button` with `@drawable` / `@mipmap` backgrounds.

#### Scenario: More Monitor entry uses FrostButtonView

- **WHEN** the operator views the quick-mode laser progress dashboard
- **THEN** the **More Monitor** control MUST be a `FrostButtonView`

#### Scenario: Confirm dismiss uses FrostButtonView primary

- **WHEN** the work-status dialog is shown with the confirm button visible (`showButton=true`)
- **THEN** the **I understand** / confirm control MUST be a `FrostButtonView` with `primary` variant
- **AND** tapping it MUST dismiss the dialog as before

### Requirement: Overlay fragment removes legacy XUI radius and shadow chrome

Live Monitor / machine-status overlay fragments SHALL NOT apply `setRadiusAndShadow` to gauge or tile containers once shared frosted components own the chrome. Clip workarounds for gauge scale lines MUST be preserved when needed.

#### Scenario: No runtime shadow on glass cards

- **WHEN** the Live Monitor overlay initializes its view
- **THEN** it MUST NOT call `setRadiusAndShadow` on gauge or status tile containers

### Requirement: FrostedGlassCard backdrop blur infrastructure

`FrostedGlassCard` / `FrostCardView` with frosted fill SHALL attach blur when available. When blur is unavailable, the card MUST fall back to panel fill. Machine-status cards in the work-status overlay MUST NOT use stack panel fill that hides wallpaper-colored frosted blur.

#### Scenario: More monitor cards do not use stack panel fill

- **WHEN** machine-status gauge or tile cards render inside the work-status overlay
- **THEN** stack panel fill MUST remain off for those cards
- **AND** cards MUST show wallpaper-colored frosted blur rather than a solid gray panel block
