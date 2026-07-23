package com.lasercyber.lws.frostui.control

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FrostStatusIndicatorLogicTest {

    private val appearance = FrostStatusIndicatorAppearance(
        indicatorSize = 36.dp,
        strokeWidth = 2.dp,
        dotRadius = 5.dp,
        idleRingColor = Color.Gray,
        inProgressDotColor = Color.Yellow,
        successColor = Color.Green,
        failureColor = Color.Red,
        glyphColor = Color.White,
    )

    @Test
    fun idleStateShowsGrayBackgroundOnly() {
        val resolved = resolveFrostStatusAppearance(FrostStatusState.Idle, FrostStatusVariant.Icon, appearance)
        assertEquals(appearance.idleRingColor, resolved.backgroundColor)
        assertNull(resolved.dotColor)
        assertFalse(resolved.showCheckmark)
        assertFalse(resolved.showCross)
    }

    @Test
    fun inProgressShowsYellowDotRegardlessOfVariant() {
        val dot = resolveFrostStatusAppearance(FrostStatusState.InProgress, FrostStatusVariant.Dot, appearance)
        val icon = resolveFrostStatusAppearance(FrostStatusState.InProgress, FrostStatusVariant.Icon, appearance)
        assertEquals(appearance.inProgressDotColor, dot.dotColor)
        assertEquals(appearance.inProgressDotColor, icon.dotColor)
        assertEquals(appearance.idleRingColor, dot.backgroundColor)
    }

    @Test
    fun successDotVariantColorsCenterDotOnly() {
        val resolved = resolveFrostStatusAppearance(FrostStatusState.Success, FrostStatusVariant.Dot, appearance)
        assertEquals(appearance.idleRingColor, resolved.backgroundColor)
        assertEquals(appearance.successColor, resolved.dotColor)
        assertFalse(resolved.showCheckmark)
    }

    @Test
    fun failureIconVariantColorsBackgroundAndDrawsCross() {
        val resolved = resolveFrostStatusAppearance(FrostStatusState.Failure, FrostStatusVariant.Icon, appearance)
        assertEquals(appearance.failureColor, resolved.backgroundColor)
        assertNull(resolved.dotColor)
        assertTrue(resolved.showCross)
        assertFalse(resolved.showCheckmark)
    }

    @Test
    fun successIconVariantColorsBackgroundAndDrawsCheckmark() {
        val resolved = resolveFrostStatusAppearance(FrostStatusState.Success, FrostStatusVariant.Icon, appearance)
        assertEquals(appearance.successColor, resolved.backgroundColor)
        assertNull(resolved.dotColor)
        assertTrue(resolved.showCheckmark)
        assertFalse(resolved.showCross)
    }

    @Test
    fun failureDotVariantColorsCenterDotOnly() {
        val resolved = resolveFrostStatusAppearance(FrostStatusState.Failure, FrostStatusVariant.Dot, appearance)
        assertEquals(appearance.idleRingColor, resolved.backgroundColor)
        assertEquals(appearance.failureColor, resolved.dotColor)
        assertFalse(resolved.showCross)
        assertFalse(resolved.showCheckmark)
    }

    @Test
    fun inProgressIconVariantIgnoresCheckAndCross() {
        val resolved = resolveFrostStatusAppearance(FrostStatusState.InProgress, FrostStatusVariant.Icon, appearance)
        assertEquals(appearance.inProgressDotColor, resolved.dotColor)
        assertFalse(resolved.showCheckmark)
        assertFalse(resolved.showCross)
    }

    @Test
    fun idleDotAndIconVariantsMatch() {
        val dot = resolveFrostStatusAppearance(FrostStatusState.Idle, FrostStatusVariant.Dot, appearance)
        val icon = resolveFrostStatusAppearance(FrostStatusState.Idle, FrostStatusVariant.Icon, appearance)
        assertEquals(dot, icon)
    }

    @Test
    fun backgroundRadiusNearlyFillsIndicatorTile() {
        assertEquals(17f, frostStatusBackgroundRadiusPx(indicatorSizePx = 36f), 0.01f)
    }

    @Test
    fun dotRadiusPassesThroughPxValue() {
        assertEquals(5f, frostStatusDotRadiusPx(5f), 0.01f)
    }
}
