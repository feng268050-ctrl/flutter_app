package com.lasercyber.lws.ime.keyboard

import com.lasercyber.lws.ime.ImeAction
import com.lasercyber.lws.ime.ImeRegistry
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig
import com.lasercyber.lws.ime.engine.ImeInputConnection
import com.lasercyber.lws.ime.field.ImeFieldType
import com.lasercyber.lws.ime.engine.pinyin.PinyinDictionary
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Locale

class KeyboardControllerPinyinTest {

    private class RecordingConnection : ImeInputConnection {
        val commits = mutableListOf<String>()

        override fun commitText(text: CharSequence) {
            commits.add(text.toString())
        }

        override fun deleteBackward(codePointCount: Int) = Unit

        override fun clearAll() = Unit

        override fun performEditorAction(action: ImeAction): Boolean = false
    }

    @Before
    fun setUp() {
        KeyboardLanguageSelector.chineseGlobalEnabledOverride = true
        ImeRegistry.languageProvider = { Locale.forLanguageTag("zh-CN") }
        PinyinDictionary.installForTests(
            phrases = mapOf(
                "buxiugang" to listOf("不锈钢"),
                "zhongwen" to listOf("中文"),
            ),
            syllables = mapOf(
                "bu" to listOf("不"),
                "xiu" to listOf("锈"),
                "gang" to listOf("钢"),
                "zhong" to listOf("中"),
                "wen" to listOf("文"),
            ),
        )
    }

    @After
    fun tearDown() {
        ImeRegistry.languageProvider = null
        KeyboardLanguageSelector.chineseGlobalEnabledOverride = null
        PinyinDictionary.resetForTests()
    }

    @Test
    fun chineseMode_appendsLettersToCompositionInsteadOfCommitting() {
        val connection = RecordingConnection()
        val controller = KeyboardController.forFieldType(
            fieldType = ImeFieldType.Text,
            connection = connection,
            enterKey = ImeEnterKeyConfig.done(),
            onEditorAction = { false },
        )
        val letterB = KeyDef(id = KeyId.Letter, primary = "b", isLetter = true)
        val letterU = KeyDef(id = KeyId.Letter, primary = "u", isLetter = true)

        controller.handleKey(letterB)
        controller.handleKey(letterU)

        assertEquals("bu", controller.pinyinComposition.raw)
        assertTrue(connection.commits.isEmpty())
    }

    @Test
    fun chineseMode_spaceCommitsSelectedCandidate() {
        val connection = RecordingConnection()
        val controller = KeyboardController.forFieldType(
            fieldType = ImeFieldType.Text,
            connection = connection,
            enterKey = ImeEnterKeyConfig.done(),
            onEditorAction = { false },
        )
        "buxiugang".forEach { ch ->
            controller.handleKey(KeyDef(id = KeyId.Letter, primary = ch.toString(), isLetter = true))
        }

        controller.handleKey(KeyDef(id = KeyId.Space, primary = " "))

        assertEquals(listOf("不锈钢"), connection.commits)
        assertEquals("", controller.pinyinComposition.raw)
    }

    @Test
    fun chineseMode_shiftInsertsApostrophe() {
        val controller = KeyboardController.forFieldType(
            fieldType = ImeFieldType.Text,
            connection = RecordingConnection(),
            enterKey = ImeEnterKeyConfig.done(),
            onEditorAction = { false },
        )
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "z", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "h", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "o", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "n", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "g", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Shift, primary = "⇧"))
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "w", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "e", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "n", isLetter = true))

        assertEquals("zhong'wen", controller.pinyinComposition.raw)
        assertTrue(controller.pinyinComposition.candidates.contains("中文"))
    }

    @Test
    fun chineseMode_backspaceTrimsCompositionBeforeConnection() {
        val connection = RecordingConnection()
        val controller = KeyboardController.forFieldType(
            fieldType = ImeFieldType.Text,
            connection = connection,
            enterKey = ImeEnterKeyConfig.done(),
            onEditorAction = { false },
        )
        controller.handleKey(KeyDef(id = KeyId.Letter, primary = "b", isLetter = true))
        controller.handleKey(KeyDef(id = KeyId.Backspace, primary = "⌫"))

        assertEquals("", controller.pinyinComposition.raw)
        assertTrue(connection.commits.isEmpty())

        controller.handleKey(KeyDef(id = KeyId.Backspace, primary = "⌫"))
        assertTrue(connection.commits.isEmpty())
    }
}
