# frosted-glass-dialog Specification

## Purpose

Define the **default in-window modal dialog** for the LWS HMI app. New confirmation prompts, teaching flows, and similar overlays SHALL use **`FrostDialog`** (雾化玻璃设计 shell with live backdrop blur) instead of stock `AlertDialog` chrome or ad-hoc full-screen layouts.

The generic component provides **title**, **text body**, and **action** slots only. Progress bars, illustrations, QR codes, and other feature UI MUST be supplied through **custom slot views** or small feature-specific wrappers — not as built-in dialog modes.
## Requirements
### Requirement: New HMI modal dialogs SHALL default to FrostDialog

When adding a new user-facing modal dialog on the HMI (confirmation, teaching, text input, date/time selection, upload/firmware progress, boot self-check, global operation status, or similar non-alarm prompt), the implementation SHALL use `FrostDialog.prompt(Context)` unless an existing specialized dialog component is explicitly required for **out-of-scope** flows (for example `WarnDialogUtil` alarms, `ReminderExactDialog`, `EngineerModeEntryTipsDialog`, `CNCExitDialog`, or `WorkStatusDialog` machine-status panels).

Preferred entry points:

| Use case | API |
|----------|-----|
| Simple title + message + confirm/cancel | `FrostDialog.prompt(context).title(...).message(...).onConfirm(...).onCancel(...).show()` |
| Same from legacy call sites | `GlobalDialogUtil.showFrostPromptDialog(...)` |
| Custom body / actions | `FrostDialog.prompt(context).customBodyView(...)` and/or `customTitleView` / `customActionBarView` |
| Numeric parameter entry | `FrostNumericInputDialog.show(...)` |

New code MUST NOT introduce another generic dialog shell when `FrostDialog` can host the content.

The following legacy shells listed in proposal **migrate-prompt-dialogs-to-frosted-glass** (WiFi password, date/time/timezone pickers, bind-device prompts, global status, text-input prompts, upload/firmware progress, boot self-check, etc.) SHALL be migrated to `FrostDialog` and MUST NOT remain exempt as permanent alternatives. Numeric parameter entry via legacy `InputDialogFragment` SHALL also be migrated to `FrostNumericInputDialog`. Excluded shells (`ReminderExactDialog`, `WorkStatusDialog`, etc.) are listed in the proposal Non-goals section.

#### Scenario: Simple confirmation uses prompt builder

- **WHEN** a feature needs a title, message, and confirm/cancel actions
- **THEN** the dialog MUST be shown via `FrostDialog.prompt(...)` (or `GlobalDialogUtil.showFrostPromptDialog`)
- **AND** MUST NOT use framework `AlertDialog` title/button rows as the primary visual container

#### Scenario: Out-of-scope specialized dialogs remain exempt

- **WHEN** a flow is an alarm (`WarnDialogUtil`), `ReminderExactDialog`, engineer-mode entry tips, CNC exit confirm, or `WorkStatusDialog` machine-status panel
- **THEN** that specialized component MAY continue to use its existing shell
- **AND** new unrelated prompts in the same area SHOULD still migrate to `FrostDialog` when touched for other reasons

#### Scenario: Progress and self-check use custom body on FrostedGlass shell

- **WHEN** a flow shows upload progress, firmware upgrade progress, or boot self-check incremental rows
- **THEN** the overlay MUST use `FrostDialog` with a custom body layout and a thin feature wrapper that owns progress/row updates
- **AND** MUST NOT use standalone `AlertDialog` or legacy `Dialog` window chrome as the primary visual container

#### Scenario: Text and picker prompts use custom body on FrostedGlass shell

- **WHEN** a non-alarm prompt requires text entry, password entry, or date/time/timezone pickers
- **THEN** the overlay MUST use `FrostDialog.prompt(...).customBodyView(...)` (directly or via a thin feature wrapper)
- **AND** MUST NOT use standalone `AlertDialog`, `MaterialDialog`, or legacy `Dialog` window chrome as the primary visual container

#### Scenario: Numeric parameter entry uses FrostedGlass numeric wrapper

- **WHEN** a non-alarm prompt requires numeric parameter entry with optional stepper controls
- **THEN** the overlay MUST use `FrostNumericInputDialog` with the shared numeric custom body
- **AND** MUST NOT use `InputDialogFragment` or standalone `Dialog`/`DialogFragment` window chrome

