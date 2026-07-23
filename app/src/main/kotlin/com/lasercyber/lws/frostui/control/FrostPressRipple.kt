package com.lasercyber.lws.frostui.control

import android.graphics.drawable.RippleDrawable
import android.view.View
import com.lasercyber.lws.frostui.button.interop.FrostButtonTileRipple
import com.lasercyber.lws.ui.R

/** Standard (non-reversible) press ripple for hold-confirm disable / immediate taps. */
object FrostPressRipple {
    @JvmStatic
    fun createRoundedRect(view: View): RippleDrawable {
        val radius = view.resources.getDimension(R.dimen.frost_reversible_ripple_corner_radius)
        return FrostButtonTileRipple.createTileRippleForeground(radius)
    }
}
