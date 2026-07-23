package com.lasercyber.lws.frostui.border

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection

/**
 * Foreground border for [com.lasercyber.lws.frostui.card.interop.FrostCardView].
 * Drawn above XML content so row backgrounds cannot obscure side strokes (legacy FrostedGlassCard).
 */
internal class FrostPanelBorderForeground(
    private val context: Context,
) : Drawable() {

    var borderSpec: PanelBorderSpec? = null
        set(value) {
            field = value
            invalidateSelf()
        }

    private val drawScope = CanvasDrawScope()
    private val density = Density(context.resources.displayMetrics.density)

    override fun draw(canvas: android.graphics.Canvas) {
        val spec = borderSpec ?: return
        if (bounds.isEmpty) {
            return
        }
        drawScope.draw(
            density = density,
            layoutDirection = LayoutDirection.Ltr,
            canvas = Canvas(canvas),
            size = Size(bounds.width().toFloat(), bounds.height().toFloat()),
        ) {
            with(PanelBorderPainter) { drawPanelBorder(spec) }
        }
    }

    override fun setAlpha(alpha: Int) = Unit

    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) = Unit

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