### Requirement: Shared text-input body pattern for non-numeric prompts

Non-numeric text-input prompts (for example process parameter name, welding material name) SHALL use a shared frosted-glass custom body layout installed via `customBodyView`, with validation and confirm/cancel semantics unchanged from the pre-migration behavior.

#### Scenario: Process parameter name entry

- **WHEN** the user edits a commonly-used process parameter name
- **THEN** the dialog MUST appear inside `FrostDialog` with a text field in the body slot
- **AND** empty or over-length names MUST be rejected with the same validation feedback as before migration

#### Scenario: Material name entry

- **WHEN** the user edits welding material name text
- **THEN** the dialog MUST use `FrostDialog` with the shared text-input body
- **AND** material validation MUST be preserved

### Requirement: Shared picker body pattern for date time and timezone

Manual date, time, and timezone selection dialogs in Date & Time settings SHALL use `FrostDialog` with picker widgets in the custom body slot; applied values and error handling MUST remain equivalent to pre-migration behavior.

#### Scenario: Manual date picker on FrostedGlass

- **WHEN** automatic date & time is off and the user opens the date picker
- **THEN** year/month/day pickers render in a frosted-glass custom body
- **AND** confirming applies the selected date through the same system APIs as before

#### Scenario: Manual timezone picker on FrostedGlass

- **WHEN** automatic time zone is off and the user opens timezone selection
- **THEN** search and list selection render in a frosted-glass custom body
- **AND** a failed platform apply shows the same error feedback as before migration

### Requirement: Global operation status uses FrostDialog

`GlobalDialogUtil.showStatusDialog` (modes 0 failure, 1 success, 2 waiting, and 3 blocking firmware progress) SHALL use `FrostDialog` with a shared status custom body (icon, title/message, optional determinate SeekBar for mode 3, and confirm when applicable). Public call-site APIs and mode semantics MUST remain equivalent to the pre-migration behavior.

#### Scenario: Success status on FrostedGlass

- **WHEN** a call site shows `showStatusDialog` with success mode (1)
- **THEN** the dialog MUST render as a `FrostDialog` overlay with success icon and confirm dismiss
- **AND** MUST NOT use legacy `dialog_global` window chrome

#### Scenario: Blocking firmware progress on FrostedGlass

- **WHEN** a call site shows `showStatusDialog` with blocking progress mode (3)
- **THEN** the dialog MUST use `FrostDialog` with SeekBar progress in the custom body
- **AND** `updateFirmwareUpgradeProgress` MUST continue to update the visible progress while showing

### Requirement: Default body slot is a single TextView

The generic dialog shell (`dialog_frosted_glass_prompt.xml`) SHALL expose a **body slot** whose default content is **`tv_frosted_glass_message`** — a single `TextView` bound by `PromptBuilder.message(...)`.

The generic dialog MUST NOT ship built-in progress, seek bar, or multi-widget body modes. Callers that need richer body content SHALL replace the body slot via `customBodyView(View)` or `customBodyView(@LayoutRes, Consumer<View>)`.

#### Scenario: Teaching prompt shows plain text body

- **WHEN** a caller sets `.message(...)` without `customBodyView`
- **THEN** the user sees the message in the default body `TextView`
- **AND** no additional body widgets are rendered by the generic shell

#### Scenario: Progress UI uses custom body layout

- **WHEN** a feature needs determinate progress (SeekBar + status text)
- **THEN** the feature MUST provide a dedicated body layout (for example `frosted_glass_body_zero_point_progress.xml`)
- **AND** MUST install it with `customBodyView`
- **AND** progress updates MUST be owned by the feature wrapper (for example `ZeroPointAutoProgressDialog`), not by `FrostDialog` itself

### Requirement: Liquid glass shell uses live blur and shared visual tokens

The dialog SHALL render as an in-window overlay attached to the hosting `Activity` content root (via `FrostOverlayHost`), with:

- Semi-transparent scrim (`frosted_glass_scrim`)
- `BlurView` card with rounded clip (`frosted_glass_rounded_clip`, `frosted_glass_corner_radius`)
- Glass fill and configurable border drawn through the shared `FrostedGlassCard` foundation
- Typography and buttons using `frosted_glass_text_*`, shared `FrostButtonView` styling, and `frosted_glass_divider` resources

