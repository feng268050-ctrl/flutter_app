package com.lasercyber.lws.frostui.card.interop

import com.lasercyber.lws.frostui.border.FrostBlurIntensity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FrostCardAttrsTest {

    @Test
    fun resolveCardBackgroundTransparent() {
        assertEquals(
            FrostBlurIntensity.TRANSPARENT,
            FrostCardAttrs.resolveCardBackground("transparent", FrostBlurIntensity.MIDDLE),
        )
    }

    @Test
    fun resolveCardBackgroundFrostedFromTransparent() {
        assertEquals(
            FrostBlurIntensity.MIDDLE,
            FrostCardAttrs.resolveCardBackground("frosted", FrostBlurIntensity.TRANSPARENT),
        )
    }

    @Test
    fun resolveCardBackgroundFrostedKeepsCurrentWhenNotTransparent() {
        assertEquals(
            FrostBlurIntensity.HIGH,
            FrostCardAttrs.resolveCardBackground("frosted", FrostBlurIntensity.HIGH),
        )
    }

    @Test
    fun blurIntensityDrawsFillForNonTransparent() {
        assertTrue(FrostBlurIntensity.MIDDLE.drawsFill())
        assertFalse(FrostBlurIntensity.TRANSPARENT.drawsFill())
    }
}
