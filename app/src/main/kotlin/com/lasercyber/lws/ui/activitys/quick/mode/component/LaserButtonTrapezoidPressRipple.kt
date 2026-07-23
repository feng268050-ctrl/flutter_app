package com.lasercyber.lws.ui.activitys.quick.mode.component

import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorFilter
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.drawable.Drawable
import android.graphics.drawable.RippleDrawable
import com.lasercyber.lws.ui.R

object LaserButtonTrapezoidPressRipple {
    @JvmStatic
    fun create(context: Context): RippleDrawable {
        val color = ColorStateList.valueOf(
            context.resources.getColor(R.color.frost_reversible_ripple_color, context.theme),
        )
        return RippleDrawable(color, null, TrapezoidMaskDrawable())
    }
}

/** Ripple mask matching [LaserButtonTrapezoidGeometry]. */
private class TrapezoidMaskDrawable : Drawable() {
    private val path = Path()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }

    override fun draw(canvas: Canvas) {
        canvas.drawPath(path, paint)
    }

    override fun onBoundsChange(bounds: Rect) {
        super.onBoundsChange(bounds)
        if (bounds.isEmpty) {
            path.reset()
            return
        }
        path.set(
            LaserButtonTrapezoidGeometry.path(
                bounds.width().toFloat(),
                bounds.height().toFloat(),
            ),
        )
        path.offset(bounds.left.toFloat(), bounds.top.toFloat())
    }

    override fun setAlpha(alpha: Int) = Unit

    override fun setColorFilter(colorFilter: ColorFilter?) = Unit

    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