`FrostDialog` and other FrostedGlass-style dialog wrappers MUST use the shared `FrostedGlassCard` foundation for card chrome instead of applying separate ad-hoc panel background/foreground drawables directly to dialog content. Prompt dialogs MAY dismiss on scrim tap when `dismissOnScrimClick(true)`; blocking flows (for example in-progress correction) SHALL disable scrim dismiss.

#### Scenario: Overlay blurs activity content behind the card

- **WHEN** `FrostDialog` is shown over a visible activity
- **THEN** the card background MUST show live blurred content from the activity (not an opaque flat panel only)
- **AND** the card MUST respect the shared 雾化玻璃设计 corner radius and border styling
- **AND** the card chrome MUST be supplied by the shared `FrostedGlassCard` foundation

#### Scenario: Blocking progress disables scrim dismiss

- **WHEN** a long-running operation shows a 雾化玻璃设计 dialog that must not dismiss accidentally
- **THEN** the caller MUST set `dismissOnScrimClick(false)`
- **AND** explicit cancel (action slot or programmatic dismiss) remains the dismissal path

#### Scenario: Dialog action buttons use shared FrostButtonView styling

- **WHEN** `FrostDialog` renders its default action slot
- **THEN** confirm and cancel actions MUST use the shared `FrostButtonView` styling
- **AND** existing confirm/cancel visibility, text, and callback behavior MUST remain unchanged

#### Scenario: Default prompt actions use standardized FrostButtonView chrome

- **WHEN** `dialog_frosted_glass_prompt.xml` renders cancel and confirm actions
- **THEN** both actions MUST use `borderGradientCenter="top-left-bottom-right"`
- **AND** cancel MUST use the `default` variant while confirm MUST use the `primary` variant

#### Scenario: Startup self-check close action uses shared FrostButtonView styling

- **WHEN** the Startup Self-Check custom body renders its close control
- **THEN** the close action MUST use `FrostButtonView` with `default` variant and `top-left-bottom-right` border orientation
- **AND** existing close visibility, text, and callback behavior MUST remain unchanged

### Requirement: Safety tips screens adopt shared FrostedGlass components

Safety Operations Tips and Product Use Disclaimer screens SHALL use the shared FrostedGlass component foundation for their main card container and agree action.

#### Scenario: Safety tips card and agree action use shared components

- **WHEN** `activity_safety_tips.xml` or `activity_use_safety_tips.xml` is inflated
- **THEN** the main content container MUST use `FrostedGlassCard`
- **AND** the agree action MUST use `FrostButtonView` with `primary` variant and `top-left-bottom-right` border orientation

#### Scenario: Product use disclaimer link remains a text link

- **WHEN** Safety Operations Tips renders the Product Use Disclaimer entry point
- **THEN** that control MUST remain a text link rather than a `FrostButtonView`
- **AND** only the agree action adopts the shared button component

### Requirement: Slot model supports optional custom chrome

`FrostDialog` SHALL support optional replacement of:

- **Title slot** — `customTitleView`
- **Body slot** — `customBodyView` (default: message `TextView`)
- **Action slot** — `customActionBarView` (default: cancel + confirm row)

`PromptBuilder` SHALL support hiding the confirm button via `showConfirm(false)` for cancel-only flows while keeping the default action bar layout.

Returned `Handle` SHALL expose `getRootView()`, slot accessors, `findViewById(int)`, `dismiss()`, and `isShowing()` for feature code that updates custom body content after show.

#### Scenario: Cancel-only action bar

- **WHEN** a dialog needs only a cancel action (no confirm)
- **THEN** the caller MAY use `.showConfirm(false).cancelText(...).onCancel(...)`
- **AND** the confirm control MUST NOT be visible

#### Scenario: Handle resolves custom body widgets

- **WHEN** a feature wrapper shows a dialog with `customBodyView`
- **THEN** it MAY locate body widgets via `Handle.findViewById` or references captured in the layout binder
- **AND** MAY post UI updates on the overlay root while `Handle.isShowing()` is true

### Requirement: Lifecycle is centralized and activity-safe

Only one 雾化玻璃设计 overlay MAY be visible at a time. `FrostDialog.show()` MUST return `null` if an overlay is already showing or the context cannot resolve a live `Activity`.

`GlobalDialogUtil.onDestroy()` SHALL call `FrostDialog.dismiss()` so overlays do not leak across activity teardown.

