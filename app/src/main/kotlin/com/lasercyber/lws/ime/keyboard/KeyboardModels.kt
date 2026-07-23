package com.lasercyber.lws.ime.keyboard

enum class KeyboardKind {
    EnglishGlobal,
    ChineseGlobal,
    /** Keyboard A primary symbol layer — toggled from QWERTY via 123 / ABC. */
    NumericGlobal,
    /** Keyboard A extended symbol layer — entered via #+= from [NumericGlobal]. */
    SymbolsExtendedGlobal,
    /** Keyboard B — dedicated numeric pad for numeric input dialogs. */
    NumericDedicated,
}

enum class KeyboardMode {
    Alpha,
    Numeric,
}

enum class KeyId {
    Letter,
    Shift,
    Backspace,
    ModeSwitch,
    Space,
    CommaPeriod,
    At,
    Enter,
    Digit,
    Minus,
    Plus,
    DecimalPeriod,
    /** Clears all text in the focused numeric field. */
    Clear,
    /** Toggles primary ↔ extended symbol layers (#+=). */
    SymbolsMore,
    /** Toggles password visibility on masked fields. */
    PasswordReveal,
    Custom,
}

data class KeyDef(
    val id: KeyId,
    val primary: String,
    val secondary: String? = null,
    val widthWeight: Float = 1f,
    val isLetter: Boolean = false,
)

data class KeyboardRow(
    val keys: List<KeyDef>,
    val heightWeight: Float = 1f,
    /** Half-key-width side inset for staggered rows (e.g. A–L). */
    val leadingInsetWeight: Float = 0f,
    val trailingInsetWeight: Float = 0f,
)

data class KeyboardLayout(val kind: KeyboardKind, val rows: List<KeyboardRow>)
