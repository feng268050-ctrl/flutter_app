## Purpose

Quick Mode **More Parameters** entry opens Engineer Mode with the currently matched quick-mode process row as an in-memory editing session.

## Requirements

### Requirement: More parameters button in quick mode header

The quick mode screen SHALL display a **More Parameters** control (icon plus localized label) in the **top-right** area of the page, aligned with the equipment status bar region, when the operator is viewing a non-CNC quick-mode process page.

#### Scenario: Button visible on continuous weld quick mode

- **WHEN** the operator is on quick mode with `processType` equal to continuous welding (`ModelConstant.CONTINUOUS_WELDING`) and laser output overlay is not active
- **THEN** the More Parameters control MUST be visible in the top-right of the page

#### Scenario: Button hidden on CNC cut

- **WHEN** the operator selects CNC cut (`ModelConstant.CNC_CUT`) in quick mode
- **THEN** the More Parameters control MUST NOT be visible

#### Scenario: Button hidden during laser output overlay

- **WHEN** quick mode laser status overlay is active (`laserStatus` true)
- **THEN** the More Parameters control MUST NOT be visible

### Requirement: Navigate to engineer mode with current quick-mode selection

When the operator taps **More Parameters**, the system SHALL open **Engineer Mode** (`EngineerModeActivity`) and SHALL apply the **currently matched** quick-mode process parameters—the same row that would be sent by `GeneralOperationsFragment.findNowProcessParametersData()` for the active material, gear, and thickness or swing-width selection.

#### Scenario: Successful navigation with matched parameters

- **WHEN** the operator taps More Parameters and a matching quick-mode `ProcessParametersData` row exists for the current pickers
- **THEN** Engineer Mode MUST open on the tab corresponding to that row's `processType` and MUST load those parameter values as the active editable preset

#### Scenario: No matching row

- **WHEN** the operator taps More Parameters but no row matches the current picker state
- **THEN** the system MUST NOT navigate, MUST surface a user-visible error (toast or equivalent), and MUST NOT open Engineer Mode with stale parameters

### Requirement: More parameters entry respects device remote lock

The More Parameters navigation SHALL honor the same remote-lock policy as other home-to-engineer navigation entry points.

#### Scenario: Remote lock blocks navigation

- **WHEN** device remote lock policy blocks engineer-mode entry
- **THEN** tapping More Parameters MUST NOT open Engineer Mode

### Requirement: More parameters entry shows engineer mode first-time tips

When the operator enters Engineer Mode via **More Parameters**, the system SHALL show the same first-time engineer mode tips dialog used when entering from the home page, including shared **Don't remind again** state.

#### Scenario: Tips dialog on first quick-mode entry

- **WHEN** the operator taps More Parameters and has not opted out of engineer mode tips
- **THEN** the engineer mode tips dialog MUST appear before Engineer Mode opens

#### Scenario: Skip tips when opted out

- **WHEN** the operator previously checked **Don't remind again** for engineer mode tips
- **THEN** tapping More Parameters MUST open Engineer Mode directly without showing the tips dialog
