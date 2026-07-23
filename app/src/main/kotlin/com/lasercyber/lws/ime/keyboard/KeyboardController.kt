package com.lasercyber.lws.ime.keyboard

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.lasercyber.lws.ime.ImeAction
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig
import com.lasercyber.lws.ime.engine.ImeInputConnection
import com.lasercyber.lws.ime.engine.pinyin.PinyinComposition
import com.lasercyber.lws.ime.field.ImeFieldProfile
import com.lasercyber.lws.ime.field.ImeFieldProfileRegistry
import com.lasercyber.lws.ime.field.ImeFieldType
import com.lasercyber.lws.ime.field.policy.NumericPolicy
import com.lasercyber.lws.ime.field.policy.NumericPolicyConfig

class KeyboardController(
    profile: ImeFieldProfile,
    private val connection: ImeInputConnection,
    val enterKey: ImeEnterKeyConfig,
    private val onEditorAction: (ImeAction) -> Boolean,
) {
    private val fieldProfile = profile
    private val numericPolicyConfig: NumericPolicyConfig? = profile.numericPolicyConfig

    var kind by mutableStateOf(profile.initialKind)
        private set
    var shiftEnabled by mutableStateOf(false)
        private set
    var capsLockEnabled by mutableStateOf(false)
        private set
    var passwordVisible by mutableStateOf(connection.isPasswordVisible())
        private set

    val pinyinComposition = PinyinComposition()

    val activeKind: KeyboardKind
        get() = when (kind) {
            KeyboardKind.NumericGlobal,
            KeyboardKind.SymbolsExtendedGlobal,
            KeyboardKind.NumericDedicated,
            -> kind
            else -> KeyboardLanguageSelector.resolveGlobalKind()
        }

    private val isChineseInput: Boolean
        get() = KeyboardLanguageSelector.isChineseGlobalEnabled() &&
            activeKind == KeyboardKind.ChineseGlobal

    val isUppercase: Boolean
        get() = shiftEnabled || capsLockEnabled

    val layout: KeyboardLayout
        get() = KeyboardLanguageSelector.layoutForKind(
            kind = activeKind,
            bottomRowProfile = fieldProfile.bottomRowProfile,
            numericModeLabel = kind == KeyboardKind.NumericGlobal ||
                kind == KeyboardKind.SymbolsExtendedGlobal,
        )

    fun syncGlobalKindFromLanguage() {
        if (KeyboardLanguageSelector.isDedicatedNumericKind(kind)) {
            return
        }
        if (KeyboardLanguageSelector.isSymbolLayerKind(kind)) {
            return
        }
        val resolved = KeyboardLanguageSelector.resolveGlobalKind()
        if (kind == resolved) {
            return
        }
        kind = resolved
        shiftEnabled = false
        capsLockEnabled = false
        pinyinComposition.clear()
    }

    fun handleKey(key: KeyDef) {
        if (isChineseInput) {
            handleChineseKey(key)
            return
        }
        handleEnglishKey(key)
    }

    fun commitPopupChoice(key: KeyDef, choice: PopupChoice) {
        if (isChineseInput) {
            commitChinesePopupChoice(key, choice)
            return
        }
        commitEnglishPopupChoice(key, choice)
    }

    fun commitPopupIndex(key: KeyDef, index: Int) {
        val options = key.popupOptions()
        if (options.isEmpty()) {
            return
        }
        val choice = when {
            hasDualPopupOptions(key) -> if (index == 1) PopupChoice.Secondary else PopupChoice.Primary
            else -> when (index.coerceIn(0, options.lastIndex)) {
                0 -> PopupChoice.Upper
                1 -> PopupChoice.Secondary
                else -> PopupChoice.Lower
            }
        }
        commitPopupChoice(key, choice)
    }

    fun resolvePrimary(key: KeyDef): String {
        if (!key.isLetter) {
            return key.primary
        }
        if (isChineseInput) {
            return key.primary.lowercase()
        }
        return if (isUppercase) key.primary.uppercase() else key.primary.lowercase()
    }

    fun handleShiftLongPress() {
        if (isChineseInput) {
            return
        }
        capsLockEnabled = !capsLockEnabled
        if (capsLockEnabled) {
            shiftEnabled = false
        }
    }

    fun commitCandidate(index: Int) {
        val candidate = pinyinComposition.candidates.getOrNull(index) ?: return
        connection.commitText(candidate)
        pinyinComposition.clear()
    }

    private fun handleChineseKey(key: KeyDef) {
        when (key.id) {
            KeyId.Shift -> pinyinComposition.appendApostrophe()
            KeyId.Backspace -> {
                if (pinyinComposition.isComposing) {
                    pinyinComposition.deleteLast()
                } else {
                    connection.deleteBackward()
                }
            }
            KeyId.ModeSwitch -> {
                pinyinComposition.clear()
                toggleMode(key)
            }
            KeyId.SymbolsMore -> {
                pinyinComposition.clear()
                toggleSymbolsMore()
            }
            KeyId.Space -> {
                if (pinyinComposition.isComposing && pinyinComposition.candidates.isNotEmpty()) {
                    commitCandidate(pinyinComposition.selectedIndex)
                } else {
                    connection.commitText(" ")
                }
            }
            KeyId.CommaPeriod -> {
                pinyinComposition.clear()
                connection.commitText(key.primary)
            }
            KeyId.At -> {
                pinyinComposition.clear()
                connection.commitText("@")
            }
            KeyId.PasswordReveal -> {
                pinyinComposition.clear()
                togglePasswordVisibility()
            }
            KeyId.Minus -> {
                pinyinComposition.clear()
                commitIfAllowed(key)
            }
            KeyId.Clear -> {
                pinyinComposition.clear()
                connection.clearAll()
            }
            KeyId.Plus -> {
                pinyinComposition.clear()
                commitIfAllowed(key)
            }
            KeyId.DecimalPeriod -> {
                pinyinComposition.clear()
                commitIfAllowed(key)
            }
            KeyId.Enter -> {
                if (pinyinComposition.isComposing && pinyinComposition.candidates.isNotEmpty()) {
                    commitCandidate(0)
                }
                onEditorAction(enterKey.action)
            }
            KeyId.Letter -> pinyinComposition.appendLetter(key.primary.first())
            KeyId.Digit, KeyId.Custom -> {
                pinyinComposition.clear()
                commitIfAllowed(key)
            }
        }
    }

    private fun handleEnglishKey(key: KeyDef) {
        when (key.id) {
            KeyId.Shift -> handleShiftTap()
            KeyId.Backspace -> connection.deleteBackward()
            KeyId.ModeSwitch -> toggleMode(key)
            KeyId.SymbolsMore -> toggleSymbolsMore()
            KeyId.Space -> connection.commitText(" ")
            KeyId.CommaPeriod -> connection.commitText(key.primary)
            KeyId.At -> connection.commitText("@")
            KeyId.PasswordReveal -> togglePasswordVisibility()
            KeyId.Minus -> commitIfAllowed(key)
            KeyId.Clear -> connection.clearAll()
            KeyId.Plus -> commitIfAllowed(key)
            KeyId.DecimalPeriod -> commitIfAllowed(key)
            KeyId.Enter -> onEditorAction(enterKey.action)
            KeyId.Letter, KeyId.Digit, KeyId.Custom -> {
                commitIfAllowed(key)
                if (key.isLetter && shiftEnabled && !capsLockEnabled) {
                    shiftEnabled = false
                }
            }
        }
    }

    private fun commitIfAllowed(key: KeyDef) {
        val config = numericPolicyConfig
        if (config != null &&
            KeyboardLanguageSelector.isDedicatedNumericKind(activeKind) &&
            !NumericPolicy.shouldCommit(key, connection.currentText(), config)
        ) {
            return
        }
        val output = if (key.isLetter) resolvePrimary(key) else key.primary
        connection.commitText(output)
    }

    private fun togglePasswordVisibility() {
        passwordVisible = connection.setPasswordVisible(!passwordVisible)
    }

    private fun commitChinesePopupChoice(key: KeyDef, choice: PopupChoice) {
        when {
            hasDualPopupOptions(key) -> {
                pinyinComposition.clear()
                val text = when (choice) {
                    PopupChoice.Secondary -> key.secondary ?: key.primary
                    else -> key.primary
                }
                connection.commitText(text)
            }
            key.isLetter -> when (choice) {
                PopupChoice.Secondary -> {
                    pinyinComposition.clear()
                    connection.commitText(key.secondary ?: key.primary.lowercase())
                }
                PopupChoice.Upper, PopupChoice.Primary, PopupChoice.Lower ->
                    pinyinComposition.appendLetter(key.primary.first())
            }
            else -> {
                pinyinComposition.clear()
                connection.commitText(key.primary)
            }
        }
    }

    private fun commitEnglishPopupChoice(key: KeyDef, choice: PopupChoice) {
        val text = when {
            hasDualPopupOptions(key) -> when (choice) {
                PopupChoice.Secondary -> key.secondary ?: key.primary
                else -> key.primary
            }
            key.isLetter -> when (choice) {
                PopupChoice.Upper, PopupChoice.Primary -> key.primary.uppercase()
                PopupChoice.Secondary -> key.secondary ?: key.primary.lowercase()
                PopupChoice.Lower -> key.primary.lowercase()
            }
            else -> key.primary
        }
        connection.commitText(text)
        if (key.isLetter && shiftEnabled && !capsLockEnabled) {
            shiftEnabled = false
        }
    }

    private fun handleShiftTap() {
        if (capsLockEnabled) {
            capsLockEnabled = false
            shiftEnabled = false
        } else {
            shiftEnabled = !shiftEnabled
        }
    }

    private fun toggleMode(key: KeyDef) {
        val target = when (kind) {
            KeyboardKind.SymbolsExtendedGlobal -> when {
                key.primary.equals("ABC", ignoreCase = true) ->
                    KeyboardLanguageSelector.resolveGlobalKind()
                key.primary == "123" -> KeyboardKind.NumericGlobal
                else -> kind
            }
            KeyboardKind.NumericGlobal -> if (key.primary.equals("ABC", ignoreCase = true)) {
                KeyboardLanguageSelector.resolveGlobalKind()
            } else {
                kind
            }
            else -> if (key.primary == "123" || key.primary.equals("abc", ignoreCase = true)) {
                KeyboardKind.NumericGlobal
            } else {
                kind
            }
        }
        switchToKind(target)
    }

    private fun toggleSymbolsMore() {
        val target = when (kind) {
            KeyboardKind.NumericGlobal -> KeyboardKind.SymbolsExtendedGlobal
            KeyboardKind.SymbolsExtendedGlobal -> KeyboardKind.NumericGlobal
            else -> return
        }
        switchToKind(target)
    }

    private fun switchToKind(target: KeyboardKind) {
        if (!KeyboardLanguageSelector.profileAllowsKind(fieldProfile, target)) {
            return
        }
        kind = target
        shiftEnabled = false
        capsLockEnabled = false
        pinyinComposition.clear()
    }

    enum class PopupChoice {
        Primary,
        Upper,
        Secondary,
        Lower,
    }

    companion object {
        fun forFieldType(
            fieldType: ImeFieldType,
            connection: ImeInputConnection,
            enterKey: ImeEnterKeyConfig,
            onEditorAction: (ImeAction) -> Boolean,
            numericPolicyOverride: NumericPolicyConfig? = null,
        ): KeyboardController = KeyboardController(
            profile = ImeFieldProfileRegistry.profile(fieldType, numericPolicyOverride),
            connection = connection,
            enterKey = enterKey,
            onEditorAction = onEditorAction,
        )
    }
}

fun KeyDef.supportsAlternatePopup(): Boolean =
    isLetter || hasDualPopupOptions(this)

private fun hasDualPopupOptions(key: KeyDef): Boolean =
    (key.id == KeyId.CommaPeriod || key.id == KeyId.Custom) && !key.secondary.isNullOrEmpty()

fun KeyDef.popupOptions(): List<String> = when {
    hasDualPopupOptions(this) -> listOf(primary, secondary!!)
    isLetter ->
        listOf(primary.uppercase(), secondary.orEmpty(), primary.lowercase())
    else -> emptyList()
}
