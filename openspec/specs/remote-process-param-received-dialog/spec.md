# remote-process-param-received-dialog Specification

## Purpose
TBD - created by archiving change remote-process-param-received-dialog. Update Purpose after archive.
## Requirements
### Requirement: Successful remote process parameter push shows confirmation dialog

After the device **successfully persists** an inbound WebSocket `command.send_process_param` payload via `ServerPushMessageHandler.saveProcessData`, the app SHALL enqueue and present a modal **`FrostedGlassDialog`** informing the operator that remote process parameters were received. The dialog MUST NOT appear when persistence fails, the payload is malformed, or the auto-dialog queue is gated (for example during boot self-check per existing `BootSelfCheckGate` rules).

#### Scenario: Dialog after successful persist

- **WHEN** a valid `command.send_process_param` payload is saved to the database without error
- **THEN** the app MUST enqueue a confirmation dialog on the main thread via `AutoDialogQueue`
- **AND** the WebSocket ack behavior MUST remain unchanged

#### Scenario: No dialog on failure

- **WHEN** `command.send_process_param` processing fails validation or persistence throws
- **THEN** the app MUST NOT show the received-parameter dialog
- **AND** MUST still send `command.send_process_param_ack` per existing envelope rules

### Requirement: Dialog uses OK-only FrostedGlass confirm action

The remote process-parameter received dialog SHALL use `FrostedGlassDialog` with **only a confirm action** visible in the action slot. The confirm button label MUST be **`OK`** (`@string/ok_text`). The cancel button MUST NOT be visible. Dismissing via OK or scrim tap (when enabled) MUST complete the auto-dialog queue task.

#### Scenario: OK-only action bar

- **WHEN** the remote process-parameter received dialog is visible
- **THEN** exactly one confirm button labeled OK MUST be shown
- **AND** no cancel button MUST be visible

#### Scenario: Dismiss completes queue task

- **WHEN** the operator taps OK or dismisses via scrim (if scrim dismiss is enabled)
- **THEN** the dialog MUST close
- **AND** the associated `AutoDialogQueue` task MUST invoke its completion callback

### Requirement: Dialog body lists process-type-specific parameter rows with units

The dialog body SHALL display a read-only scrollable list of parameter rows derived from the received `ProcessParametersData`. The **set of rows MUST match the visible Engineer Mode fields** for the row's `processType`:

- **Continuous welding** (`CONTINUOUS_WELDING`): welding-material panel fields excluding spot-welding-only rows (T1/T2 interval-duration).
- **Spot welding** (`POINT_WELDING`): welding-material panel fields appropriate to spot mode, including spot interval and duration where shown in Engineer Mode.
- **Weld clean / width clean** (`WELD_CLEAN`, `WIDTH_CLEAN`): wash/cleaning panel fields (material, laser power, swing frequency, swing width, delays, slow rise/descent, etc.).
- **Hand cut / CNC cut** (`HAND_CUT`, `CNC_CUT`): cutting panel fields (material, thickness, laser power, delays, slow rise/descent, etc.).

Each row MUST show a **localized label**, a **formatted value**, and a **unit suffix** when the corresponding Engineer Mode row displays a unit (for example `%`, `mm`/`in`, `Hz`, `ms`, `m/min`). Unit display MUST respect the device metric/imperial preference from `CommonSettings`, using the same formatting rules as Engineer Mode (`ProcessParameterDisplayFormat`, `InchMillimeterUtils`, and related converters). Rows without units in Engineer Mode MUST omit the unit column.

The parameter preset **name** MUST appear as a list row (not only in the dialog title).

#### Scenario: Continuous welding row set

- **WHEN** a received row has `processType` continuous welding
- **THEN** the dialog list MUST include welding thickness, laser power, swing frequency, and swing width with correct units
- **AND** MUST NOT include spot-welding interval/duration rows exclusive to point welding

#### Scenario: Spot welding row set

- **WHEN** a received row has `processType` point welding
- **THEN** the dialog list MUST include spot interval and spot duration rows with millisecond units
- **AND** MUST include shared welding fields shown in Engineer Mode for point welding

#### Scenario: Cleaning mode row set

- **WHEN** a received row has `processType` weld clean or width clean
- **THEN** the dialog list MUST include cleaning material, laser power, swing frequency, and swing width with units matching the wash Engineer Mode panel

#### Scenario: Cutting mode row set

- **WHEN** a received row has `processType` hand cut or CNC cut
- **THEN** the dialog list MUST include cutting thickness with mm/in unit per user preference
- **AND** MUST include cutting-specific delay rows shown in the cutting Engineer Mode panel

#### Scenario: Metric vs imperial thickness

- **WHEN** common settings use imperial units and the received row includes thickness or swing width
- **THEN** displayed values MUST use inch formatting consistent with Engineer Mode
- **AND** the unit suffix MUST show the inch unit string

### Requirement: Dialog body uses shared InsetList read-only binder

The read-only parameter list in the dialog body SHALL be rendered via a shared programmatic list component built on **`InsetList`**, **`InsetListRow`**, and **`InsetDivider`** (Settings list chrome). The component MUST accept a list of label/value/unit items and MUST NOT require feature-specific XML duplication for each row.

#### Scenario: Programmatic row binding

- **WHEN** the dialog is shown for any process type
- **THEN** rows MUST be added through the shared read-only list binder API
- **AND** dividers MUST appear between rows consistent with Settings list styling

#### Scenario: Scrollable body for long row sets

- **WHEN** the process-type row set exceeds the dialog body height
- **THEN** the list MUST scroll within the frosted-glass custom body
- **AND** MUST use the global vertical scrollbar baseline where applicable

### Requirement: Dialog title identifies process type

The dialog title SHALL indicate that a remote process parameter was received and MUST include the localized process-type name (same source as Engineer Mode / home process type labels).

#### Scenario: Title includes mode name

- **WHEN** the dialog is shown for a continuous welding parameter
- **THEN** the title MUST reference continuous welding using the localized process-type string

