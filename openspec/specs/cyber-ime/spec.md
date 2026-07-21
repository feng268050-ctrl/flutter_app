# cyber-ime Specification

## Purpose
In-app overlay soft keyboard (CyberIME) for LWS HMI product Apps on flutter-pi — field-type registry, Keyboard A/B, session lift height, and commit path without OEM IME.

## Requirements

### Requirement: CyberIME package identity

The shared Flutter soft-keyboard kit SHALL live at `packages/cyber_ime` (in-repo path package for v1) with `publish_to: none`, SDK constraint compatible with `app/hmi`, and a public import surface under `package:cyber_ime/...`. Public types and widgets MUST use the **CyberIme\*** prefix. The package MUST NOT depend on the product App. Product Apps MUST depend on this package for HMI overlay keyboards rather than forking keyboard widgets under feature folders.

#### Scenario: App imports CyberIME

- **WHEN** `app/hmi` declares a path dependency on `cyber_ime`
- **THEN** product code can `import 'package:cyber_ime/cyber_ime.dart'` and resolve at least one public overlay/session API

### Requirement: In-app overlay keyboard (not system IME)

CyberIME SHALL implement an **application overlay** soft keyboard for HMI input sessions. It MUST NOT require a platform `InputMethodService` / OEM IME. For CyberIME-managed fields on Linux HMI, the App MUST suppress or ignore the system soft keyboard so only the CyberIME panel is used.

#### Scenario: Focus shows CyberIME panel

- **WHEN** a CyberIME session is attached to a focused text or numeric field
- **THEN** the CyberIME keyboard panel is shown as an overlay
- **AND** the flow MUST NOT rely on OEM soft-keyboard rendering for that session

### Requirement: Field-type registry selects keyboard profile

CyberIME SHALL expose a field-type registry (aligned with lws-ui `ImeFieldProfileRegistry`) that maps `CyberImeFieldType` values (at least Text, Number / SignedDecimal, WiFi, Password; Email / Uri MAY be registered without all scenes wired) to a keyboard kind, bottom-row profile, and numeric policy. Overlay entry MUST go through a field-type-aware session/spec API rather than ad-hoc per-dialog layout switches.

#### Scenario: Numeric field opens dedicated pad

- **WHEN** the focused field type is Number or SignedDecimal
- **THEN** CyberIME MUST show the dedicated numeric keyboard (Keyboard B)
- **AND** MUST NOT show the global QWERTY letter layout as the primary panel

#### Scenario: Wi-Fi password uses global keyboard profile

- **WHEN** the focused field type is WiFi or Password
- **THEN** CyberIME MUST show Keyboard A (global) with the WiFi/Password bottom-row profile from the registry

### Requirement: Keyboard A — global QWERTY and symbol layers

CyberIME SHALL implement Keyboard A with: (1) QWERTY letter rows, (2) a primary symbols layer entered via `123`, (3) an extended symbols layer entered via `#+=`, and return paths to QWERTY via `ABC`. Bottom row for default Text SHALL follow the product baseline (mode / space / punctuation / enter — exact key set documented in package README to match lws-ui baseline). Letter keys MUST support short-tap commit and long-press secondary popup where the baseline requires it.

#### Scenario: Toggle to primary symbols

- **WHEN** the user taps `123` on Keyboard A
- **THEN** the panel switches to the primary symbols layer
- **AND** a control exists to return to the letter layout

### Requirement: Keyboard B — dedicated numeric pad

CyberIME SHALL implement Keyboard B as a dedicated numeric pad with digits, backspace, clear (`C`), sign/decimal keys gated by `NumericPolicy`, and enter. It MUST NOT offer an `abc` mode switch back to QWERTY on the pad itself.

#### Scenario: Clear empties field

- **WHEN** the user taps `C` on Keyboard B
- **THEN** the active field content is cleared according to the session commit API

### Requirement: Language provider selects global kind

CyberIME SHALL resolve EnglishGlobal versus ChineseGlobal from an App-registered language provider (no hard dependency on Settings locale classes inside `cyber_ime`). Until ChineseGlobal assets/layout are complete, the package MAY temporarily present EnglishGlobal for Text fields when Chinese is selected, but MUST document that gap and MUST NOT claim Chinese parity in README until the ChineseGlobal task is done.

#### Scenario: Non-Chinese language uses EnglishGlobal

- **WHEN** the language provider reports a non-Chinese locale and a Text field is focused
- **THEN** CyberIME presents the EnglishGlobal letter layout

### Requirement: Session attach, detach, and card lift height

CyberIME SHALL expose a session API to attach on focus/show and detach on dismiss/dispose. While the keyboard panel is visible, the session MUST expose keyboard height so the host can translate the focused dialog/input card upward with a configurable margin (default 24 logical pixels) without resizing the underlying route scaffold. Touch handling for the keyboard MUST be limited to the panel bounds (MUST NOT use a full-screen touch absorber that steals taps above the keyboard).

#### Scenario: Detach resets lift signal

- **WHEN** the CyberIME session detaches or the keyboard hides
- **THEN** reported keyboard height returns to zero so the host can reset card translation

#### Scenario: Stacked sessions are refcount-safe

- **WHEN** multiple CyberIME sessions attach on the same overlay stack
- **THEN** host lift/IME override remains until the last session detaches

### Requirement: Commit path for keys and enter

CyberIME SHALL commit characters, backspace, and enter/submit through a documented connection to the focused field (controller or input connection shim). Enter MUST invoke a configurable `CyberImeAction` (Done / Go / Custom) supplied by the session.

#### Scenario: Enter invokes Done action

- **WHEN** the session is configured with Done and the user taps Enter
- **THEN** the registered Done/submit callback runs

### Requirement: Optional host hooks without cyber_ui hard dependency

`cyber_ime` MAY offer optional callbacks (keyboard shown/hidden, lift applied) for the App or CyberUI host to refresh backdrop sampling. The package MUST NOT hard-require `cyber_ui` types for core keyboard rendering; composition MAY live in the App or a thin adapter.

#### Scenario: Unregistered hooks still work

- **WHEN** no backdrop hook is registered
- **THEN** keyboard show/hide and typing still function

### Requirement: Keyboard A supports four regional typewriter layouts

CyberIME Keyboard A SHALL provide selectable typewriter arrangements for ANSI US QWERTY, ISO German QWERTZ, ISO French AZERTY, and JIS Japanese letter/symbol rows. Layout selection MUST be driven by an App-registered profile/layout provider (or the shared product keyboard preference). Layouts MUST NOT include an F1–F12 row or a right-hand numeric keypad.

Regional soft layouts MUST be built from a unified `CyberImeKeyCode` identity plus per-profile character maps (base / shift / optional altGr). Soft key commit characters MUST come from that map. The product MUST align those maps with the XKB layouts used for physical typing for the same profile; CyberIME MUST NOT implement F-keys or NumPad chrome (hardware path owns those).

#### Scenario: Profile switches QWERTY to QWERTZ

- **WHEN** the registered profile is ISO DE and Keyboard A letter layer is shown
- **THEN** the letter row arrangement matches German QWERTZ (Z/Y positions per DE), not US QWERTY

#### Scenario: No numpad on Keyboard A

- **WHEN** Keyboard A is shown for any regional profile
- **THEN** the panel MUST NOT render a dedicated 9-key numeric keypad block

#### Scenario: Soft commit uses KeyMap

- **WHEN** the operator taps a letter key on Keyboard A for the active regional profile
- **THEN** the inserted character matches the KeyMap entry for that key’s `CyberImeKeyCode` under the active profile
