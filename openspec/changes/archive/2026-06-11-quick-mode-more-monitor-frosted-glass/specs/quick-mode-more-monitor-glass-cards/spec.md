## ADDED Requirements

### Requirement: More Monitor dialog gauge panels use frosted glass with backdrop blur

The quick-mode **More Monitor** flow (`WorkStatusDialog` with `MachineStatusDialogFragment` and `ARG_QUICK_MODE_MORE_MONITOR`) and the engineer-mode auto-popup that shares the same fragment layout SHALL render both circular gauge containers as `MachineStatusGaugeCard` with `machineStatusVariant="dialog"` and **frosted glass fill** (`cardBackground="frosted"`). Frosted fill MUST mean live backdrop blur sampling the dialog wallpaper via `BlurTarget`, not a solid dark `FrostedGlassPanelDrawable` alone when blur is active. This MUST differ from Monitor → Machine Status gauge cards (`machineStatusVariant="monitor"`, `cardBackground="transparent"`). Gauge dimensions, padding, `CircleProgressView` children, and Modbus data bindings MUST remain functionally unchanged.

#### Scenario: Quick mode opens More Monitor with blurred gauge cards

- **WHEN** the operator taps **More Monitor** on the quick-mode laser dashboard and the work-status dialog opens
- **THEN** both gauge containers MUST be `MachineStatusGaugeCard` with visible frosted blur over the yellow-white wallpaper
- **AND** the left gauge MUST use `borderGradientCenter="bottom-left-top-right"`
- **AND** the right gauge MUST use `borderGradientCenter="top-left-bottom-right"`
- **AND** gauge containers MUST NOT use `XUILinearLayout` with solid white background or legacy `@mipmap` chrome

#### Scenario: Engineer-mode auto popup shares blurred gauge cards

- **WHEN** engineer mode auto-opens the work-status dialog without the confirm button
- **THEN** the embedded gauge containers MUST use the same dialog-variant `MachineStatusGaugeCard` chrome as the quick-mode More Monitor dialog

### Requirement: More Monitor dialog status tiles use frosted glass with backdrop blur

Each status tile in `fragment_machine_status_dialog.xml` SHALL be a `MachineStatusStatusTile` with `machineStatusVariant="dialog"`, frosted backdrop blur, and `borderGradientCenter="top-left-bottom-right"`. Tile dimensions, labels, disabled checkbox bindings, and checked/unchecked semantics MUST remain unchanged. Label and checkbox styling MUST be readable on the light blurred wallpaper (black label text, `highlight_check_box`). Horizontal padding MUST be symmetric: label-to-left-edge distance MUST equal checkbox-to-right-edge distance (`frosted_glass_content_padding`).

#### Scenario: Status tiles render with frosted blur chrome

- **WHEN** the work-status dialog displays machine status tiles
- **THEN** each of the six status tiles MUST be a `MachineStatusStatusTile` with dialog-variant frosted blur
- **AND** tiles MUST NOT use solid white `XUILinearLayout` backgrounds
- **AND** checkbox checked state MUST still reflect `DeviceStatus` bindings via `app:machineStatusChecked`

### Requirement: Monitor machine status reuses shared gauge and tile components

`fragment_machine_status.xml` SHALL use the same `MachineStatusGaugeCard` and `MachineStatusStatusTile` components with `machineStatusVariant="monitor"` and transparent card backgrounds. Monitor gauge/tile IDs, bindings, and Modbus behavior MUST remain unchanged.

#### Scenario: Monitor page uses monitor variant chrome

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** gauge and status tiles MUST use `machineStatusVariant="monitor"`
- **AND** cards MUST use `cardBackground="transparent"` (no frosted panel or blur stack fill)
- **AND** labels MUST remain white with `check_box_warn_show` on the dark monitor background

### Requirement: Work status dialog provides BlurTarget for card blur

`work_status_dialog.xml` SHALL wrap the yellow-white wallpaper layer in a `BlurTarget` (`@+id/frosted_glass_blur_target`) so frosted cards in the same dialog window can sample and blur that backdrop. Card content MUST remain a sibling above the target, not a child inside it.

#### Scenario: Cards blur dialog wallpaper not Activity content

