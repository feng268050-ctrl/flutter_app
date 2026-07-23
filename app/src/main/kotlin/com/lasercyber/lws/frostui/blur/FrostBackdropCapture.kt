package com.lasercyber.lws.frostui.blur

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import kotlin.math.ceil
import kotlin.math.max

/** Captures a downscaled region of a backdrop [drawRoot] aligned to [anchor]. */
object FrostBackdropCapture {

    const val BLUR_SCALE_FACTOR = 3f

    @JvmStatic
    @JvmOverloads
    fun captureRegion(
        drawRoot: View,
        anchor: View,
        scaleFactor: Float = BLUR_SCALE_FACTOR,
        overscanPx: Int = 0,
    ): Bitmap? {
        val width = anchor.width
        val height = anchor.height
        if (width <= 0 || height <= 0) {
            return null
        }

        val drawLoc = IntArray(2)
        val anchorLoc = IntArray(2)
        drawRoot.getLocationOnScreen(drawLoc)
        anchor.getLocationOnScreen(anchorLoc)
        val offsetX = anchorLoc[0] - drawLoc[0]
        val offsetY = anchorLoc[1] - drawLoc[1]
        val pad = overscanPx.coerceAtLeast(0)
        val captureLeft = offsetX - pad
        val captureTop = offsetY - pad
        val captureWidth = width + pad * 2
        val captureHeight = height + pad * 2

        val scale = 1f / scaleFactor
        // Ceil so the upscaled bitmap never undershoots the anchor (avoids bottom gaps).
        val scaledWidth = max(1, ceil(captureWidth * scale).toInt())
        val scaledHeight = max(1, ceil(captureHeight * scale).toInt())

        val snapshot = Bitmap.createBitmap(scaledWidth, scaledHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(snapshot)
        canvas.scale(scale, scale)
        canvas.translate(-captureLeft.toFloat(), -captureTop.toFloat())
        withAnchorHidden(anchor) {
            HomeBackdropWebPCaptureGuard.withOverlayHidden(drawRoot) {
                drawRoot.draw(canvas)
            }
        }
        return snapshot
    }

    private inline fun withAnchorHidden(anchor: View, block: () -> Unit) {
        val previousVisibility = anchor.visibility
        if (previousVisibility != View.GONE) {
            anchor.visibility = View.INVISIBLE
        }
        try {
            block()
        } finally {
            anchor.visibility = previousVisibility
        }
    }
}