Programmatic `Handle.dismiss()` and `FrostDialog.dismiss()` SHALL remove the overlay without invoking confirm/cancel callbacks.

#### Scenario: Second show while visible is rejected

- **WHEN** a 雾化玻璃设计 dialog is already showing
- **AND** another caller invokes `.show()` on a new builder
- **THEN** the second call MUST return `null` and MUST NOT stack a second overlay

#### Scenario: Activity destroy clears overlay

- **WHEN** the hosting activity is destroyed while a 雾化玻璃设计 dialog is visible
- **THEN** `GlobalDialogUtil.onDestroy()` MUST dismiss the overlay as part of global dialog cleanup

### Requirement: Reference implementation for custom-body progress

**Zero Offset Auto Correction** (Advanced Settings) SHALL demonstrate the intended pattern:

1. Teaching step — `FrostDialog.prompt(...).message(...).onConfirm(...)` (default text body)
2. In-progress step — `ZeroPointAutoProgressDialog.show(...)`, which wraps `FrostDialog` with `customBodyView(R.layout.frosted_glass_body_zero_point_progress)` and owns `updateProgress(int, CharSequence)`

Future progress or multi-widget dialogs SHOULD follow the same split: generic shell + feature layout + thin feature wrapper.

#### Scenario: Zero point teaching uses default body

- **WHEN** the user starts Zero Offset Auto Correction and a teaching prompt is required
- **THEN** the app shows `FrostDialog.prompt` with title and message only

#### Scenario: Zero point correction progress uses custom body wrapper

- **WHEN** manual zero-point correction is running
- **THEN** the app shows `ZeroPointAutoProgressDialog` (custom SeekBar + status text body)
- **AND** `FrostDialog` itself does not expose a built-in progress API

### Requirement: Shared numeric-input body pattern for parameter entry

Numeric parameter-input prompts (engineer-mode process fields and advanced-settings device parameters) SHALL use shared body layout `frosted_glass_body_numeric_input.xml` installed via `customBodyView`, with validation and confirm/cancel semantics unchanged from the pre-migration `InputDialogFragment` behavior.

#### Scenario: Thickness entry with unit title

- **WHEN** the user edits welding thickness with mm/in unit suffix in the title
- **THEN** the dialog MUST appear inside `FrostDialog` with the numeric body and unit formatted title
- **AND** decimal validation via `EngineerDataCheck` MUST be preserved

### Requirement: IME interaction MUST NOT resize host background for input overlays

FrostedGlass overlays that host focusable text or numeric input fields SHALL prevent the host Activity content from being vertically compressed when the soft keyboard is visible. Implementation MUST use `com.lasercyber.lws.ime.core.ImeController` (or `FrostPromptConfig.imeConfig` which delegates to it) to temporarily adjust host `softInputMode` to `SOFT_INPUT_ADJUST_NOTHING` and apply IME insets to the overlay card via vertical translation rather than resizing the activity content root. Feature wrappers MUST NOT invoke legacy `FrostedGlassImeCoordinator` after migration is complete.

#### Scenario: Numeric input keyboard does not adjustResize host

- **WHEN** a `FrostNumericInputDialog` is showing and the IME opens
- **THEN** the host activity MUST NOT apply `adjustResize` layout shrinking to the page beneath the overlay
- **AND** the overlay card MUST remain interactable above the keyboard

#### Scenario: FrostPromptConfig enables IME session automatically

- **WHEN** an input overlay is shown with non-null `imeConfig` on `FrostPromptConfig`
- **THEN** `FrostOverlayHost` MUST attach and detach `ImeController` for the overlay lifecycle without requiring duplicate attach calls in the feature wrapper

### Requirement: Read-only parameter list custom body pattern

Informational dialogs that summarize process-parameter field values (for example remote received-parameter confirmation) SHALL use `FrostDialog.prompt(...).customBodyView(...)` with a shared read-only list body layout. When only acknowledgment is required, the dialog MAY use **OK-only** confirm (`.showCancel(false).confirmText(R.string.ok_text)`) following the same pattern as global status dialogs.

#### Scenario: Remote received-parameter summary

- **WHEN** the app shows the remote process-parameter received confirmation
- **THEN** the overlay MUST use `FrostDialog` with a custom body containing the shared read-only parameter list
- **AND** MUST show only an OK confirm action in the default action slot

