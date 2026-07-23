package com.lasercyber.lws.frostui.blur

import org.junit.Assert.assertEquals
import org.junit.Test

class FrostBackdropDisplayTest {

    @Test
    fun fullscreenOffsetPx_alignsContentOriginToCardOrigin() {
        val (offsetX, offsetY) = FrostBackdropDisplay.fullscreenOffsetPx(
            cardX = 50,
            cardY = 80,
            contentX = 10,
            contentY = 20,
            hasContent = true,
        )
        assertEquals(-40f, offsetX, 0.01f)
        assertEquals(-60f, offsetY, 0.01f)
    }

    @Test
    fun fullscreenOffsetPx_withoutContent_isZero() {
        val (offsetX, offsetY) = FrostBackdropDisplay.fullscreenOffsetPx(
            cardX = 50,
            cardY = 80,
            contentX = 0,
            contentY = 0,
            hasContent = false,
        )
        assertEquals(0f, offsetX, 0.01f)
        assertEquals(0f, offsetY, 0.01f)
    }
}
