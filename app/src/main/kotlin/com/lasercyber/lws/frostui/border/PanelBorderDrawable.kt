package com.lasercyber.lws.frostui.border

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection

/** View-system border overlay aligned with [PanelBorderPainter]. */
class PanelBorderDrawable(
    context: Context,
    private val spec: PanelBorderSpec,
) : Drawable() {

    private val drawScope = CanvasDrawScope()
    private val density = Density(context.resources.displayMetrics.density)

    override fun draw(canvas: android.graphics.Canvas) {
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

    companion object {
        @JvmStatic
        fun create(
            context: Context,
            gradientCenter: BorderGradientCenter = BorderGradientCenter.TOP_LEFT_BOTTOM_RIGHT,
            lightTone: Boolean = false,
            primary: Boolean = false,
            lightToneLocalizedBorder: Boolean = false,
            drawsFill: Boolean = false,
            cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
            borderWidthPx: Float = FrostDimens.defaultBorderWidthPx(context),
        ): PanelBorderDrawable {
            val resolvedRadius = if (cornerRadiusPx >= 0f) {
                cornerRadiusPx
            } else {
                FrostDimens.cornerRadiusPx(context)
            }
            return PanelBorderDrawable(
                context = context,
                spec = PanelBorderPainter.panelBorderSpec(
                    context = context,
                    gradientCenter = gradientCenter,
                    lightTone = lightTone,
                    primary = primary,
                    lightToneLocalizedBorder = lightToneLocalizedBorder,
                    drawsFill = drawsFill,
                    cornerRadiusPx = resolvedRadius,
                    borderWidthPx = borderWidthPx,
                ),
            )
        }
    }
}
