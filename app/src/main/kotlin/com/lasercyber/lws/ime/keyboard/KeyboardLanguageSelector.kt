package com.lasercyber.lws.ime.keyboard

import com.lasercyber.lws.ime.ImeRegistry
import com.lasercyber.lws.ime.field.KeyboardLayoutId
import com.lasercyber.lws.ime.field.ImeBottomRowProfile
import com.lasercyber.lws.ime.field.ImeFieldProfile
import com.lasercyber.lws.ime.field.ImeFieldProfileRegistry
import com.lasercyber.lws.ime.field.ImeFieldType
import com.lasercyber.lws.ime.keyboard.layout.DedicatedNumericLayout
import com.lasercyber.lws.ime.keyboard.layout.GlobalQwertyLayout
import com.lasercyber.lws.ime.keyboard.layout.GlobalSymbolsExtendedLayout
import com.lasercyber.lws.ime.keyboard.layout.GlobalSymbolsPrimaryLayout
import java.util.Locale
import androidx.annotation.VisibleForTesting

object KeyboardLanguageSelector {
    /** Product default: English-only global QWERTY. Set override in tests to exercise ChineseGlobal. */
    private const val CHINESE_GLOBAL_KEYBOARD_ENABLED = false

    @get:VisibleForTesting
    internal var chineseGlobalEnabledOverride: Boolean? = null

    fun isChineseGlobalEnabled(): Boolean =
        chineseGlobalEnabledOverride ?: CHINESE_GLOBAL_KEYBOARD_ENABLED

    fun resolveGlobalKind(): KeyboardKind {
        if (!isChineseGlobalEnabled()) {
            return KeyboardKind.EnglishGlobal
        }
        val locale = ImeRegistry.languageProvider?.invoke() ?: Locale.getDefault()
        return if (isChineseLocale(locale)) {
            KeyboardKind.ChineseGlobal
        } else {
            KeyboardKind.EnglishGlobal
        }
    }

    fun isChineseLocale(locale: Locale): Boolean {
        val language = locale.language.lowercase(Locale.ROOT)
        if (language.startsWith("zh")) {
            return true
        }
        return locale.toLanguageTag().lowercase(Locale.ROOT).startsWith("zh")
    }

    fun layoutForKind(
        kind: KeyboardKind,
        bottomRowProfile: ImeBottomRowProfile = ImeBottomRowProfile.Default,
        numericModeLabel: Boolean = false,
    ): KeyboardLayout = when (kind) {
        KeyboardKind.EnglishGlobal ->
            GlobalQwertyLayout.layout(KeyboardKind.EnglishGlobal, bottomRowProfile, numericModeLabel)
        KeyboardKind.ChineseGlobal ->
            GlobalQwertyLayout.layout(KeyboardKind.ChineseGlobal, bottomRowProfile, numericModeLabel)
        KeyboardKind.NumericGlobal -> GlobalSymbolsPrimaryLayout.layout()
        KeyboardKind.SymbolsExtendedGlobal -> GlobalSymbolsExtendedLayout.layout()
        KeyboardKind.NumericDedicated -> DedicatedNumericLayout.layout()
    }

    fun initialKind(fieldType: ImeFieldType): KeyboardKind =
        ImeFieldProfileRegistry.initialKind(fieldType)

    fun isNumericKind(kind: KeyboardKind): Boolean =
        kind == KeyboardKind.NumericGlobal ||
            kind == KeyboardKind.SymbolsExtendedGlobal ||
            kind == KeyboardKind.NumericDedicated

    fun isSymbolLayerKind(kind: KeyboardKind): Boolean =
        kind == KeyboardKind.NumericGlobal || kind == KeyboardKind.SymbolsExtendedGlobal

    fun isDedicatedNumericKind(kind: KeyboardKind): Boolean = kind == KeyboardKind.NumericDedicated

    fun isGlobalKind(kind: KeyboardKind): Boolean =
        kind == KeyboardKind.EnglishGlobal || kind == KeyboardKind.ChineseGlobal

    fun profileAllowsKind(profile: ImeFieldProfile, kind: KeyboardKind): Boolean = when (kind) {
        KeyboardKind.EnglishGlobal, KeyboardKind.ChineseGlobal ->
            KeyboardLayoutId.QwertyGlobal in profile.allowedLayoutIds
        else -> profile.allowsKind(kind)
    }
}
