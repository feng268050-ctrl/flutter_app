package com.lasercyber.lws.ui.activitys.quick.mode.component

import android.graphics.Path
import kotlin.math.hypot
import kotlin.math.max

/** Bottom trapezoid hit/clip region for quick-mode Laser Enable buttons. */
object LaserButtonTrapezoidGeometry {
    const val TOP_WIDTH_RATIO = 0.5f
    const val BOTTOM_WIDTH_RATIO = 0.93f
    const val HEIGHT_RATIO = 0.8f

    data class Vertices(
        val topLeftX: Float,
        val topLeftY: Float,
        val topRightX: Float,
        val topRightY: Float,
        val bottomRightX: Float,
        val bottomRightY: Float,
        val bottomLeftX: Float,
        val bottomLeftY: Float,
    )

    @JvmStatic
    fun vertices(width: Float, height: Float): Vertices {
        val topY = height - height * HEIGHT_RATIO
        val topLeftX = width * (1 - TOP_WIDTH_RATIO) / 2f
        val topRightX = width - topLeftX
        val bottomY = height
        val bottomLeftX = width * (1 - BOTTOM_WIDTH_RATIO) / 2f
        val bottomRightX = width - bottomLeftX
        return Vertices(
            topLeftX = topLeftX,
            topLeftY = topY,
            topRightX = topRightX,
            topRightY = topY,
            bottomRightX = bottomRightX,
            bottomRightY = bottomY,
            bottomLeftX = bottomLeftX,
            bottomLeftY = bottomY,
        )
    }

    /** Ray-cast point-in-polygon for the bottom trapezoid. */
    @JvmStatic
    fun contains(x: Float, y: Float, width: Float, height: Float): Boolean {
        if (width <= 0f || height <= 0f) {
            return false
        }
        val v = vertices(width, height)
        val xs = floatArrayOf(v.topLeftX, v.topRightX, v.bottomRightX, v.bottomLeftX)
        val ys = floatArrayOf(v.topLeftY, v.topRightY, v.bottomRightY, v.bottomLeftY)
        var intersectCount = 0
        for (i in xs.indices) {
            val p1x = xs[i]
            val p1y = ys[i]
            val p2x = xs[(i + 1) % xs.size]
            val p2y = ys[(i + 1) % ys.size]
            if (p1y == p2y) {
                continue
            }
            if (y > minOf(p1y, p2y) && y <= maxOf(p1y, p2y)) {
                val intersectX = (y - p1y) * (p2x - p1x) / (p2y - p1y) + p1x
                if (x <= intersectX) {
                    intersectCount++
                }
            }
        }
        return intersectCount % 2 == 1
    }

    /** Farthest trapezoid vertex from touch origin — same radial fill semantics as rectangular buttons. */
    @JvmStatic
    fun coverRadius(originX: Float, originY: Float, width: Float, height: Float): Float {
        if (width <= 0f || height <= 0f) {
            return 0f
        }
        val v = vertices(width, height)
        val xs = floatArrayOf(v.topLeftX, v.topRightX, v.bottomRightX, v.bottomLeftX)
        val ys = floatArrayOf(v.topLeftY, v.topRightY, v.bottomRightY, v.bottomLeftY)
        var maxRadius = 0f
        for (i in xs.indices) {
            maxRadius = max(maxRadius, hypot(originX - xs[i], originY - ys[i]))
        }
        return maxRadius
    }

    @JvmStatic
    fun path(width: Float, height: Float): Path {
        val v = vertices(width, height)
        return Path().apply {
            moveTo(v.topLeftX, v.topLeftY)
            lineTo(v.topRightX, v.topRightY)
            lineTo(v.bottomRightX, v.bottomRightY)
            lineTo(v.bottomLeftX, v.bottomLeftY)
            close()
        }
    }
}
