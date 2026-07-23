## MODIFIED Requirements

### Requirement: More Monitor dialog status tiles use frosted glass with backdrop blur

Each status tile in `fragment_machine_status_dialog.xml` SHALL be a `MachineStatusStatusTile` with `machineStatusVariant="dialog"`, frosted backdrop blur, and `borderGradientCenter="top-left-bottom-right"`. Tile dimensions, labels, disabled status bindings, and on/off semantics MUST remain unchanged. Label and status indicator styling MUST be readable on the light blurred wallpaper (black label text, `FrostStatusIndicatorView` with **Dot** variant). Horizontal padding MUST be symmetric: label-to-left-edge distance MUST equal indicator-to-right-edge distance (`frosted_glass_content_padding`).

#### Scenario: Status tiles render with frosted blur chrome

- **WHEN** the work-status dialog displays machine status tiles
- **THEN** each of the six status tiles MUST be a `MachineStatusStatusTile` with dialog-variant frosted blur
- **AND** tiles MUST NOT use solid white `XUILinearLayout` backgrounds
- **AND** indicator state MUST still reflect `DeviceStatus` bindings via `app:machineStatusChecked` (mapped to Success when on, Idle when off)

### Requirement: Monitor machine status reuses shared gauge and tile components

`fragment_machine_status.xml` SHALL use the same `MachineStatusGaugeCard` and `MachineStatusStatusTile` components with `machineStatusVariant="monitor"` and transparent card backgrounds. Monitor gauge/tile IDs, bindings, and Modbus behavior MUST remain unchanged.

#### Scenario: Monitor page uses monitor variant chrome

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** gauge and status tiles MUST use `machineStatusVariant="monitor"`
- **AND** cards MUST use `cardBackground="transparent"` (no frosted panel or blur stack fill)
- **AND** labels MUST remain white with `FrostStatusIndicatorView` (**Dot** variant) on the dark monitor background
