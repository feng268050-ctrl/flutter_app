package com.lasercyber.lws.frostui.blur

import android.graphics.Bitmap
import android.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNotSame
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FrostBitmapBlurInstrumentedTest {

    @Test
    fun blur_preservesDimensions() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val input = Bitmap.createBitmap(40, 30, Bitmap.Config.ARGB_8888).apply {
            eraseColor(Color.RED)
        }
        val output = FrostBitmapBlur.blur(context, input, blurRadius = 10, passes = 1)
        assertNotNull(output)
        assertEquals(40, output!!.width)
        assertEquals(30, output.height)
        if (output !== input) {
            output.recycle()
        }
        input.recycle()
    }

    @Test
    fun blur_forceCopy_doesNotRecycleInput() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val input = Bitmap.createBitmap(20, 20, Bitmap.Config.ARGB_8888).apply {
            eraseColor(Color.BLUE)
        }
        val output = FrostBitmapBlur.blur(context, input, blurRadius = 8, passes = 1)
        assertNotNull(output)
        assertFalse(input.isRecycled)
        if (output !== input) {
            assertNotSame(input, output)
            output.recycle()
        }
        input.recycle()
    }
}
