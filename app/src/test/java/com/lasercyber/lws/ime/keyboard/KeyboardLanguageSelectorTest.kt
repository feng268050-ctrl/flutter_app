package com.lasercyber.lws.ime.keyboard

import com.lasercyber.lws.ime.ImeAction
import com.lasercyber.lws.ime.ImeRegistry
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig
import com.lasercyber.lws.ime.engine.ImeInputConnection
import com.lasercyber.lws.ime.field.ImeFieldType
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

class KeyboardLanguageSelectorTest {

    @After
    fun tearDown() {
        ImeRegistry.languageProvider = null
        KeyboardLanguageSelector.chineseGlobalEnabledOverride = null
    }

    @Test
    fun resolveGlobalKind_usesEnglishGlobalWhenChineseDisabled() {
        ImeRegistry.languageProvider = { Locale.forLanguageTag("zh-CN") }
        assertEquals(KeyboardKind.EnglishGlobal, KeyboardLanguageSelector.resolveGlobalKind())
    }

    @Test
    fun resolveGlobalKind_usesChineseGlobalForZhCnWhenEnabled() {
        KeyboardLanguageSelector.chineseGlobalEnabledOverride = true
        try {
            ImeRegistry.languageProvider = { Locale.forLanguageTag("zh-CN") }
            assertEquals(KeyboardKind.ChineseGlobal, KeyboardLanguageSelector.resolveGlobalKind())
        } finally {
            KeyboardLanguageSelector.chineseGlobalEnabledOverride = null
        }
    }

    @Test
    fun resolveGlobalKind_usesEnglishGlobalForEnUs() {
        ImeRegistry.languageProvider = { Locale.forLanguageTag("en-US") }
        assertEquals(KeyboardKind.EnglishGlobal, KeyboardLanguageSelector.resolveGlobalKind())
    }

    @Test
    fun layoutForKind_chineseAndEnglishShareSameQwertyStructure() {
        val english = KeyboardLanguageSelector.layoutForKind(KeyboardKind.EnglishGlobal)
        val chinese = KeyboardLanguageSelector.layoutForKind(KeyboardKind.ChineseGlobal)
        assertEquals(english.rows.size, chinese.rows.size)
        english.rows.zip(chinese.rows).forEach { (englishRow, chineseRow) ->
            assertEquals(englishRow.keys.size, chineseRow.keys.size)
            englishRow.keys.zip(chineseRow.keys).forEach { (englishKey, chineseKey) ->
                assertEquals(englishKey.id, chineseKey.id)
                assertEquals(englishKey.primary, chineseKey.primary)
                assertEquals(englishKey.secondary, chineseKey.secondary)
                assertEquals(englishKey.widthWeight, chineseKey.widthWeight, 0.001f)
            }
        }
    }

    @Test
    fun initialKind_usesNumericDedicatedForNumberField() {
        assertEquals(
            KeyboardKind.NumericDedicated,
            KeyboardLanguageSelector.initialKind(ImeFieldType.Number),
        )
    }

    @Test
    fun syncGlobalKindFromLanguage_staysEnglishWhenChineseDisabled() {
        ImeRegistry.languageProvider = { Locale.forLanguageTag("en-US") }
        val controller = KeyboardController.forFieldType(
            fieldType = ImeFieldType.Text,
            connection = NoopImeInputConnection,
            enterKey = ImeEnterKeyConfig.done(),
            onEditorAction = { false },
        )
        assertEquals(KeyboardKind.EnglishGlobal, controller.activeKind)

        ImeRegistry.languageProvider = { Locale.forLanguageTag("zh-CN") }
        controller.syncGlobalKindFromLanguage()
        assertEquals(KeyboardKind.EnglishGlobal, controller.kind)
        assertEquals(KeyboardKind.EnglishGlobal, controller.activeKind)
    }

    private object NoopImeInputConnection : ImeInputConnection {
        override fun commitText(text: CharSequence) {}
        override fun deleteBackward(codePointCount: Int) {}
        override fun clearAll() {}
        override fun performEditorAction(action: ImeAction): Boolean = false
    }
}
