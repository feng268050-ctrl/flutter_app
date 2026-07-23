package com.lasercyber.lws.frostui.clock.interop

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.util.AttributeSet
import android.util.TypedValue
import android.view.View
import androidx.core.content.withStyledAttributes
import com.lasercyber.lws.frostui.blur.FrostBitmapBlur
import com.lasercyber.lws.frostui.blur.FrostBlurTargetLocator
import com.lasercyber.lws.frostui.blur.FrostCaptureTarget
import com.lasercyber.lws.frostui.clock.FrostClockAppearance
import com.lasercyber.lws.frostui.clock.FrostGlyphBlurRenderer
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.Future
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Home hero clock: backdrop captured from a sibling [FrostCaptureTarget], blurred via RenderScript registry,
 * drawn inside glyph paths. Refreshes on minute change only (not every second).
 */
class FrostHomeClockView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
) : View(context, attrs) {

    private val appearance = FrostClockAppearance.fromContext(context)
    private var textSizePx = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_SP,
        DEFAULT_TEXT_SIZE_SP,
        resources.displayMetrics,
    )
    private val renderer = FrostGlyphBlurRenderer(appearance, textSizePx)
    private val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())

    private var blurredBackdrop: Bitmap? = null
    private var backdropCaptureWidth = 0
    private var backdropCaptureHeight = 0
    private var backdropBlurEnabled = false
    private var lastRenderedMinuteKey = Int.MIN_VALUE
    private var blurFuture: Future<*>? = null
    private var captureGeneration = 0

    init {
        context.withStyledAttributes(attrs, intArrayOf(android.R.attr.textSize)) {
            if (hasValue(0)) {
                textSizePx = getDimension(0, textSizePx)
            }
        }
    }

    /** Primary API for [MainActivity]: updates only when [HH:mm] changes. */
    fun updateTime(millis: Long) {
        val minuteKey = minuteKey(millis)
        val timeText = timeFormat.format(Date(millis))
        if (minuteKey == lastRenderedMinuteKey && renderer.text.toString() == timeText) {
            return
        }
        lastRenderedMinuteKey = minuteKey
        applyTextChange(timeText, requestCapture = true)
    }

    fun setText(value: CharSequence?) {
        val next = value?.toString().orEmpty()
        if (renderer.text.toString() == next) {
            return
        }
        applyTextChange(next, requestCapture = false)
    }

    fun getText(): CharSequence = renderer.text

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        backdropBlurEnabled = resolveBackdropContent() != null
        if (renderer.text.isNotEmpty()) {
            requestBackdropCapture(force = true)
        }
    }

    override fun onDetachedFromWindow() {
        blurFuture?.cancel(false)
        blurFuture = null
        recycleBackdrop()
        backdropBlurEnabled = false
        super.onDetachedFromWindow()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        renderer.invalidateGlyphPath()
        if (w != backdropCaptureWidth || h != backdropCaptureHeight) {
            recycleBackdrop()
            if (w > 0 && h > 0 && backdropBlurEnabled) {
                requestBackdropCapture(force = true)
            }
        }
    }

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val (desiredWidth, desiredHeight) = renderer.measureText(
            renderer.text,
            paddingLeft,
            paddingRight,
            paddingTop,
            paddingBottom,
        )
        setMeasuredDimension(
            resolveSize(desiredWidth, widthMeasureSpec),
            resolveSize(desiredHeight, heightMeasureSpec),
        )
    }

    override fun onDraw(canvas: Canvas) {
        if (renderer.text.isEmpty()) {
            return
        }
        val width = width
        val height = height
        if (backdropBlurEnabled && blurredBackdrop != null && !blurredBackdrop!!.isRecycled) {
            renderer.drawBackdropBlurredGlyphs(canvas, blurredBackdrop!!, width, height)
        } else {
            renderer.drawFallbackGlyphs(canvas, width, height)
        }
    }

    private fun applyTextChange(timeText: String, requestCapture: Boolean) {
        renderer.text = timeText
        renderer.invalidateGlyphPath()
        requestLayout()
        if (requestCapture && backdropBlurEnabled) {
            requestBackdropCapture(force = true)
        } else {
            invalidate()
        }
    }

    private fun requestBackdropCapture(force: Boolean) {
        val width = width
        val height = height
        if (width <= 0 || height <= 0) {
            return
        }
        if (!force
            && blurredBackdrop != null
            && !blurredBackdrop!!.isRecycled
            && width == backdropCaptureWidth
            && height == backdropCaptureHeight
        ) {
            invalidate()
            return
        }
        val backdropContent = resolveBackdropContent() ?: run {
            invalidate()
            return
        }
        val blurTarget = resolveBlurTarget() ?: run {
            invalidate()
            return
        }

        val viewLoc = IntArray(2)
        val targetLoc = IntArray(2)
        getLocationOnScreen(viewLoc)
        blurTarget.getLocationOnScreen(targetLoc)
        val offsetX = viewLoc[0] - targetLoc[0]
        val offsetY = viewLoc[1] - targetLoc[1]

        val scale = 1f / BACKDROP_CAPTURE_SCALE_DIVISOR
        val scaledWidth = max(1, (width * scale).roundToInt())
        val scaledHeight = max(1, (height * scale).roundToInt())

        val snapshot = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)
        val snapshotCanvas = Canvas(snapshot)
        snapshotCanvas.scale(scale, scale)
        snapshotCanvas.translate(-offsetX.toFloat(), -offsetY.toFloat())
        backdropContent.draw(snapshotCanvas)

        val generation = ++captureGeneration
        blurFuture?.cancel(false)
        blurFuture = FrostBitmapBlur.blurAsync(
            context = context,
            bitmap = snapshot,
            blurRadius = FrostBitmapBlur.DEFAULT_RADIUS,
            passes = FrostBitmapBlur.CLOCK_BLUR_PASSES,
            sampleFactor = 1f,
            onSuccess = { blurred ->
                if (!isAttachedToWindow || generation != captureGeneration) {
                    if (!blurred.isRecycled) {
                        blurred.recycle()
                    }
                    return@blurAsync
                }
                recycleBackdrop()
                blurredBackdrop = blurred
                backdropCaptureWidth = width
                backdropCaptureHeight = height
                invalidate()
            },
            onFailed = {
                if (generation == captureGeneration && !snapshot.isRecycled) {
                    snapshot.recycle()
                }
                if (isAttachedToWindow) {
                    invalidate()
                }
            },
        )
    }

    private fun resolveBlurTarget(): FrostCaptureTarget? = FrostBlurTargetLocator.findLocalBlurTarget(this)

    private fun resolveBackdropContent(): View? {
        val captureTarget = resolveBlurTarget() ?: return null
        if (captureTarget.childCount == 0) {
            return null
        }
        return captureTarget.getChildAt(0)
    }

    private fun recycleBackdrop() {
        blurredBackdrop?.let { bitmap ->
            if (!bitmap.isRecycled) {
                bitmap.recycle()
            }
        }
        blurredBackdrop = null
        backdropCaptureWidth = 0
        backdropCaptureHeight = 0
    }

    private fun minuteKey(millis: Long): Int {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        return calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
    }

    private companion object {
        const val DEFAULT_TEXT_SIZE_SP = 150f
        const val BACKDROP_CAPTURE_SCALE_DIVISOR = 5f
    }
}
