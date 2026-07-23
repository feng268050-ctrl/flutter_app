package com.lasercyber.lws.frostui.border

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PanelBorderPainterInstrumentedTest {

    @Test
    fun borderGradientCenter_topLeftBottomRightHighlightsExpectedCorners() {
        val bitmap = drawBorder(BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT)
        assertBrighter(
            maxLuminance(bitmap, Rect(0, 0, 120, 100)),
            maxLuminance(bitmap, Rect(WIDTH - 120, 0, WIDTH, 100)),
        )
        assertBrighter(
            maxLuminance(bitmap, Rect(WIDTH - 120, HEIGHT - 100, WIDTH, HEIGHT)),
            maxLuminance(bitmap, Rect(0, HEIGHT - 100, 120, HEIGHT)),
        )
    }

    @Test
    fun borderGradientCenter_bottomLeftTopRightHighlightsExpectedCorners() {
        val bitmap = drawBorder(BorderGradientCenter.BOTTOM_LEFT_TOP_RIGHT)
        assertBrighter(
            maxLuminance(bitmap, Rect(0, HEIGHT - 100, 120, HEIGHT)),
            maxLuminance(bitmap, Rect(0, 0, 120, 100)),
        )
        assertBrighter(
            maxLuminance(bitmap, Rect(WIDTH - 120, 0, WIDTH, 100)),
            maxLuminance(bitmap, Rect(WIDTH - 120, HEIGHT - 100, WIDTH, HEIGHT)),
        )
    }

    @Test
    fun borderGradientCenter_topRightBottomLeftHighlightsExpectedCorners() {
        val bitmap = drawBorder(BorderGradientCenter.TOP_RIGHT_BOTTOM_LEFT)
        assertBrighter(
            maxLuminance(bitmap, Rect(WIDTH - 120, 0, WIDTH, 100)),
            maxLuminance(bitmap, Rect(WIDTH - 120, HEIGHT - 100, WIDTH, HEIGHT)),
        )
        assertBrighter(
            maxLuminance(bitmap, Rect(0, HEIGHT - 100, 120, HEIGHT)),
            maxLuminance(bitmap, Rect(0, 0, 120, 100)),
        )
    }

    @Test
    fun borderGradientCenter_topBottomHighlightsExpectedEdges() {
        val bitmap = drawBorder(BorderGradientCenter.TOP_BOTTOM)
        assertBrighter(
            maxLuminance(bitmap, Rect(120, 0, WIDTH - 120, 40)),
            maxLuminance(bitmap, Rect(0, 70, 40, HEIGHT - 70)),
        )
        assertBrighter(
            maxLuminance(bitmap, Rect(120, HEIGHT - 40, WIDTH - 120, HEIGHT)),
            maxLuminance(bitmap, Rect(WIDTH - 40, 70, WIDTH, HEIGHT - 70)),
        )
    }

    @Test
    fun fillOnly_cornerPixelsStayTransparent() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val bitmap = PanelBitmapRenderer.drawFillOnly(context, WIDTH, HEIGHT)
        assertTrue(Color.alpha(bitmap.getPixel(1, 1)) == 0)
        assertTrue(Color.alpha(bitmap.getPixel(WIDTH - 2, 1)) == 0)
        assertTrue(Color.alpha(bitmap.getPixel(1, HEIGHT - 2)) == 0)
        assertTrue(Color.alpha(bitmap.getPixel(WIDTH - 2, HEIGHT - 2)) == 0)
    }

    @Test
    fun borderGradientCenter_leftRightHighlightsExpectedEdges() {
        val bitmap = drawBorder(BorderGradientCenter.LEFT_RIGHT)
        assertBrighter(
            maxLuminance(bitmap, Rect(0, 70, 40, HEIGHT - 70)),
            maxLuminance(bitmap, Rect(120, 0, WIDTH - 120, 40)),
        )
        assertBrighter(
            maxLuminance(bitmap, Rect(WIDTH - 40, 70, WIDTH, HEIGHT - 70)),
            maxLuminance(bitmap, Rect(120, HEIGHT - 40, WIDTH - 120, HEIGHT)),
        )
    }

    private fun drawBorder(center: BorderGradientCenter): Bitmap {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        return PanelBitmapRenderer.drawBorderOnly(context, WIDTH, HEIGHT, center)
    }

    private fun maxLuminance(bitmap: Bitmap, region: Rect): Int {
        var max = 0
        for (y in region.top until region.bottom) {
            for (x in region.left until region.right) {
                val color = bitmap.getPixel(x, y)
                if (Color.alpha(color) == 0) {
                    continue
                }
                val luminance = (Color.red(color) + Color.green(color) + Color.blue(color)) / 3
                max = maxOf(max, luminance)
            }
        }
        return max
    }

    private fun assertBrighter(highlight: Int, shadow: Int) {
        assertTrue(
            "Expected highlight $highlight to exceed shadow $shadow",
            highlight >= shadow + MIN_LUMINANCE_DELTA,
        )
    }

    companion object {
        private const val WIDTH = 400
        private const val HEIGHT = 240
        private const val MIN_LUMINANCE_DELTA = 20
    }
}
