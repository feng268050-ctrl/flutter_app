package com.lasercyber.lws.ui.activitys.quick.mode.component

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LaserButtonTrapezoidGeometryTest {

    @Test
    fun centerOfBottomTrapezoidIsInside() {
        val width = 564f
        val height = 223f
        val v = LaserButtonTrapezoidGeometry.vertices(width, height)
        val centerX = (v.bottomLeftX + v.bottomRightX) / 2f
        val centerY = (v.topLeftY + v.bottomLeftY) / 2f
        assertTrue(LaserButtonTrapezoidGeometry.contains(centerX, centerY, width, height))
    }

    @Test
    fun topLeftCornerOutsideTrapezoidIsRejected() {
        assertFalse(LaserButtonTrapezoidGeometry.contains(10f, 10f, 564f, 223f))
    }

    @Test
    fun coverRadiusUsesFarthestTrapezoidVertex() {
        val width = 564f
        val height = 223f
        val v = LaserButtonTrapezoidGeometry.vertices(width, height)
        val originX = (v.bottomLeftX + v.bottomRightX) / 2f
        val originY = v.bottomLeftY - 10f
        val radius = LaserButtonTrapezoidGeometry.coverRadius(originX, originY, width, height)
        assertTrue(radius > 0f)
        assertTrue(radius < LaserButtonTrapezoidGeometry.coverRadius(0f, 0f, width, height))
    }
}
