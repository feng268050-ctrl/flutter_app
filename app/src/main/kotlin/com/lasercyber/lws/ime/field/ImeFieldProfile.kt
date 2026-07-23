package com.lasercyber.lws.ime.field

import com.lasercyber.lws.ime.field.policy.NumericPolicyConfig
import com.lasercyber.lws.ime.keyboard.KeyboardKind

data class ImeFieldProfile(
    val initialLayoutId: KeyboardLayoutId,
    val allowedLayoutIds: Set<KeyboardLayoutId>,
    val bottomRowProfile: ImeBottomRowProfile = ImeBottomRowProfile.Default,
    val numericPolicyConfig: NumericPolicyConfig? = null,
    val maskInput: Boolean = false,
) {
    val initialKind: KeyboardKind
        get() = resolveKind(initialLayoutId)

    val allowedKinds: Set<KeyboardKind>
        get() = allowedLayoutIds.map { resolveKind(it) }.toSet()

    fun allowsKind(kind: KeyboardKind): Boolean = kind in allowedKinds

    private fun resolveKind(layoutId: KeyboardLayoutId): KeyboardKind = when (layoutId) {
        KeyboardLayoutId.QwertyGlobal -> KeyboardKind.EnglishGlobal
        KeyboardLayoutId.SymbolsPrimaryA -> KeyboardKind.NumericGlobal
        KeyboardLayoutId.SymbolsExtendedA -> KeyboardKind.SymbolsExtendedGlobal
        KeyboardLayoutId.NumericDedicatedB -> KeyboardKind.NumericDedicated
    }

    companion object {
        fun symbolLayersPlusQwerty(): Set<KeyboardLayoutId> = setOf(
            KeyboardLayoutId.QwertyGlobal,
            KeyboardLayoutId.SymbolsPrimaryA,
            KeyboardLayoutId.SymbolsExtendedA,
        )
    }
}