- **WHEN** frosted machine-status cards render inside `WorkStatusDialog`
- **THEN** blur MUST sample the local `frosted_glass_blur_target` wallpaper in the dialog window
- **AND** blur MUST NOT rely on cross-window fallback to the hosting Activity `android.R.id.content`

### Requirement: More Monitor actions use FrostedGlassButton

The quick-mode **More Monitor** entry control and the work-status dialog confirm action SHALL use `FrostedGlassButton` instead of legacy `Button` with `@drawable` / `@mipmap` backgrounds.

#### Scenario: More Monitor entry uses FrostedGlassButton

- **WHEN** the operator views the quick-mode laser progress dashboard
- **THEN** the **More Monitor** control MUST be a `FrostedGlassButton`
- **AND** it MUST NOT use `pressure_monitoring_btn_green`, `pressure_monitoring_btn_blue`, or `pressure_monitoring_btn_orange` backgrounds

#### Scenario: Confirm dismiss uses FrostedGlassButton primary

- **WHEN** the work-status dialog is shown with the confirm button visible (`showButton=true`)
- **THEN** the **I understand** / confirm control MUST be a `FrostedGlassButton` with `primary` variant
- **AND** tapping it MUST dismiss the dialog as before

### Requirement: Dialog fragment removes legacy XUI radius and shadow chrome

`MachineStatusDialogFragment` SHALL NOT apply `setRadiusAndShadow` to gauge or tile containers once shared frosted components own the chrome. The quick-mode More Monitor clip workaround (`setClipChildren(false)` on gauge ancestors when `ARG_QUICK_MODE_MORE_MONITOR` is true) MUST be preserved so gauge scale lines are not clipped.

#### Scenario: No runtime shadow on glass cards

- **WHEN** `MachineStatusDialogFragment` initializes its view
- **THEN** it MUST NOT call `setRadiusAndShadow` on gauge or status tile containers
- **AND** frosted card border and corner radius MUST come from `FrostedGlassCard` only

#### Scenario: Quick mode gauge clipping workaround retained

- **WHEN** the fragment is created with `ARG_QUICK_MODE_MORE_MONITOR=true`
- **THEN** gauge row and container clip flags MUST still be relaxed to prevent `CircleProgressView` scale clipping

### Requirement: FrostedGlassCard backdrop blur infrastructure

`FrostedGlassCard` with `cardBackground="frosted"` SHALL attach an internal `BlurView` via shared `FrostedGlassBlurSupport` when not already inside a parent `BlurView`. When blur is active and `frostedGlassStackPanelFill` is false (default), the card MUST NOT stack `FrostedGlassPanelDrawable` on the content container. When blur is unavailable, the card MUST fall back to `FrostedGlassPanelDrawable`. Card padding MUST migrate to the content container when blur is active so the blur layer covers the full rounded card.

#### Scenario: Standalone frosted card blurs without gray panel stack

- **WHEN** a `FrostedGlassCard` with frosted fill and default `frostedGlassStackPanelFill` renders over a light backdrop with blur enabled
- **THEN** the visible fill MUST come from blur and overlay tint
- **AND** a dark `FrostedGlassPanelDrawable` fill MUST NOT be drawn on top of the blur

### Requirement: FrostedGlassDialog prompt uses stack panel fill only

`dialog_frosted_glass_prompt.xml` SHALL use a single root `FrostedGlassCard` (no outer `BlurView` wrapper) with `frostedGlassStackPanelFill="true"` so prompt dialogs match pre-refactor blur + panel concentration. Machine-status cards in `WorkStatusDialog` MUST NOT set `frostedGlassStackPanelFill`.

#### Scenario: Boot self-check prompt retains legacy glass density

- **WHEN** a `FrostedGlassDialog` prompt (e.g. boot self-check) is shown over the Activity
- **THEN** the root `FrostedGlassCard` MUST use `frostedGlassStackPanelFill="true"`
- **AND** there MUST NOT be a separate outer `BlurView` wrapping the same card

#### Scenario: More monitor cards do not use stack panel fill

- **WHEN** machine-status gauge or tile cards render inside the work-status dialog
- **THEN** `frostedGlassStackPanelFill` MUST remain false
- **AND** cards MUST show wallpaper-colored frosted blur rather than a solid gray panel block
