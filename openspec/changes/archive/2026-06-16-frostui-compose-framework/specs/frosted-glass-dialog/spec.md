## ADDED Requirements

### Requirement: FrostedGlassDialog prompt path is implemented by frostui dialog layer

`FrostedGlassDialog.prompt(Context)` and its `PromptBuilder`/`Handle` public API SHALL remain the ui-layer entry point, but the overlay shell, scrim, blur card chrome, and default prompt layout for the high-frequency simple prompt path MUST be implemented by `com.lasercyber.lws.frostui.dialog`. `GlobalDialogUtil.showFrostedGlassPromptDialog(...)` MUST continue to work without signature changes.

#### Scenario: Simple prompt uses frostui implementation

- **WHEN** a caller invokes `FrostedGlassDialog.prompt(context).title(...).message(...).onConfirm(...).onCancel(...).show()`
- **THEN** the visible overlay MUST be rendered by frostui dialog components
- **AND** confirm/cancel callbacks and `Handle` accessors MUST behave equivalently to the pre-migration View implementation

#### Scenario: GlobalDialogUtil shortcut unchanged

- **WHEN** legacy code calls `GlobalDialogUtil.showFrostedGlassPromptDialog(...)`
- **THEN** the dialog MUST still appear with frostui-backed implementation
- **AND** callers MUST NOT require import or API changes

### Requirement: FrostedGlassDialog delegates card chrome to frostui card primitives

The liquid glass dialog shell SHALL use `frostui.card` primitives (`FrostCard`, `FrostButton`, `FrostBlur`) for card background, border, blur, and default action styling instead of direct `FrostedGlassCard`/`FrostedGlassButton` View wiring, while preserving scrim, corner radius, typography tokens, and action variant rules defined in this specification.

#### Scenario: Prompt overlay uses frostui card chrome

- **WHEN** a frostui-backed `FrostedGlassDialog` is shown over a visible activity
- **THEN** the card background MUST show live blurred activity content
- **AND** card chrome MUST be supplied by frostui.card primitives using split `frostui_*` design tokens
- **AND** default confirm/cancel actions MUST use frostui button styling with `top-left-bottom-right` border orientation for default prompt layouts

#### Scenario: Custom body slots remain View-compatible

- **WHEN** a caller supplies `customBodyView`, `customTitleView`, or `customActionBarView`
- **THEN** frostui dialog MUST host the supplied Android View in the appropriate slot
- **AND** feature wrappers MUST continue updating custom body content via `Handle` while showing
