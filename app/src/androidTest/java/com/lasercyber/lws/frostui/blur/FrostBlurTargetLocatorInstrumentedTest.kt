package com.lasercyber.lws.frostui.blur

import android.view.View
import android.widget.FrameLayout
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FrostBlurTargetLocatorInstrumentedTest {

    @Test
    fun findLocalBlurTarget_returnsSiblingCaptureTarget() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = FrameLayout(context)
        val captureTarget = FrostCaptureTarget(context)
        captureTarget.addView(View(context))
        val clock = View(context)
        root.addView(captureTarget)
        root.addView(clock)

        val found = FrostBlurTargetLocator.findLocalBlurTarget(clock)
        assertNotNull(found)
        assert(found === captureTarget)
    }

    @Test
    fun findLocalBlurTarget_ignoresDescendantCaptureTarget() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val root = FrameLayout(context)
        val wrapper = FrameLayout(context)
        val captureTarget = FrostCaptureTarget(context)
        captureTarget.addView(View(context))
        wrapper.addView(captureTarget)
        root.addView(wrapper)

        val found = FrostBlurTargetLocator.findLocalBlurTarget(captureTarget)
        assertNull(found)
    }
}
