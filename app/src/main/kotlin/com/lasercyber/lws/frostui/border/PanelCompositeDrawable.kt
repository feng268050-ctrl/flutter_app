package com.lasercyber.lws.frostui.border

import android.content.Context
import android.graphics.PixelFormat
import android.graphics.drawable.Drawable
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Canvas
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection

/** View-system fill + border overlay (replaces legacy combined panel drawable). */
class PanelCompositeDrawable(
    context: Context,
    private val fillSpec: PanelFillSpec?,
    private val borderSpec: PanelBorderSpec?,
    private val drawFill: Boolean,
    private val drawBorder: Boolean,
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
            if (drawFill && fillSpec != null) {
                with(PanelFillPainter) { drawPanelFill(fillSpec) }
            }
            if (drawBorder && borderSpec != null) {
                with(PanelBorderPainter) { drawPanelBorder(borderSpec) }
            }
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
            solid: Boolean = false,
            lightToneLocalizedBorder: Boolean = false,
            drawFill: Boolean = true,
            drawBorder: Boolean = true,
            cornerRadiusPx: Float = FrostDimens.cornerRadiusPx(context),
            borderWidthPx: Float = FrostDimens.defaultBorderWidthPx(context),
        ): PanelCompositeDrawable {
            val resolvedRadius = if (cornerRadiusPx >= 0f) {
                cornerRadiusPx
            } else {
                FrostDimens.cornerRadiusPx(context)
            }
            return PanelCompositeDrawable(
                context = context,
                fillSpec = if (drawFill) {
                    PanelFillPainter.panelFillSpec(
                        context = context,
                        lightTone = lightTone,
                        solid = solid,
                        cornerRadiusPx = resolvedRadius,
                        borderWidthPx = borderWidthPx,
                    )
                } else {
                    null
                },
                borderSpec = if (drawBorder) {
                    PanelBorderPainter.panelBorderSpec(
                        context = context,
                        gradientCenter = gradientCenter,
                        lightTone = lightTone,
                        lightToneLocalizedBorder = lightToneLocalizedBorder,
                        drawsFill = drawFill,
                        cornerRadiusPx = resolvedRadius,
                        borderWidthPx = borderWidthPx,
                    )
                } else {
                    null
                },
                drawFill = drawFill,
                drawBorder = drawBorder,
            )
        }
    }
}
