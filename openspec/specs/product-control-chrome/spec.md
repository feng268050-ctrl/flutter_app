# product-control-chrome Specification

## Purpose
Product HMI control chrome: CyberCheckbox / CyberSwitch / HmiButton / TipDialogHost / CyberIME on operator surfaces (boot self-check, Engineer Mode, Process Library, IP Camera Settings, Wi‑Fi list, and related tips), so production call sites do not regress to Material stand-ins or ad-hoc sizes.

## Requirements

### Requirement: Product checkbox face is CyberCheckbox at large size

On product HMI surfaces (boot self-check footer, Engineer Mode entry tip, Laser Enable reminder, Settings rows, Engineer device panel, Record Work, Safety Tips, and any other production “don’t show again” / boolean checkbox), the App SHALL use `CyberCheckbox` with face size `CyberDimens.checkboxLargeSize` (28 logical px). The App MUST NOT use Material `Checkbox` for those roles and MUST NOT pass ad-hoc face sizes (including 38) on product call sites.

#### Scenario: Boot self-check footer checkbox

- **WHEN** the boot self-check dialog shows its footer “don’t show again” control
- **THEN** the control is a `CyberCheckbox` at size 28

#### Scenario: Cream tip dialogs use CyberCheckbox

- **WHEN** Engineer Mode entry tip or Laser Enable reminder shows “don’t show again this session”
- **THEN** the control is a `CyberCheckbox` at size 28 (light prompt host MAY remain cream frost)

### Requirement: Product process switch uses CyberSwitch

Engineer/Quick device control manual-gas (or equivalent boolean process switch previously implemented with Material `SwitchListTile`) SHALL use `CyberSwitch` rather than Material `Switch` / `SwitchListTile` alone.

#### Scenario: Manual gas toggle

- **WHEN** the operator toggles manual gas on the process device control bar
- **THEN** the control is a `CyberSwitch` (or CyberSwitch embedded in the existing row)

### Requirement: Product library and camera CTAs use HmiButton and TipDialogHost

Process Library confirm/edit dialogs and IP Camera Settings primary action buttons SHALL use `HmiButton`. Confirm/cancel shells SHALL use `TipDialogHost` (or the product’s shared Hmi dialog action pattern), not Material `AlertDialog` with Material filled/text buttons for those flows.

#### Scenario: Process Library confirm uses TipDialogHost

- **WHEN** the operator confirms a destructive or save action in Process Library that previously used `AlertDialog`
- **THEN** the dialog is presented via `TipDialogHost` (or equivalent product frost host) with `HmiButton` actions

#### Scenario: IP Camera Settings CTAs

- **WHEN** the operator uses primary record/connect actions on IP Camera Settings
- **THEN** those CTAs are `HmiButton` instances rather than Material `FilledButton`

### Requirement: Process Library text entry uses CyberIME

Process Library edit forms that collect operator text or numbers SHALL use CyberIME (`showCyberImeInputDialog` and/or `CyberImeTextField`) and MUST NOT rely on bare Material `TextField` with the system soft keyboard as the sole product entry path.

#### Scenario: Library field edit opens CyberIME

- **WHEN** the operator edits a Process Library text or numeric field that requires keyboard entry
- **THEN** input is committed through CyberIME

### Requirement: Shared Wi‑Fi list actions use HmiButton

Shared Wi‑Fi network list UI (`wifi_network_views` and product callers) SHALL present connect / dismiss style actions with `HmiButton` rather than Material `FilledButton` / `TextButton` for those roles.

#### Scenario: Wi‑Fi list connect action

- **WHEN** the Wi‑Fi network list shows a primary connect action
- **THEN** that action is an `HmiButton`
