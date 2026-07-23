## ADDED Requirements

### Requirement: Overlay input IME sessions use ImeController

The system SHALL coordinate soft-keyboard (IME) interaction for in-window overlay input surfaces through `com.lasercyber.lws.ime.core.ImeController`. Input overlays MUST NOT call legacy `FrostedGlassImeCoordinator` directly once migration is complete. Each overlay IME session MUST be keyed per overlay instance and reference an `ImeAnchor` that applies vertical lift to the dialog card without resizing the host Activity content root.

#### Scenario: Attach on input overlay show

- **WHEN** an overlay with `ImeConfig` is shown and hosts a focusable text or numeric field
- **THEN** `ImeController.attach` MUST save the host Activity `softInputMode`, apply `SOFT_INPUT_ADJUST_NOTHING`, and register inset listeners for card lift
- **AND** the host Activity content root MUST retain its pre-keyboard layout height

#### Scenario: Detach on overlay dismiss

- **WHEN** the input overlay is dismissed after the soft keyboard was visible or focused
- **THEN** `ImeController.detach` MUST hide the IME, reset card translation, restore the saved host `softInputMode`, and clear residual IME insets on the content root

#### Scenario: Refcount-safe overlay stack

- **WHEN** multiple overlays on the same Activity attach IME sessions sequentially
- **THEN** host `softInputMode` MUST remain overridden until the last session detaches
- **AND** restoring the host window MUST occur only when the refcount returns to zero

### Requirement: Card lift keeps input interactable above keyboard

While an IME session is active and the custom keyboard panel or soft keyboard is visible, the system SHALL compute visible keyboard height from the custom panel height or `WindowInsetsCompat.Type.ime()` fallback, and apply vertical translation to the overlay card anchor so the focused input remains usable above the keyboard with a configurable margin (default 24dp).

#### Scenario: Custom keyboard panel opens and card shifts

- **WHEN** the application custom keyboard panel is shown for a focused field in an active IME session
- **THEN** the overlay card MUST translate vertically based on the custom panel height so the input area is not obscured
- **AND** translation MUST NOT change the layout height of the host Activity content beneath the overlay

#### Scenario: Keyboard closed resets lift

- **WHEN** the custom keyboard panel hides while the overlay remains visible
- **THEN** card translation MUST return to zero

### Requirement: ImeRegistry allows frost-specific side effects without ime-to-frostui dependency

`com.lasercyber.lws.ime.ImeRegistry` SHALL provide optional hooks for app-layer registration of frost-specific side effects and language resolution. The `ime/core` and `ime/engine` packages MUST NOT import `com.lasercyber.lws.frostui` or `com.lasercyber.lws.ui`.

#### Scenario: Keyboard shown triggers registered backdrop refresh

- **WHEN** the custom keyboard panel becomes visible, card lift is applied, and `ImeRegistry.onKeyboardShown` is registered
- **THEN** the registered callback MUST be invoked with the host Activity and keyboard height in pixels
- **AND** when unregistered, IME coordination MUST continue without backdrop side effects

#### Scenario: Language provider registered by app layer

- **WHEN** `ImeRegistry.languageProvider` is registered to return the current application locale
- **THEN** the custom keyboard MUST use that locale to choose `ChineseGlobal` versus `EnglishGlobal` without importing ui settings classes from `ime/core`

#### Scenario: Anchor lift triggers registered matrix sync

- **WHEN** card lift is applied and `ImeRegistry.onAnchorLiftApplied` is registered
- **THEN** the registered callback MUST receive the lifted anchor view for optional static-backdrop matrix synchronization

### Requirement: Compose ImeHost provides session lifecycle

The `ime.compose` package SHALL expose `rememberImeSession` and `ImeHost` Composables that attach and detach `ImeController` via `DisposableEffect`, host `ImeKeyboardPanel` when focused, and expose computed lift offset to child content.

#### Scenario: Compose host attaches on enter

- **WHEN** `ImeHost` enters composition with an active session
- **THEN** it MUST attach the IME session for the host Activity
- **AND** MUST detach on dispose

### Requirement: ImeAction standardizes enter key submit

The system SHALL represent enter/submit actions through `com.lasercyber.lws.ime.ImeAction` (`Done`, `Go`, `Custom(actionId, label)`). Custom keyboard Enter and hardware Enter (`KEYCODE_ENTER` + `ACTION_DOWN`) MUST invoke the same submit triggers unless a capability spec defines otherwise.

#### Scenario: Done submits text input

- **WHEN** the user taps Enter on the custom keyboard configured for Done in a text input overlay
- **THEN** the wrapper validation and confirm path MUST run using the same semantics as before migration

#### Scenario: Custom action submits WiFi password

- **WHEN** the WiFi password field configures Enter with the connect label and custom action
- **THEN** tapping Enter on the custom keyboard MUST invoke the same submit path as the former Connect control without requiring an on-screen Connect button

### Requirement: Custom keyboard reveal after overlay layout

When auto-showing the keyboard for a focusable field in an overlay, the system SHALL wait until the field is attached and laid out before showing the custom keyboard panel, and MAY retry reveal at bounded delays to survive blur or card re-parenting during dialog open.

#### Scenario: Auto-show after numeric stepper ready

- **WHEN** a numeric input overlay registers `onEditTextReady` from an embedded stepper
- **THEN** the IME MUST show the custom numeric keyboard after layout without calling system `showSoftInput`
- **AND** MUST re-sync card position after the panel is shown
