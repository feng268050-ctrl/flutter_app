## MODIFIED Requirements

### Requirement: New HMI modal dialogs SHALL default to FrostedGlassDialog

When adding a new user-facing modal dialog on the HMI (confirmation, teaching, text input, date/time selection, upload/firmware progress, boot self-check, global operation status, or similar non-alarm prompt), the implementation SHALL use `FrostedGlassDialog.prompt(Context)` unless an existing specialized dialog component is explicitly required for **out-of-scope** flows (for example `WarnDialogUtil` alarms, `ReminderExactDialog`, `EngineerModeEntryTipsDialog`, `CNCExitDialog`, or `WorkStatusDialog` machine-status panels).

Preferred entry points:

| Use case | API |
|----------|-----|
| Simple title + message + confirm/cancel | `FrostedGlassDialog.prompt(context).title(...).message(...).onConfirm(...).onCancel(...).show()` |
| Same from legacy call sites | `GlobalDialogUtil.showFrostedGlassPromptDialog(...)` |
| Custom body / actions | `FrostedGlassDialog.prompt(context).customBodyView(...)` and/or `customTitleView` / `customActionBarView` |
| Numeric parameter entry | `FrostedGlassNumericInputDialog.show(...)` |

New code MUST NOT introduce another generic dialog shell when `FrostedGlassDialog` can host the content.

The following legacy shells listed in proposal **migrate-prompt-dialogs-to-frosted-glass** (WiFi password, date/time/timezone pickers, bind-device prompts, global status, text-input prompts, upload/firmware progress, boot self-check, etc.) SHALL be migrated to `FrostedGlassDialog` and MUST NOT remain exempt as permanent alternatives. Numeric parameter entry via legacy `InputDialogFragment` SHALL also be migrated to `FrostedGlassNumericInputDialog`. Excluded shells (`ReminderExactDialog`, `WorkStatusDialog`, etc.) are listed in the proposal Non-goals section.

#### Scenario: Simple confirmation uses prompt builder

- **WHEN** a feature needs a title, message, and confirm/cancel actions
- **THEN** the dialog MUST be shown via `FrostedGlassDialog.prompt(...)` (or `GlobalDialogUtil.showFrostedGlassPromptDialog`)
- **AND** MUST NOT use framework `AlertDialog` title/button rows as the primary visual container

#### Scenario: Out-of-scope specialized dialogs remain exempt

- **WHEN** a flow is an alarm (`WarnDialogUtil`), `ReminderExactDialog`, engineer-mode entry tips, CNC exit confirm, or `WorkStatusDialog` machine-status panel
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

#### Scenario: Numeric parameter entry uses FrostedGlass numeric wrapper

- **WHEN** a non-alarm prompt requires numeric parameter entry with optional stepper controls
- **THEN** the overlay MUST use `FrostedGlassNumericInputDialog` with the shared numeric custom body
- **AND** MUST NOT use `InputDialogFragment` or standalone `Dialog`/`DialogFragment` window chrome

## ADDED Requirements

### Requirement: Shared numeric-input body pattern for parameter entry

Numeric parameter-input prompts (engineer-mode process fields and advanced-settings device parameters) SHALL use shared body layout `frosted_glass_body_numeric_input.xml` installed via `customBodyView`, with validation and confirm/cancel semantics unchanged from the pre-migration `InputDialogFragment` behavior.

#### Scenario: Thickness entry with unit title

- **WHEN** the user edits welding thickness with mm/in unit suffix in the title
- **THEN** the dialog MUST appear inside `FrostedGlassDialog` with the numeric body and unit formatted title
- **AND** decimal validation via `EngineerDataCheck` MUST be preserved

### Requirement: IME interaction MUST NOT resize host background for input overlays

FrostedGlass overlays that host focusable text or numeric input fields SHALL prevent the host Activity content from being vertically compressed when the soft keyboard is visible, by temporarily adjusting host `softInputMode` and applying IME insets to the overlay card rather than resizing the activity content root.

#### Scenario: Numeric input keyboard does not adjustResize host

- **WHEN** a `FrostedGlassNumericInputDialog` is showing and the IME opens
- **THEN** the host activity MUST NOT apply `adjustResize` layout shrinking to the page beneath the overlay
- **AND** the overlay card MUST remain interactable above the keyboard