#### Scenario: List content supplied by feature wrapper

- **WHEN** a read-only parameter list dialog is shown
- **THEN** row labels, values, and units MUST be bound by the feature wrapper or shared row builder
- **AND** `FrostDialog` itself MUST NOT gain built-in parameter-list modes

### Requirement: FrostDialog prompt path is implemented by frostui dialog layer

`FrostDialog.prompt(Context)` and its `PromptBuilder`/`Handle` public API SHALL remain the ui-layer entry point, but the overlay shell, scrim, blur card chrome, and default prompt layout for the high-frequency simple prompt path MUST be implemented by `com.lasercyber.lws.frostui.dialog`. `GlobalDialogUtil.showFrostPromptDialog(...)` provides a Java convenience wrapper with equivalent behavior.

#### Scenario: Simple prompt uses frostui implementation

- **WHEN** a caller invokes `FrostDialog.prompt(context).title(...).message(...).onConfirm(...).onCancel(...).show()`
- **THEN** the visible overlay MUST be rendered by frostui dialog components
- **AND** confirm/cancel callbacks and `Handle` accessors MUST behave equivalently to the pre-migration View implementation

#### Scenario: GlobalDialogUtil prompt shortcut

- **WHEN** code calls `GlobalDialogUtil.showFrostPromptDialog(...)`
- **THEN** the dialog MUST appear with frostui-backed implementation

### Requirement: FrostDialog delegates card chrome to frostui card primitives

The liquid glass dialog shell SHALL use `frostui.card` primitives (`FrostCard`, `FrostBlur`) and `frostui.button` primitives (`FrostButton`) for card background, border, blur, and default action styling instead of legacy View wiring, while preserving scrim, corner radius, typography tokens, and action variant rules defined in this specification.

#### Scenario: Prompt overlay uses frostui card chrome

- **WHEN** a frostui-backed `FrostDialog` is shown over a visible activity
- **THEN** the card background MUST show live blurred activity content
- **AND** card chrome MUST be supplied by frostui.card primitives using split `frostui_*` design tokens
- **AND** default confirm/cancel actions MUST use frostui button styling with `top-left-bottom-right` border orientation for default prompt layouts

#### Scenario: Custom body slots remain View-compatible

- **WHEN** a caller supplies `customBodyView`, `customTitleView`, or `customActionBarView`
- **THEN** frostui dialog MUST host the supplied Android View in the appropriate slot
- **AND** feature wrappers MUST continue updating custom body content via `Handle` while showing

### Requirement: FrostedGlass overlay cards use live BlurView backdrop

`FrostCardView` instances shown inside `FrostOverlayHost` dialog overlays SHALL use live `BlurView` against the activity `BlurTarget` (or equivalent capture root) as the primary backdrop blur mechanism. Bitmap snapshot blur MAY be used only when live `BlurView` setup fails.

#### Scenario: Prompt dialog shows live blur on open

- **WHEN** a `FrostedGlassDialog` prompt overlay is attached and the dialog card has backdrop blur enabled
- **THEN** the card MUST display live `BlurView` blur before any optional freeze
- **AND** MUST NOT block the UI thread on full-window CPU stack blur

#### Scenario: Overlay freeze stops BlurView updates

- **WHEN** the overlay host freezes the dialog backdrop after initial settle (triple-invalidate semantics)
- **THEN** the card MUST call `BlurView.setBlurAutoUpdate(false)` to retain the last GPU frame
- **AND** MUST NOT replace the live path with a new CPU stack-blurred full-screen bitmap as the default freeze mechanism

#### Scenario: Single BlurView per dialog card

- **WHEN** a frosted-glass prompt dialog is shown
- **THEN** exactly one `BlurView` layer on the dialog card MUST perform backdrop blur
- **AND** there MUST NOT be a separate outer `BlurView` wrapping the same card

### Requirement: Input overlays integrate imeConfig on FrostPromptConfig

`FrostPromptConfig` SHALL expose an optional `imeConfig: ImeConfig?`. When non-null, the frostui dialog layer MUST manage IME session attach and detach for the overlay card anchor.

#### Scenario: Text input dialog uses imeConfig

- **WHEN** `FrostedGlassTextInputDialog` is shown
- **THEN** it MUST configure `imeConfig` on the underlying prompt config
- **AND** MUST NOT manually call legacy IME coordinator attach or detach in the wrapper

