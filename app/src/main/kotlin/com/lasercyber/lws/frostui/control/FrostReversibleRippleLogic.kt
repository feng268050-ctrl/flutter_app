package com.lasercyber.lws.frostui.control

import kotlin.math.hypot
import kotlin.math.max

internal fun frostReversibleRippleCoverRadius(
    boundsLeft: Float,
    boundsTop: Float,
    boundsRight: Float,
    boundsBottom: Float,
    originX: Float,
    originY: Float,
): Float {
    val dx = max(originX - boundsLeft, boundsRight - originX)
    val dy = max(originY - boundsTop, boundsBottom - originY)
    return hypot(dx.toDouble(), dy.toDouble()).toFloat()
}

internal fun frostReversibleRippleReverseDurationMs(
    fillDurationMs: Long,
    progress: Float,
): Long = max(1L, (fillDurationMs * progress.coerceIn(0f, 1f)).toLong())
