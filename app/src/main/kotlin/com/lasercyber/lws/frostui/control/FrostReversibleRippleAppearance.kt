package com.lasercyber.lws.frostui.control

import android.content.Context
import com.lasercyber.lws.ui.R

/** Visual tokens for hold-confirm ripple; [cornerRadiusPx] is for Compose overlay only. */
data class FrostReversibleRippleAppearance(
    val rippleColor: Int,
    val cornerRadiusPx: Float,
    val holdScale: Float,
    val scaleAnimationDurationMs: Int,
    val fillDurationMs: Long,
) {
    companion object {
        fun fromContext(context: Context): FrostReversibleRippleAppearance {
            return FrostReversibleRippleAppearance(
                rippleColor = context.resources.getColor(R.color.frost_reversible_ripple_color, context.theme),
                cornerRadiusPx = context.resources.getDimension(R.dimen.engineer_toggle_btn_corner_radius),
                holdScale = FrostControlDefaults.REVERSIBLE_RIPPLE_HOLD_SCALE,
                scaleAnimationDurationMs = FrostControlDefaults.SLIDER_THUMB_EXPAND_DURATION_MS,
                fillDurationMs = context.resources.getInteger(R.integer.frost_reversible_ripple_fill_duration_ms).toLong(),
            )
        }
    }
}
