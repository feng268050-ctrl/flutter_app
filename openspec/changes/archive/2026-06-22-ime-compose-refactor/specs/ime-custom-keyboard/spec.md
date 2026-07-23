## ADDED Requirements

### Requirement: Application provides three custom keyboard kinds

The system SHALL implement in-app custom keyboards in `com.lasercyber.lws.ime` with exactly three kinds: `EnglishGlobal`, `ChineseGlobal`, and `Numeric`. The custom keyboard MUST replace the system soft keyboard for supported HMI input overlays and MUST NOT rely on OEM keyboard rendering for those flows.

#### Scenario: Numeric field opens numeric keyboard

- **WHEN** the focused input field is configured for numeric entry (integer, decimal, or signed numeric)
- **THEN** the IME MUST show the `Numeric` keyboard kind with digits 0 through 9
- **AND** MUST NOT show the global QWERTY letter layout

#### Scenario: Text field opens language-appropriate global keyboard

- **WHEN** the focused input field is configured for text entry and the application language is Chinese
- **THEN** the IME MUST show the `ChineseGlobal` keyboard kind
- **AND** when the application language is not Chinese, MUST show `EnglishGlobal`

### Requirement: Application language selects Chinese versus English global keyboard

The IME SHALL determine whether to use `ChineseGlobal` or `EnglishGlobal` from the current application language setting (Common Settings language / `SystemSettingUtils.getLanguage()`), exposed through `ImeRegistry.languageProvider`. The keyboard MUST update to the matching global kind when the language setting changes while an input session is active.

#### Scenario: Language set to Chinese

- **WHEN** the application language is Chinese (`zh` locale prefix) and a text input gains focus
- **THEN** the IME MUST present `ChineseGlobal` key definitions

#### Scenario: Language set to English

- **WHEN** the application language is not Chinese and a text input gains focus
- **THEN** the IME MUST present `EnglishGlobal` key definitions

### Requirement: Global keyboard upper rows follow device QWERTY reference

The `EnglishGlobal` and `ChineseGlobal` keyboards SHALL render an upper letter area consistent with the device reference layout: row 1 `Q–P` with digit secondaries `1–0`, row 2 `A–L` with symbol secondaries, row 3 Shift + `Z–M` with symbol secondaries + Backspace. Each letter key MUST display its secondary function as a small corner hint on the key cap.

#### Scenario: Top row shows digit secondaries

- **WHEN** the global keyboard is visible
- **THEN** keys `Q` through `P` MUST show secondaries `1` through `0` respectively in the key cap hint position

#### Scenario: Shift toggles letter case for subsequent taps

- **WHEN** the user taps Shift on the global keyboard
- **THEN** subsequent letter key taps MUST commit uppercase letters until Shift is toggled off or a non-letter key is committed per keyboard state rules

### Requirement: Global keyboard bottom row has five fixed keys

The global keyboard bottom row SHALL contain exactly five keys in order: mode switch (`123` when in alpha mode, `abc` when numeric mode is active), Space, comma/period, `@`, and Enter. This row MUST match the simplified device reference (figure 3) and MUST NOT include extra keys such as symbol picker, language toggle, or microphone on the bottom row for the global layout.

#### Scenario: Bottom row shows five keys in alpha mode

- **WHEN** the global keyboard is in alpha mode
- **THEN** the bottom row MUST show mode key labeled `123`, Space, comma/period, `@`, and Enter in that order
- **AND** MUST NOT show additional bottom-row keys beyond these five

#### Scenario: Mode key switches to numeric keyboard

- **WHEN** the user taps the `123` mode key on the global keyboard bottom row
- **THEN** the IME MUST switch to the `Numeric` keyboard kind
- **AND** the mode key on return MUST be labeled `abc` to restore the language-appropriate global keyboard

#### Scenario: Space commits space character

- **WHEN** the user taps Space on the bottom row
- **THEN** the IME MUST commit U+0020 to the active input connection

### Requirement: Numeric keyboard layout follows device numeric reference

The `Numeric` keyboard SHALL render a digit layout covering `0` through `9` consistent with the device numeric reference, including Backspace and Enter actions required for numeric parameter entry.

#### Scenario: Numeric keyboard shows digits zero through nine

- **WHEN** the `Numeric` keyboard is visible
- **THEN** keys for digits `0` through `9` MUST be available
- **AND** Backspace MUST delete one character from the active input connection

### Requirement: Letter keys show long-press popup with uppercase secondary and lowercase

Every letter key on global keyboards SHALL support a long-press popup anchored above the key that presents three selectable outputs in order: uppercase letter, secondary function character, and lowercase letter. The popup MUST match the device reference interaction (figure 2) where the user can slide to highlight a choice before release.

