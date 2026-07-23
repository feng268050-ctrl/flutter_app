package com.lasercyber.lws.frostui.clock

import android.content.Context
import androidx.annotation.ColorInt
import androidx.core.content.ContextCompat
import com.lasercyber.lws.ui.R

/** Design tokens for home clock glyph fill, frost overlays, and edge highlights. */
internal data class FrostClockAppearance(
    @ColorInt val fallbackFillTopColor: Int,
    @ColorInt val fallbackFillMidColor: Int,
    @ColorInt val fallbackFillBottomColor: Int,
    @ColorInt val frostOverlayColor: Int,
    @ColorInt val frostMilkColor: Int,
    @ColorInt val borderHighlightColor: Int,
    @ColorInt val borderMidColor: Int,
    @ColorInt val borderShadowColor: Int,
    val edgeStrokePx: Float,
) {
    companion object {
        fun fromContext(context: Context): FrostClockAppearance {
            fun withAlphaBoost(color: Int, minAlpha: Int): Int {
                val alpha = maxOf(minAlpha, color ushr 24 and 0xFF)
                return color and 0x00FFFFFF or (alpha shl 24)
            }
            return FrostClockAppearance(
                fallbackFillTopColor = withAlphaBoost(
                    ContextCompat.getColor(context, R.color.frost_clock_fill_top),
                    0x88,
                ),
                fallbackFillMidColor = withAlphaBoost(
                    ContextCompat.getColor(context, R.color.frost_clock_fill_mid),
                    0x78,
                ),
                fallbackFillBottomColor = withAlphaBoost(
                    ContextCompat.getColor(context, R.color.frost_clock_fill_bottom),
                    0x68,
                ),
                frostOverlayColor = ContextCompat.getColor(context, R.color.frost_clock_warm_overlay),
                frostMilkColor = ContextCompat.getColor(context, R.color.frost_clock_milk_overlay),
                borderHighlightColor = ContextCompat.getColor(
                    context,
                    R.color.frost_clock_border_highlight,
                ),
                borderMidColor = ContextCompat.getColor(context, R.color.frost_clock_border_mid),
                borderShadowColor = ContextCompat.getColor(context, R.color.frost_clock_border_shadow),
                edgeStrokePx = context.resources.displayMetrics.density * 1.25f,
            )
        }
    }
}
