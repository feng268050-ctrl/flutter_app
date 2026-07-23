package com.lasercyber.lws.frostui.control

/** View that draws [FrostReversibleRippleDrawable] clipped in [onDraw] (not View.foreground). */
interface FrostRippleClipSurface {
    fun bindHoldRipple(drawable: FrostReversibleRippleDrawable)

    fun unbindHoldRipple()
}
