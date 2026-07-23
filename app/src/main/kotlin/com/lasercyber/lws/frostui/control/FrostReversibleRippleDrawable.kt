package com.lasercyber.lws.frostui.control

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.Drawable
import androidx.annotation.VisibleForTesting

/**
 * Reversible radial hold ripple. Drawn on the hosting view's foreground; shape clip is via
 * [FrostViewOutlineChrome] and/or [clipPathProvider].
 */
class FrostReversibleRippleDrawable(
    appearance: FrostReversibleRippleAppearance,
) : Drawable() {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = appearance.rippleColor
    }
    private val boundsRect = Rect()
    private val clipPath = Path()

    /** When set, ripple is clipped to this path in view-local coordinates (0..width, 0..height). */
    var clipPathProvider: ((width: Int, height: Int) -> Path)? = null

    /** When set, overrides rectangular farthest-corner cover radius (e.g. trapezoid vertices). */
    var coverRadiusProvider: ((originX: Float, originY: Float, width: Int, height: Int) -> Float)? = null

    var originX: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                invalidateSelf()
            }
        }

    var originY: Float = 0f
        set(value) {
            if (field != value) {
                field = value
                invalidateSelf()
            }
        }

    var progress: Float = 0f
        set(value) {
            val clamped = value.coerceIn(0f, 1f)
            if (field != clamped) {
                field = clamped
                invalidateSelf()
            }
        }

    override fun draw(canvas: Canvas) {
        if (progress <= 0f || boundsRect.isEmpty) {
            return
        }
        val maxRadius = resolveCoverRadius()
        val provider = clipPathProvider
        if (provider != null) {
            clipPath.reset()
            clipPath.set(provider(boundsRect.width(), boundsRect.height()))
            canvas.save()
            canvas.clipPath(clipPath)
        }
        canvas.drawCircle(originX, originY, maxRadius * progress, paint)
        if (provider != null) {
            canvas.restore()
        }
    }

    private fun resolveCoverRadius(): Float {
        val custom = coverRadiusProvider?.invoke(
            originX,
            originY,
            boundsRect.width(),
            boundsRect.height(),
        )
        if (custom != null) {
            return custom
        }
        return frostReversibleRippleCoverRadius(
            boundsLeft = boundsRect.left.toFloat(),
            boundsTop = boundsRect.top.toFloat(),
            boundsRight = boundsRect.right.toFloat(),
            boundsBottom = boundsRect.bottom.toFloat(),
            originX = originX,
            originY = originY,
        )
    }

    override fun setAlpha(alpha: Int) {
        paint.alpha = alpha
        invalidateSelf()
    }

    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
        paint.colorFilter = colorFilter
        invalidateSelf()
    }

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT

    override fun onBoundsChange(bounds: Rect) {
        super.onBoundsChange(bounds)
        boundsRect.set(bounds)
        invalidateSelf()
    }

    @VisibleForTesting
    internal fun coverRadiusForTesting(): Float = resolveCoverRadius()
}
