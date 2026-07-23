## MODIFIED Requirements

### Requirement: New HMI modal dialogs SHALL default to FrostedGlassDialog

When adding a new user-facing modal dialog on the HMI (confirmation, teaching, text input, date/time selection, upload/firmware progress, boot self-check, global operation status, or similar non-alarm prompt), the implementation SHALL use `FrostedGlassDialog.prompt(Context)` unless an existing specialized dialog component is explicitly required for **out-of-scope** flows (for example `WarnDialogUtil` alarms, numeric `InputDialogFragment` parameter entry, `ReminderExactDialog`, `EngineerModeEntryTipsDialog`, `CNCExitDialog`, or `WorkStatusDialog` machine-status panels).

Preferred entry points:

| Use case | API |
|----------|-----|
| Simple title + message + confirm/cancel | `FrostedGlassDialog.prompt(context).title(...).message(...).onConfirm(...).onCancel(...).show()` |
| Same from legacy call sites | `GlobalDialogUtil.showFrostedGlassPromptDialog(...)` |
| Custom body / actions | `FrostedGlassDialog.prompt(context).customBodyView(...)` and/or `customTitleView` / `customActionBarView` |

New code MUST NOT introduce another generic dialog shell when `FrostedGlassDialog` can host the content.

The following legacy shells listed in proposal **migrate-prompt-dialogs-to-frosted-glass** (WiFi password, date/time/timezone pickers, bind-device prompts, global status, text-input prompts, upload/firmware progress, boot self-check, etc.) SHALL be migrated to `FrostedGlassDialog` and MUST NOT remain exempt as permanent alternatives. Excluded shells (`ReminderExactDialog`, `WorkStatusDialog`, etc.) are listed in the proposal Non-goals section.

#### Scenario: Simple confirmation uses prompt builder

- **WHEN** a feature needs a title, message, and confirm/cancel actions
- **THEN** the dialog MUST be shown via `FrostedGlassDialog.prompt(...)` (or `GlobalDialogUtil.showFrostedGlassPromptDialog`)
- **AND** MUST NOT use framework `AlertDialog` title/button rows as the primary visual container

#### Scenario: Out-of-scope specialized dialogs remain exempt

- **WHEN** a flow is an alarm (`WarnDialogUtil`), numeric parameter entry (`InputDialogFragment` with number input types), `ReminderExactDialog`, engineer-mode entry tips, CNC exit confirm, or `WorkStatusDialog` machine-status panel
- **THEN** that specialized component MAY continue to use its existing shell
- **AND** new unrelated prompts in the same area SHOULD still migrate to `FrostedGlassDialog` when touched for other reasons

#### Scenario: Progress and self-check use custom body on FrostedGlass shell

- **WHEN** a flow shows upload progress, firmware upgrade progress, or boot self-check incremental rows
- **THEN** the overlay MUST use `FrostedGlassDialog` with a custom body layout and a thin feature wrapper that owns progress/row updates
- **AND** MUST NOT use standalone `AlertDialog` or legacy `Dialog` window chrome as the primary visual container

#### Scenario: Text and picker prompts use custom body on FrostedGlass shell

- **WHEN** a non-alarm prompt requires text entry, password entry, or date/time/timezone pickers
- **THEN** the overlay MUST use `FrostedGlassDialog.prompt(...).customBodyView(...)` (directly or via a thin feature wrapper)
- **AND** MUST NOT use standalone `AlertDialog`, `MaterialDialog`, or legacy `Dialog` window chrome as the primary visual container

## ADDED Requirements

### Requirement: Shared text-input body pattern for non-numeric prompts

Non-numeric text-input prompts (for example process parameter name, welding material name) SHALL use a shared frosted-glass custom body layout installed via `customBodyView`, with validation and confirm/cancel semantics unchanged from the pre-migration behavior.

#### Scenario: Process parameter name entry

- **WHEN** the user edits a commonly-used process parameter name
- **THEN** the dialog MUST appear inside `FrostedGlassDialog` with a text field in the body slot
- **AND** empty or over-length names MUST be rejected with the same validation feedback as before migration

#### Scenario: Material name entry

- **WHEN** the user edits welding material name text
- **THEN** the dialog MUST use `FrostedGlassDialog` with the shared text-input body
- **AND** material validation MUST be preserved

### Requirement: Shared picker body pattern for date time and timezone

Manual date, time, and timezone selection dialogs in Date & Time settings SHALL use `FrostedGlassDialog` with picker widgets in the custom body slot; applied values and error handling MUST remain equivalent to pre-migration behavior.

#### Scenario: Manual date picker on FrostedGlass

- **WHEN** automatic date & time is off and the user opens the date picker
- **THEN** year/month/day pickers render in a frosted-glass custom body
- **AND** confirming applies the selected date through the same system APIs as before

#### Scenario: Manual timezone picker on FrostedGlass

- **WHEN** automatic time zone is off and the user opens timezone selection
- **THEN** search and list selection render in a frosted-glass custom body
- **AND** a failed platform apply shows the same error feedback as before migration

### Requirement: Global operation status uses FrostedGlassDialog

`GlobalDialogUtil.showStatusDialog` (modes 0 failure, 1 success, 2 waiting, and 3 blocking firmware progress) SHALL use `FrostedGlassDialog` with a shared status custom body (icon, title/message, optional determinate SeekBar for mode 3, and confirm when applicable). Public call-site APIs and mode semantics MUST remain equivalent to the pre-migration behavior.

#### Scenario: Success status on FrostedGlass

- **WHEN** a call site shows `showStatusDialog` with success mode (1)
- **THEN** the dialog MUST render as a `FrostedGlassDialog` overlay with success icon and confirm dismiss
- **AND** MUST NOT use legacy `dialog_global` window chrome

#### Scenario: Blocking firmware progress on FrostedGlass

- **WHEN** a call site shows `showStatusDialog` with blocking progress mode (3)
- **THEN** the dialog MUST use `FrostedGlassDialog` with SeekBar progress in the custom body
- **AND** `updateFirmwareUpgradeProgress` MUST continue to update the visible progress while showing