#### Scenario: Long press on letter shows three choices

- **WHEN** the user long-presses letter key `N` whose secondary is `;`
- **THEN** a floating popup MUST appear above the key showing `N`, `;`, and `n`
- **AND** the initially highlighted choice MUST follow finger position or default to the secondary slot per implementation rules

#### Scenario: Release commits highlighted popup choice

- **WHEN** the user releases after selecting `;` in the popup
- **THEN** the IME MUST commit `;` to the active input connection
- **AND** MUST dismiss the popup

#### Scenario: Short tap commits primary without popup

- **WHEN** the user performs a short tap on a letter key without long-press
- **THEN** the IME MUST commit the primary character for the current shift state
- **AND** MUST NOT show the three-choice popup

### Requirement: Enter key display and action are configurable per input session

The IME SHALL accept `ImeEnterKeyConfig` per input session with an `ImeEnterKeyDisplay` that MAY be text-only, icon-only, text-and-icon, or a built-in default return icon. The Enter key MUST always render as a primary orange FrostedGlass button (`FrostButtonVariant.PRIMARY`) regardless of whether the face shows text, an icon, or both. The configured `ImeAction` MUST drive the same editor-action semantics as the pre-migration system IME action for that flow.

#### Scenario: Default enter shows icon with Done behavior

- **WHEN** a text input session uses `ImeEnterKeyDisplay.Default` or icon-only return styling
- **THEN** the Enter key MUST use primary orange styling
- **AND** MUST show the configured default return icon when no custom text is supplied
- **AND** tapping Enter MUST trigger the same confirm/submit path as `IME_ACTION_DONE` for that dialog

#### Scenario: Enter shows text-only label

- **WHEN** an input session configures `ImeEnterKeyDisplay.Text` with a non-empty label
- **THEN** the Enter key MUST render that label on the primary orange button face
- **AND** MUST NOT require an icon to be present

#### Scenario: Enter shows icon-only label

- **WHEN** an input session configures `ImeEnterKeyDisplay.Icon` with a drawable resource
- **THEN** the Enter key MUST render only that icon on the primary orange button face
- **AND** MUST provide content description when supplied for accessibility

#### Scenario: Enter shows text and icon together

- **WHEN** an input session configures `ImeEnterKeyDisplay.TextAndIcon`
- **THEN** the Enter key MUST render both the icon and label on the same primary orange button
- **AND** tapping Enter MUST invoke the configured `ImeAction`

#### Scenario: WiFi password enter shows Connect text

- **WHEN** the WiFi password input session configures enter display to the localized Connect string
- **THEN** the Enter key MUST display that Connect label on the primary orange custom keyboard button
- **AND** tapping Enter MUST invoke the WiFi password submit path without a separate on-screen Connect button

### Requirement: Keyboard key caps use FrostButton frosted glass styling

All custom keyboard key caps except Enter MUST use `FrostButton` with the default/neutral frosted glass variant, including visible press feedback and click sound via `FrostUiClickSoundRegistry`. The Enter key MUST use `FrostButtonVariant.PRIMARY` with shared primary orange tokens.

#### Scenario: Letter key uses default glass variant

- **WHEN** a letter key is rendered on the custom keyboard
- **THEN** it MUST use `FrostButtonVariant.DEFAULT`
- **AND** MUST NOT use primary orange styling reserved for Enter

#### Scenario: Enter key uses primary orange variant

- **WHEN** the Enter key is rendered
- **THEN** it MUST use `FrostButtonVariant.PRIMARY`

### Requirement: Custom keyboard hides system IME

When the custom keyboard is shown for a supported input overlay, the system MUST hide the system soft keyboard and MUST NOT call `InputMethodManager.showSoftInput` for that field. Host window soft-input mode MUST prevent background resize while the custom panel is visible.

#### Scenario: Focus shows custom panel not system keyboard

- **WHEN** an input field with custom IME enabled gains focus
- **THEN** the application custom keyboard panel MUST become visible
- **AND** the system IME MUST remain hidden

### Requirement: ImeInputConnection commits text and editor actions

The IME engine SHALL expose an `ImeInputConnection` abstraction that supports committing text, backward deletion, and performing configured editor actions, usable from both View `EditText` and Compose text field hosts.

#### Scenario: Key tap commits character

- **WHEN** the user taps a key that outputs `x`
- **THEN** `ImeInputConnection.commitText` MUST insert `x` into the focused field

#### Scenario: Enter performs configured editor action

- **WHEN** the user taps Enter configured with `ImeAction.Custom` for WiFi connect
- **THEN** `ImeInputConnection.performEditorAction` MUST invoke the WiFi submit handler
