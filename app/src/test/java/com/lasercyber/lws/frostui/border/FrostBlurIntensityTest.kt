package com.lasercyber.lws.frostui.border

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized

class FrostBlurIntensityTest {

    @Test
    fun blurRadiusLevels() {
        assertEquals(8f, FrostBlurIntensity.MINIMAL.blurRadius, 0.01f)
        assertEquals(12f, FrostBlurIntensity.LOW.blurRadius, 0.01f)
        assertEquals(20f, FrostBlurIntensity.MIDDLE.blurRadius, 0.01f)
        assertEquals(23f, FrostBlurIntensity.HIGH.blurRadius, 0.01f)
        assertEquals(25f, FrostBlurIntensity.EXTREME.blurRadius, 0.01f)
        assertEquals(0f, FrostBlurIntensity.TRANSPARENT.blurRadius, 0.01f)
        assertEquals(0f, FrostBlurIntensity.SOLID.blurRadius, 0.01f)
    }

    @Test
    fun fromXmlValueMapsAttrEnums() {
        assertEquals(FrostBlurIntensity.LOW, FrostBlurIntensity.fromXmlValue(0))
        assertEquals(FrostBlurIntensity.MIDDLE, FrostBlurIntensity.fromXmlValue(1))
        assertEquals(FrostBlurIntensity.HIGH, FrostBlurIntensity.fromXmlValue(2))
        assertEquals(FrostBlurIntensity.EXTREME, FrostBlurIntensity.fromXmlValue(3))
        assertEquals(FrostBlurIntensity.TRANSPARENT, FrostBlurIntensity.fromXmlValue(4))
        assertEquals(FrostBlurIntensity.SOLID, FrostBlurIntensity.fromXmlValue(5))
        assertEquals(FrostBlurIntensity.MINIMAL, FrostBlurIntensity.fromXmlValue(6))
        assertEquals(FrostBlurIntensity.MIDDLE, FrostBlurIntensity.fromXmlValue(99))
    }

    @Test
    fun fillAndBlurModes() {
        assertFalse(FrostBlurIntensity.TRANSPARENT.drawsFill())
        assertFalse(FrostBlurIntensity.TRANSPARENT.usesBackdropBlur())
        assertTrue(FrostBlurIntensity.SOLID.drawsFill())
        assertTrue(FrostBlurIntensity.SOLID.usesSolidFill())
        assertFalse(FrostBlurIntensity.SOLID.usesBackdropBlur())
        assertTrue(FrostBlurIntensity.MIDDLE.usesBackdropBlur())
    }

    @RunWith(Parameterized::class)
    class LegacyDevParity(
        private val intensity: FrostBlurIntensity,
        private val overlayAlpha: Int,
        private val blurRadius: Float,
        private val drawsFill: Boolean,
        private val usesBackdropBlur: Boolean,
        private val usesSolidFill: Boolean,
        private val gaussianRadiusPx: Int,
        private val stackBlurRadiusPx: Int,
    ) {
        @Test
        fun matchesFrostedGlassBlurIntensityOnDev() {
            assertEquals(overlayAlpha, intensity.legacyOverlayAlpha())
            assertEquals(blurRadius, intensity.blurRadius, 0.01f)
            assertEquals(drawsFill, intensity.drawsFill())
            assertEquals(usesBackdropBlur, intensity.usesBackdropBlur())
            assertEquals(usesSolidFill, intensity.usesSolidFill())
            assertEquals(gaussianRadiusPx, intensity.dialogGaussianBlurRadiusPx())
            assertEquals(stackBlurRadiusPx, intensity.stackBlurRadiusPx())
            assertEquals(1, intensity.stackBlurPasses())
        }

        companion object {
            @JvmStatic
            @Parameterized.Parameters(name = "{0}")
            fun data(): Collection<Array<Any>> = listOf(
                arrayOf(FrostBlurIntensity.TRANSPARENT, 0, 0f, false, false, false, 0, 0),
                arrayOf(FrostBlurIntensity.MINIMAL, 0x0C, 8f, true, true, false, 8, 8),
                arrayOf(FrostBlurIntensity.LOW, 0x15, 12f, true, true, false, 12, 12),
                arrayOf(FrostBlurIntensity.MIDDLE, 0x30, 20f, true, true, false, 20, 20),
                arrayOf(FrostBlurIntensity.HIGH, 0x40, 23f, true, true, false, 23, 23),
                arrayOf(FrostBlurIntensity.EXTREME, 0x50, 25f, true, true, false, 25, 25),
                arrayOf(FrostBlurIntensity.SOLID, 0xFF, 0f, true, false, true, 0, 0),
            )
        }
    }
}
