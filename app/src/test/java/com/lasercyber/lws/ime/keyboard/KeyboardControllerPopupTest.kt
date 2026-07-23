package com.lasercyber.lws.ime.keyboard

import com.lasercyber.lws.ime.ImeAction
import com.lasercyber.lws.ime.engine.ImeEnterKeyConfig
import com.lasercyber.lws.ime.engine.ImeInputConnection
import com.lasercyber.lws.ime.field.ImeFieldType
import com.lasercyber.lws.ime.field.policy.NumericPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KeyboardControllerPopupTest {

    private class RecordingConnection(
        private var text: String = "",
    ) : ImeInputConnection {
        val commits = mutableListOf<String>()
        var clearCount = 0

        override fun commitText(text: CharSequence) {
            this.text += text
            commits.add(text.toString())
        }

        override fun deleteBackward(codePointCount: Int) = Unit

        override fun clearAll() {
            clearCount++
            text = ""
            commits.clear()
        }

        override fun performEditorAction(action: ImeAction): Boolean = false

        override fun currentText(): String = text
    }

    private fun controller(
        fieldType: ImeFieldType = ImeFieldType.Text,
        connection: ImeInputConnection = RecordingConnection(),
        numericPolicyOverride: com.lasercyber.lws.ime.field.policy.NumericPolicyConfig? = null,
    ): KeyboardController = KeyboardController.forFieldType(
        fieldType = fieldType,
        connection = connection,
        enterKey = ImeEnterKeyConfig.done(),
        onEditorAction = { false },
        numericPolicyOverride = numericPolicyOverride,
    )

    @Test
    fun commitPopupChoice_commitsUpperSecondaryAndLower() {
        val connection = RecordingConnection()
        val controller = controller(connection = connection)
        val key = KeyDef(
            id = KeyId.Letter,
            primary = "a",
            secondary = "1",
            isLetter = true,
        )

        controller.commitPopupChoice(key, KeyboardController.PopupChoice.Upper)
        controller.commitPopupChoice(key, KeyboardController.PopupChoice.Secondary)
        controller.commitPopupChoice(key, KeyboardController.PopupChoice.Lower)

        assertEquals(listOf("A", "1", "a"), connection.commits)
    }

    @Test
    fun commitPopupIndex_commitsPeriodOrComma() {
        val connection = RecordingConnection()
        val controller = controller(connection = connection)
        val key = KeyDef(
            id = KeyId.CommaPeriod,
            primary = ".",
            secondary = ",",
        )

        controller.commitPopupIndex(key, 0)
        controller.commitPopupIndex(key, 1)

        assertEquals(listOf(".", ","), connection.commits)
    }

    @Test
    fun commitPopupIndex_commitsQuoteOrBacktick() {
        val connection = RecordingConnection()
        val controller = controller(connection = connection)
        val key = KeyDef(
            id = KeyId.Custom,
            primary = "'",
            secondary = "`",
        )

        controller.commitPopupIndex(key, 0)
        controller.commitPopupIndex(key, 1)

        assertEquals(listOf("'", "`"), connection.commits)
    }

    @Test
    fun quoteKey_supportsAlternatePopup() {
        val key = KeyDef(id = KeyId.Custom, primary = "'", secondary = "`")
        assertTrue(key.supportsAlternatePopup())
        assertEquals(listOf("'", "`"), key.popupOptions())
    }

    @Test
    fun numericPolicy_blocksMinusAndDecimalForIntegerField() {
        val connection = RecordingConnection()
        val controller = controller(fieldType = ImeFieldType.Number, connection = connection)

        controller.handleKey(KeyDef(id = KeyId.Minus, primary = "-"))
        controller.handleKey(KeyDef(id = KeyId.DecimalPeriod, primary = "."))
        controller.handleKey(KeyDef(id = KeyId.Digit, primary = "5"))

        assertEquals(listOf("5"), connection.commits)
    }

    @Test
    fun handleKey_commitsMinusAndDecimalForSignedDecimalField() {
        val connection = RecordingConnection()
        val controller = controller(fieldType = ImeFieldType.SignedDecimal, connection = connection)

        controller.handleKey(KeyDef(id = KeyId.Minus, primary = "-"))
        controller.handleKey(KeyDef(id = KeyId.DecimalPeriod, primary = "."))
        controller.handleKey(KeyDef(id = KeyId.Digit, primary = "5"))

        assertEquals(listOf("-", ".", "5"), connection.commits)
    }

    @Test
    fun shiftTap_togglesTemporaryUppercase() {
        val connection = RecordingConnection()
        val controller = controller(connection = connection)
        val letter = KeyDef(id = KeyId.Letter, primary = "a", isLetter = true)

        controller.handleKey(KeyDef(id = KeyId.Shift, primary = "⇧"))
        assertEquals(true, controller.isUppercase)
        controller.handleKey(letter)
        assertEquals("A", connection.commits.single())
        assertEquals(false, controller.isUppercase)
    }

    @Test
    fun shiftLongPress_togglesCapsLock() {
        val connection = RecordingConnection()
        val controller = controller(connection = connection)
        val letter = KeyDef(id = KeyId.Letter, primary = "a", isLetter = true)

        controller.handleShiftLongPress()
        assertEquals(true, controller.capsLockEnabled)
        controller.handleKey(letter)
        controller.handleKey(letter)
        assertEquals(listOf("A", "A"), connection.commits)
        assertEquals(true, controller.capsLockEnabled)

        controller.handleKey(KeyDef(id = KeyId.Shift, primary = "⇧"))
        assertEquals(false, controller.capsLockEnabled)
    }

    @Test
    fun handleKey_clearAndDoubleZero() {
        val connection = RecordingConnection()
        val controller = controller(fieldType = ImeFieldType.Number, connection = connection)

        controller.handleKey(KeyDef(id = KeyId.Custom, primary = "00"))
        assertEquals(listOf("00"), connection.commits)

        connection.clearCount = 0
        controller.handleKey(KeyDef(id = KeyId.Clear, primary = "C"))
        assertEquals(1, connection.clearCount)
    }

    @Test
    fun dedicatedNumericLayout_matchesKeyboardBGrid() {
        val layout = KeyboardLanguageSelector.layoutForKind(KeyboardKind.NumericDedicated)
        assertEquals(4, layout.rows.size)
        assertEquals(listOf("1", "2", "3", "⌫"), layout.rows[0].keys.map { it.primary })
        assertEquals(listOf("4", "5", "6", "C"), layout.rows[1].keys.map { it.primary })
        assertEquals(listOf("7", "8", "9", "-"), layout.rows[2].keys.map { it.primary })
        assertEquals(listOf(".", "0", "00", "⏎"), layout.rows[3].keys.map { it.primary })
    }

    @Test
    fun symbolsPrimaryLayout_matchesFigure2() {
        val layout = KeyboardLanguageSelector.layoutForKind(KeyboardKind.NumericGlobal)
        assertEquals(4, layout.rows.size)
        assertEquals(
            listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "0"),
            layout.rows[0].keys.map { it.primary },
        )
        assertEquals(
            listOf("-", "/", ":", ";", "(", ")", "$", "&", "@", "\""),
            layout.rows[1].keys.map { it.primary },
        )
        assertEquals(
            listOf("#+=", ",", ".", "?", "!", "'", "⌫"),
            layout.rows[2].keys.map { it.primary },
        )
        assertEquals(
            listOf("ABC", " ", "⏎"),
            layout.rows[3].keys.map { it.primary },
        )
    }

    @Test
    fun symbolsExtendedLayout_matchesFigure3() {
        val layout = KeyboardLanguageSelector.layoutForKind(KeyboardKind.SymbolsExtendedGlobal)
        assertEquals(4, layout.rows.size)
        assertEquals(
            listOf("[", "]", "{", "}", "#", "%", "^", "*", "+", "="),
            layout.rows[0].keys.map { it.primary },
        )
        assertEquals(
            listOf("_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"),
            layout.rows[1].keys.map { it.primary },
        )
        assertEquals(
            listOf("123", ",", ".", "?", "!", "'", "⌫"),
            layout.rows[2].keys.map { it.primary },
        )
        assertEquals(
            listOf("ABC", " ", "⏎"),
            layout.rows[3].keys.map { it.primary },
        )
    }

    @Test
    fun defaultQwertyBottomRow_usesPeriodKeyWithoutAt() {
        val layout = KeyboardLanguageSelector.layoutForKind(KeyboardKind.EnglishGlobal)
        val bottom = layout.rows.last().keys
        assertEquals(listOf("123", " ", ".", "⏎"), bottom.map { it.primary })
        assertEquals(4, bottom.size)
    }

    @Test
    fun extendedLayer123_returnsToPrimarySymbols() {
        val controller = controller()
        controller.handleKey(KeyDef(id = KeyId.ModeSwitch, primary = "123"))
        controller.handleKey(KeyDef(id = KeyId.SymbolsMore, primary = "#+="))
        assertEquals(KeyboardKind.SymbolsExtendedGlobal, controller.kind)

        controller.handleKey(KeyDef(id = KeyId.ModeSwitch, primary = "123"))
        assertEquals(KeyboardKind.NumericGlobal, controller.kind)
    }

    @Test
    fun toggleMode_switchesBetweenGlobalAndSymbolsPrimary() {
        val controller = controller()
        assertEquals(KeyboardKind.EnglishGlobal, controller.kind)

        controller.handleKey(KeyDef(id = KeyId.ModeSwitch, primary = "123"))
        assertEquals(KeyboardKind.NumericGlobal, controller.kind)

        controller.handleKey(KeyDef(id = KeyId.ModeSwitch, primary = "ABC"))
        assertEquals(KeyboardKind.EnglishGlobal, controller.kind)
    }

    @Test
    fun symbolsMore_opensExtendedLayerFromPrimary() {
        val controller = controller()
        controller.handleKey(KeyDef(id = KeyId.ModeSwitch, primary = "123"))
        assertEquals(KeyboardKind.NumericGlobal, controller.kind)

        controller.handleKey(KeyDef(id = KeyId.SymbolsMore, primary = "#+="))
        assertEquals(KeyboardKind.SymbolsExtendedGlobal, controller.kind)
    }

    @Test
    fun initialKind_usesNumericDedicatedForNumberField() {
        val controller = controller(fieldType = ImeFieldType.Number)
        assertEquals(KeyboardKind.NumericDedicated, controller.kind)
    }

    @Test
    fun emailBottomRow_includesComSuffix() {
        val layout = KeyboardLanguageSelector.layoutForKind(
            kind = KeyboardKind.EnglishGlobal,
            bottomRowProfile = com.lasercyber.lws.ime.field.ImeBottomRowProfile.Email(comSuffixKey = true),
        )
        val bottom = layout.rows.last().keys.map { it.primary }
        assertTrue(bottom.contains(".com"))
        assertTrue(bottom.contains("@"))
    }

    @Test
    fun numericPolicy_blocksSecondDecimalPoint() {
        val decimalKey = KeyDef(id = KeyId.DecimalPeriod, primary = ".")
        val config = NumericPolicy.forSignedDecimal()
        assertTrue(NumericPolicy.shouldCommit(decimalKey, "1", config))
        assertFalse(NumericPolicy.shouldCommit(decimalKey, "1.2", config))
    }
}
