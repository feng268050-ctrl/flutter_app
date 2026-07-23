package com.lasercyber.lws.ime.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ImeInsetsTest {

    @Test
    fun resolveKeyboardHeight_prefersImeInsetWhenVisible() {
        assertEquals(300, ImeInsets.resolveKeyboardHeightPx(decorHeight = 2000, visibleBottom = 1700, imeInsetBottom = 300))
    }

    @Test
    fun resolveKeyboardHeight_fallsBackToVisibleFrameDelta() {
        assertEquals(250, ImeInsets.resolveKeyboardHeightPx(decorHeight = 2000, visibleBottom = 1750, imeInsetBottom = 0))
    }

    @Test
    fun effectiveKeyboardHeight_usesMaxOfSystemAndCustomPanel() {
        assertEquals(280, ImeInsets.effectiveKeyboardHeightPx(systemImePx = 0, customPanelPx = 280))
        assertEquals(320, ImeInsets.effectiveKeyboardHeightPx(systemImePx = 320, customPanelPx = 280))
    }

    @Test
    fun computeCardTranslationY_centersWhenSpaceAllows() {
        val translation = ImeInsets.computeCardTranslationY(
            visibleTopPx = 0,
            visibleBottomPx = 1200,
            cardTopOnScreenPx = 400f,
            cardHeightPx = 200,
            keyboardHeightPx = 400,
            marginPx = 24,
        )
        assertEquals(100f, translation, 0.01f)
    }

    @Test
    fun computeCardTranslationY_liftsAboveKeyboardWhenSpaceTight() {
        val translation = ImeInsets.computeCardTranslationY(
            visibleTopPx = 0,
            visibleBottomPx = 240,
            cardTopOnScreenPx = 300f,
            cardHeightPx = 200,
            keyboardHeightPx = 400,
            marginPx = 24,
        )
        assertEquals(-276f, translation, 0.01f)
    }

    @Test
    fun computeCardTranslationY_clampsLiftWhenCardTallerThanAvailableSpace() {
        val translation = ImeInsets.computeCardTranslationY(
            visibleTopPx = 0,
            visibleBottomPx = 240,
            cardTopOnScreenPx = 300f,
            cardHeightPx = 400,
            keyboardHeightPx = 400,
            marginPx = 24,
        )
        assertEquals(-276f, translation, 0.01f)
    }

    @Test
    fun computeCardTranslationY_returnsZeroWhenKeyboardHidden() {
        assertEquals(
            0f,
            ImeInsets.computeCardTranslationY(
                visibleTopPx = 0,
                visibleBottomPx = 1200,
                cardTopOnScreenPx = 400f,
                cardHeightPx = 200,
                keyboardHeightPx = 0,
                marginPx = 24,
            ),
            0.01f,
        )
    }

    @Test
    fun keyboardVisibleThreshold_isAtLeast80px() {
        assertTrue(ImeInsets.KEYBOARD_VISIBLE_THRESHOLD_PX >= 80)
    }
}
