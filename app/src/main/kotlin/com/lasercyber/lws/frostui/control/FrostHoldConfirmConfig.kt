package com.lasercyber.lws.frostui.control

import android.graphics.Path
import android.graphics.drawable.Drawable
import android.graphics.drawable.RippleDrawable
import android.view.View
import com.lasercyber.lws.ui.R

/** Optional overrides for hold-confirm chrome and hit region. */
data class FrostHoldConfirmConfig(
    val applyViewClip: ((View) -> Unit)?,
    val hitTest: ((x: Float, y: Float, view: View) -> Boolean)?,
    val rippleClipPath: ((width: Int, height: Int) -> Path)?,
    val holdScaleEnabled: Boolean = true,
    val coverRadiusProvider: ((originX: Float, originY: Float, width: Int, height: Int) -> Float)? = null,
    val pressRippleProvider: ((View) -> Drawable)? = null,
) {
    companion object {
        /** Rounded-rect laser/toggle hold confirm: radial ripple only, no view scale. */
        @JvmStatic
        fun roundedRect(): FrostHoldConfirmConfig = FrostHoldConfirmConfig(
            applyViewClip = { view ->
                FrostViewOutlineChrome.applyRoundedClip(view, R.dimen.frost_reversible_ripple_corner_radius)
            },
            hitTest = null,
            rippleClipPath = null,
            holdScaleEnabled = false,
            pressRippleProvider = { view -> FrostPressRipple.createRoundedRect(view) },
        )

        /** Trapezoid quick-mode laser button: same radial ripple, clipped to trapezoid; no view scale. */
        @JvmStatic
        fun trapezoidRippleOnly(
            applyViewClip: ((View) -> Unit)?,
            hitTest: (x: Float, y: Float, view: View) -> Boolean,
            rippleClipPath: ((width: Int, height: Int) -> Path)?,
            coverRadiusProvider: (originX: Float, originY: Float, width: Int, height: Int) -> Float,
            pressRippleProvider: (View) -> Drawable,
        ): FrostHoldConfirmConfig = FrostHoldConfirmConfig(
            applyViewClip = applyViewClip,
            hitTest = hitTest,
            rippleClipPath = rippleClipPath,
            holdScaleEnabled = false,
            coverRadiusProvider = coverRadiusProvider,
            pressRippleProvider = pressRippleProvider,
        )
    }
}
