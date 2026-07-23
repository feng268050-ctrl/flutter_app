package com.lasercyber.lws.frostui.clock

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import kotlin.math.roundToInt

/**
 * Glyph-path drawing for the home clock: blurred backdrop clipped to text paths,
 * frost overlays, gradient fallback, and edge highlights.
 */
internal class FrostGlyphBlurRenderer(
    private val appearance: FrostClockAppearance,
    private val textSizePx: Float,
) {
    private val typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
    private val glyphPath = Path()
    private val charGlyphPath = Path()
    private val glyphMatrix = Matrix()
    private val glyphPathPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        textSize = textSizePx
        this.typeface = this@FrostGlyphBlurRenderer.typeface
        textAlign = Paint.Align.LEFT
    }
    private val frostOverlayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = appearance.frostOverlayColor
    }
    private val frostMilkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        color = appearance.frostMilkColor
    }
    private val backdropPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val fallbackFillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        configureTextPaint(this)
        style = Paint.Style.FILL
    }
    private val edgeShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
        color = withAlphaBoost(appearance.borderShadowColor, 0x55)
    }
    private val edgeHighlightPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
    }
    private val glyphBounds = RectF()
    private val srcRect = Rect()
    private val dstRect = RectF()

    var text: CharSequence = ""
        set(value) {
            if (field.toString() != value.toString()) {
                field = value
                glyphPathDirty = true
            }
        }

    private var glyphPathDirty = true

    fun invalidateGlyphPath() {
        glyphPathDirty = true
    }

    fun measureText(text: CharSequence, paddingLeft: Int, paddingRight: Int, paddingTop: Int, paddingBottom: Int): Pair<Int, Int> {
        val value = text.toString()
        val textWidth = fallbackFillPaint.measureText(value)
        val metrics = fallbackFillPaint.fontMetrics
        val textHeight = (metrics.descent - metrics.ascent) * TEXT_VERTICAL_SCALE
        val width = textWidth.roundToInt() + paddingLeft + paddingRight
        val height = textHeight.roundToInt() + paddingTop + paddingBottom
        return width to height
    }

    fun drawBackdropBlurredGlyphs(canvas: Canvas, blurredBackdrop: Bitmap, viewWidth: Int, viewHeight: Int) {
        rebuildGlyphPathIfNeeded(viewWidth, viewHeight)
        if (glyphPath.isEmpty() || blurredBackdrop.isRecycled) {
            drawFallbackGlyphs(canvas, viewWidth, viewHeight)
            return
        }
        srcRect.set(0, 0, blurredBackdrop.width, blurredBackdrop.height)
        dstRect.set(0f, 0f, viewWidth.toFloat(), viewHeight.toFloat())
        canvas.save()
        canvas.clipPath(glyphPath)
        canvas.drawBitmap(blurredBackdrop, srcRect, dstRect, backdropPaint)
        canvas.drawRect(dstRect, frostOverlayPaint)
        canvas.drawRect(dstRect, frostMilkPaint)
        canvas.restore()
        drawGlyphEdgeHighlight(canvas, viewWidth, viewHeight)
    }

    fun drawFallbackGlyphs(canvas: Canvas, viewWidth: Int, viewHeight: Int) {
        if (text.isEmpty()) {
            return
        }
        val metrics = computeGlyphMetrics(viewWidth, viewHeight)
        val value = text.toString()
        canvas.save()
        canvas.scale(1f, TEXT_VERTICAL_SCALE, metrics.centerX, metrics.centerY)
        fallbackFillPaint.shader = LinearGradient(
            metrics.centerX,
            metrics.top,
            metrics.centerX,
            metrics.bottom,
            intArrayOf(
                appearance.fallbackFillTopColor,
                appearance.fallbackFillMidColor,
                appearance.fallbackFillBottomColor,
            ),
            floatArrayOf(0f, 0.42f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawText(value, metrics.centerX, metrics.centerY, fallbackFillPaint)
        fallbackFillPaint.shader = null
        canvas.restore()
        drawGlyphEdgeHighlight(canvas, viewWidth, viewHeight)
    }

    private fun drawGlyphEdgeHighlight(canvas: Canvas, viewWidth: Int, viewHeight: Int) {
        edgeShadowPaint.strokeWidth = appearance.edgeStrokePx * 0.72f
        edgeHighlightPaint.strokeWidth = appearance.edgeStrokePx
        forEachGlyphPath(viewWidth, viewHeight) { path, bounds ->
            canvas.drawPath(path, edgeShadowPaint)
            edgeHighlightPaint.shader = createLightToneEdgeGradient(bounds)
            canvas.drawPath(path, edgeHighlightPaint)
        }
        edgeHighlightPaint.shader = null
    }

    private fun createLightToneEdgeGradient(bounds: RectF): LinearGradient {
        val bright = withAlphaBoost(appearance.borderHighlightColor, 0xCC)
        val midHighlight = withAlphaBoost(appearance.borderMidColor, 0xB0)
        val shadow = withAlphaBoost(appearance.borderShadowColor, 0x88)
        return LinearGradient(
            bounds.left,
            bounds.top,
            bounds.right,
            bounds.bottom,
            intArrayOf(bright, midHighlight, shadow, midHighlight, bright),
            floatArrayOf(0f, 0.22f, 0.5f, 0.78f, 1f),
            Shader.TileMode.CLAMP,
        )
    }

    private fun rebuildGlyphPathIfNeeded(viewWidth: Int, viewHeight: Int) {
        if (!glyphPathDirty && !glyphPath.isEmpty()) {
            return
        }
        glyphPath.reset()
        val value = text.toString()
        if (value.isEmpty() || viewWidth <= 0 || viewHeight <= 0) {
            glyphPathDirty = false
            return
        }
        forEachGlyphPath(viewWidth, viewHeight) { path, _ -> glyphPath.addPath(path) }
        glyphPathDirty = false
    }

    private fun forEachGlyphPath(
        viewWidth: Int,
        viewHeight: Int,
        callback: (Path, RectF) -> Unit,
    ) {
        val value = text.toString()
        if (value.isEmpty() || viewWidth <= 0 || viewHeight <= 0) {
            return
        }
        val metrics = computeGlyphMetrics(viewWidth, viewHeight)
        val advances = FloatArray(value.length)
        glyphPathPaint.getTextWidths(value, advances)
        var totalWidth = 0f
        for (advance in advances) {
            totalWidth += advance
        }
        var x = metrics.centerX - totalWidth / 2f
        glyphMatrix.setScale(1f, TEXT_VERTICAL_SCALE, metrics.centerX, metrics.centerY)
        for (i in value.indices) {
            charGlyphPath.reset()
            glyphPathPaint.getTextPath(value, i, i + 1, x, metrics.centerY, charGlyphPath)
            charGlyphPath.transform(glyphMatrix)
            charGlyphPath.computeBounds(glyphBounds, true)
            if (!glyphBounds.isEmpty()) {
                callback(charGlyphPath, RectF(glyphBounds))
            }
            x += advances[i]
        }
    }

    private fun computeGlyphMetrics(viewWidth: Int, viewHeight: Int): GlyphMetrics {
        val centerX = viewWidth / 2f
        val centerY = (viewHeight
            - fallbackFillPaint.ascent() * TEXT_VERTICAL_SCALE
            - fallbackFillPaint.descent() * TEXT_VERTICAL_SCALE) / 2f
        val top = centerY + fallbackFillPaint.ascent()
        val bottom = centerY + fallbackFillPaint.descent()
        return GlyphMetrics(centerX, centerY, top, bottom)
    }

    private fun configureTextPaint(paint: Paint) {
        paint.textSize = textSizePx
        paint.typeface = typeface
        paint.textAlign = Paint.Align.CENTER
    }

    private fun withAlphaBoost(color: Int, minAlpha: Int): Int {
        val alpha = maxOf(minAlpha, color ushr 24 and 0xFF)
        return color and 0x00FFFFFF or (alpha shl 24)
    }

    private data class GlyphMetrics(
        val centerX: Float,
        val centerY: Float,
        val top: Float,
        val bottom: Float,
    )

    private companion object {
        const val TEXT_VERTICAL_SCALE = 1.2f
    }
}
