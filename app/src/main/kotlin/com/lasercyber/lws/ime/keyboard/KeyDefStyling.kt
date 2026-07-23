package com.lasercyber.lws.ime.keyboard

/**
 * Function keys: gray glass + orange label (no accent border).
 *
 * [KeyId.Backspace] uses this style on every keyboard kind; numeric-only keys apply on
 * [KeyboardKind.NumericGlobal] / [KeyboardKind.NumericDedicated].
 */
internal fun KeyDef.usesSingleAccentKeycap(kind: KeyboardKind): Boolean = when (id) {
    KeyId.Backspace -> true
    KeyId.Clear,
    KeyId.Minus,
    KeyId.Plus,
    -> KeyboardLanguageSelector.isNumericKind(kind)
    else -> false
}
