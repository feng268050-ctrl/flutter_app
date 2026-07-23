package com.lasercyber.lws.ime.field

import com.lasercyber.lws.ime.keyboard.KeyboardKind

enum class KeyboardLayoutId {
    QwertyGlobal,
    SymbolsPrimaryA,
    SymbolsExtendedA,
    NumericDedicatedB,
}

fun KeyboardLayoutId.toKeyboardKind(): KeyboardKind = when (this) {
    KeyboardLayoutId.QwertyGlobal -> KeyboardKind.EnglishGlobal
    KeyboardLayoutId.SymbolsPrimaryA -> KeyboardKind.NumericGlobal
    KeyboardLayoutId.SymbolsExtendedA -> KeyboardKind.SymbolsExtendedGlobal
    KeyboardLayoutId.NumericDedicatedB -> KeyboardKind.NumericDedicated
}

fun KeyboardKind.toLayoutId(): KeyboardLayoutId? = when (this) {
    KeyboardKind.EnglishGlobal,
    KeyboardKind.ChineseGlobal,
    -> KeyboardLayoutId.QwertyGlobal
    KeyboardKind.NumericGlobal -> KeyboardLayoutId.SymbolsPrimaryA
    KeyboardKind.SymbolsExtendedGlobal -> KeyboardLayoutId.SymbolsExtendedA
    KeyboardKind.NumericDedicated -> KeyboardLayoutId.NumericDedicatedB
}
