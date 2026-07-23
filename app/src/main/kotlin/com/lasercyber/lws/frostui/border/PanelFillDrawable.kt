package com.lasercyber.lws.frostui.border

import android.content.Context
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable
import androidx.compose.ui.graphics.toArgb
import kotlin.math.max
import kotlin.math.min

/** View-system fill overlay aligned with [PanelFillPainter] (replaces legacy fill-only panel drawable). */
class PanelFillDrawable(
    private val spec: PanelFillSpec,
) : Drawable() {

    private val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val clipPath = Path()
    private val drawRect = RectF()

    override fun draw(canvas: Canvas) {
        if (getBounds().isEmpty()) {
            return
        }

        val inset = spec.borderWidthPx * 0.5f
        drawRect.set(getBounds())
        drawRect.inset(inset, inset)

        val resolvedCornerRadius = if (spec.cornerRadiusPx < 0f) {
            min(drawRect.width(), drawRect.height()) * 0.5f
        } else {
            spec.cornerRadiusPx
        }
        val strokeRadius = max(0f, resolvedCornerRadius - inset)

        clipPath.reset()
        clipPath.addRoundRect(drawRect, strokeRadius, strokeRadius, Path.Direction.CW)
        fillPaint.shader = LinearGradient(
            drawRect.left,
            drawRect.top,
            drawRect.left,
            drawRect.bottom,
            intArrayOf(
                spec.topColor.toArgb(),
                spec.midColor.toArgb(),
                spec.bottomColor.toArgb(),
            ),
            FILL_STOPS,
            Shader.TileMode.CLAMP,
        )
        canvas.drawPath(clipPath, fillPaint)
        fillPaint.shader = null
    }

    override fun setAlpha(alpha: Int) {
        fillPaint.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
        fillPaint.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

    override fun onBoundsChange(bounds: Rect) {
        super.onBoundsChange(bounds)
        invalidateSelf()
    }

    companion object {
        private val FILL_STOPS = floatArrayOf(0f, 0.45f, 1f)

        fun create(
            context: Context,
            cornerRadiusPx: Float,
            lightTone: Boolean = false,
            solid: Boolean = false,
            primary: Boolean = false,
        ): PanelFillDrawable {
            val resolvedRadius = if (cornerRadiusPx >= 0f) {
                cornerRadiusPx
            } else {
                FrostDimens.cornerRadiusPx(context)
            }
            return PanelFillDrawable(
                PanelFillPainter.panelFillSpec(
                    context = context,
                    lightTone = lightTone,
                    solid = solid,
                    primary = primary,
                    cornerRadiusPx = resolvedRadius,
                ),
            )
        }
    }
}
