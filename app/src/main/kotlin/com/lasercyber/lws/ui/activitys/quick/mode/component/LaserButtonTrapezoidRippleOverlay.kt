package com.lasercyber.lws.ui.activitys.quick.mode.component

import android.content.Context
import android.graphics.Canvas
import android.graphics.Path
import android.graphics.drawable.Drawable
import android.util.AttributeSet
import android.view.View
import com.lasercyber.lws.frostui.control.FrostReversibleRippleDrawable
import com.lasercyber.lws.frostui.control.FrostRippleClipSurface

/**
 * Top layer for hold ripple; always clips in [onDraw] (foreground + clipToOutline is unreliable here).
 */
class LaserButtonTrapezoidRippleOverlay @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : View(context, attrs, defStyleAttr), FrostRippleClipSurface {

    private val clipPath = Path()
    private var holdRipple: FrostReversibleRippleDrawable? = null

    init {
        // Hit region is the trapezoid only; keep non-clickable so outside points
        // fall through instead of View#onTouchEvent claiming the full rect.
        isClickable = false
        isFocusable = false
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        setWillNotDraw(false)
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        if (w <= 0 || h <= 0) {
            return
        }
        clipPath.set(LaserButtonTrapezoidGeometry.path(w.toFloat(), h.toFloat()))
        holdRipple?.setBounds(0, 0, w, h)
    }

    override fun bindHoldRipple(drawable: FrostReversibleRippleDrawable) {
        holdRipple = drawable
        drawable.callback = this
        if (width > 0 && height > 0) {
            drawable.setBounds(0, 0, width, height)
        }
        invalidate()
    }

    override fun unbindHoldRipple() {
        holdRipple?.callback = null
        holdRipple = null
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val ripple = holdRipple ?: return
        if (ripple.progress <= 0f) {
            return
        }
        canvas.save()
        canvas.clipPath(clipPath)
        ripple.draw(canvas)
        canvas.restore()
    }

    override fun invalidateDrawable(who: Drawable) {
        invalidate()
    }
}
